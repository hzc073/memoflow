import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/migration/memoflow_device_name_resolver.dart';
import '../../application/sync/migration/memoflow_migration_client.dart';
import '../../application/sync/migration/memoflow_migration_models.dart';
import '../../application/sync/migration/memoflow_migration_package_builder.dart';
import '../../application/sync/migration/memoflow_migration_protocol.dart';
import '../../data/models/local_library.dart';
import 'memoflow_migration_state.dart';

class MemoFlowMigrationSenderController
    extends StateNotifier<MemoFlowMigrationSenderState> {
  MemoFlowMigrationSenderController({
    required LocalLibrary? initialLibrary,
    required this.currentLibrary,
    required this.packageBuilder,
    required this.client,
    required this.deviceNameResolver,
  }) : super(
         MemoFlowMigrationSenderState.initial(
           isLocalLibraryMode: initialLibrary != null,
         ),
       );

  final LocalLibrary? Function() currentLibrary;
  final MemoFlowMigrationPackageBuilder packageBuilder;
  final MemoFlowMigrationClient client;
  final MemoFlowDeviceNameResolver deviceNameResolver;

  Future<void> refreshLibraryState() async {
    final library = currentLibrary();
    state = state.copyWith(
      isLocalLibraryMode: library != null,
      includeMemos: library != null ? state.includeMemos : false,
    );
  }

  void setIncludeMemos(bool value) {
    if (!state.isLocalLibraryMode && value) return;
    state = state.copyWith(includeMemos: value, errorMessage: null);
  }

  void setIncludeSettings(bool value) {
    state = state.copyWith(
      includeSettings: value,
      selectedConfigTypes: value && state.selectedConfigTypes.isEmpty
          ? memoFlowMigrationSafeConfigDefaults
          : state.selectedConfigTypes,
      errorMessage: null,
    );
  }

  void toggleConfigType(MemoFlowMigrationConfigType type, bool value) {
    final next = <MemoFlowMigrationConfigType>{...state.selectedConfigTypes};
    if (value) {
      next.add(type);
    } else {
      next.remove(type);
    }
    state = state.copyWith(selectedConfigTypes: next, errorMessage: null);
  }

  Future<void> buildPackage() async {
    final library = currentLibrary();
    if (library == null && state.includeMemos) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        packageResult: null,
        activeProposalId: null,
        latestStatus: null,
        result: null,
        uploadProgress: 0,
        errorMessage: 'A local workspace is required to include memos.',
        statusMessage: null,
      );
      return;
    }
    if (!state.canBuildPackage) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        packageResult: null,
        activeProposalId: null,
        latestStatus: null,
        result: null,
        uploadProgress: 0,
        errorMessage: 'Select at least one migration content type.',
        statusMessage: null,
      );
      return;
    }

    state = state.copyWith(
      phase: MemoFlowMigrationSenderPhase.buildingPackage,
      packageResult: null,
      activeProposalId: null,
      statusMessage: 'Preparing migration package...',
      errorMessage: null,
      result: null,
      latestStatus: null,
      uploadProgress: 0,
    );

    try {
      final deviceName = await deviceNameResolver.resolve();
      final result = await packageBuilder.buildPackage(
        sourceLibrary:
            library ??
            LocalLibrary(
              key: 'settings-only',
              name: 'settings-only',
              rootPath: Directory.systemTemp.path,
            ),
        includeMemos: state.includeMemos,
        configTypes: state.effectiveConfigTypes,
        senderDeviceName: deviceName,
        senderPlatform: resolveMigrationPlatformLabel(),
      );
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.packageReady,
        packageResult: result,
        statusMessage:
            'Package ready: ${result.manifest.memoCount} memos, '
            '${result.manifest.attachmentCount} attachments, '
            '${result.manifest.draftCount} drafts.',
      );
    } catch (error) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        packageResult: null,
        activeProposalId: null,
        errorMessage: error.toString(),
        statusMessage: null,
      );
    }
  }

  Future<void> connectFromQrPayload(String raw) async {
    final descriptor = parseMemoFlowMigrationConnectUri(raw);
    if (descriptor == null) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        errorMessage: 'Invalid receiver QR payload.',
      );
      return;
    }
    await startTransfer(descriptor);
  }

  Future<void> connectManually({
    required String host,
    required int port,
    required String pairingCode,
  }) async {
    final trimmedHost = host.trim();
    final trimmedCode = pairingCode.trim();

    if (trimmedHost.isEmpty) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        errorMessage: 'Address is required.',
      );
      return;
    }
    if (port <= 0 || port > 65535) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        errorMessage: 'Port is invalid.',
      );
      return;
    }
    if (trimmedCode.isEmpty) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        errorMessage: 'Pair code is required.',
      );
      return;
    }

    try {
      final descriptor = await client.resolveManualDescriptor(
        host: trimmedHost,
        port: port,
        pairingCode: trimmedCode,
      );
      await startTransfer(descriptor);
    } catch (error) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> startTransfer(
    MemoFlowMigrationSessionDescriptor descriptor,
  ) async {
    if (state.packageResult == null) {
      await buildPackage();
    }
    final prepared = state.packageResult;
    if (prepared == null) return;

    state = state.copyWith(
      phase: MemoFlowMigrationSenderPhase.waitingForReceiver,
      statusMessage: 'Sending migration proposal...',
      errorMessage: null,
      uploadProgress: 0,
      result: null,
    );

    try {
      final proposalId = await client.submitProposal(
        descriptor: descriptor,
        manifest: prepared.manifest,
        senderDeviceName: prepared.manifest.senderDeviceName,
        senderPlatform: prepared.manifest.senderPlatform,
      );
      state = state.copyWith(activeProposalId: proposalId);

      MemoFlowMigrationStatusSnapshot status;
      do {
        await Future<void>.delayed(const Duration(seconds: 1));
        status = await client.getStatus(
          descriptor: descriptor,
          proposalId: proposalId,
        );
        state = state.copyWith(
          latestStatus: status,
          statusMessage: status.message,
        );
      } while (mounted &&
          !status.isTerminal &&
          (status.uploadToken == null || status.uploadToken!.isEmpty));

      if (!mounted) return;
      if (status.isTerminal) {
        _finishWithStatus(status);
        return;
      }

      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.uploading,
        statusMessage: 'Uploading migration package...',
      );
      final uploadResponse = await client.uploadPackage(
        descriptor: descriptor,
        uploadToken: status.uploadToken!,
        packageFile: prepared.packageFile,
        onSendProgress: (sentBytes, totalBytes) {
          if (!mounted) return;
          final progress = totalBytes <= 0 ? 0.0 : sentBytes / totalBytes;
          state = state.copyWith(uploadProgress: progress);
        },
      );
      if (!mounted) return;
      if (uploadResponse.result != null) {
        _finishWithUploadResult(uploadResponse.result!);
        return;
      }

      MemoFlowMigrationStatusSnapshot finalStatus;
      do {
        await Future<void>.delayed(const Duration(seconds: 1));
        finalStatus = await client.getStatus(
          descriptor: descriptor,
          proposalId: proposalId,
        );
        state = state.copyWith(
          latestStatus: finalStatus,
          statusMessage: finalStatus.message,
        );
      } while (mounted && !finalStatus.isTerminal);

      if (!mounted) return;
      _finishWithStatus(finalStatus);
    } catch (error) {
      state = state.copyWith(
        phase: MemoFlowMigrationSenderPhase.failed,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> reset() async {
    await disposeResources();
    final library = currentLibrary();
    state = MemoFlowMigrationSenderState.initial(
      isLocalLibraryMode: library != null,
    );
  }

  Future<void> disposeResources() async {
    final file = state.packageResult?.packageFile;
    if (file != null && await file.exists()) {
      await file.delete();
      final parent = file.parent;
      if (await parent.exists()) {
        await parent.delete(recursive: true);
      }
    }
  }

  void _finishWithStatus(MemoFlowMigrationStatusSnapshot status) {
    state = state.copyWith(
      phase: status.stage == MemoFlowMigrationTransferStage.completed
          ? MemoFlowMigrationSenderPhase.completed
          : MemoFlowMigrationSenderPhase.failed,
      latestStatus: status,
      result: status.result,
      statusMessage: status.message,
      errorMessage: status.error,
      uploadProgress: status.stage == MemoFlowMigrationTransferStage.completed
          ? 1
          : state.uploadProgress,
    );
  }

  void _finishWithUploadResult(MemoFlowMigrationResult result) {
    state = state.copyWith(
      phase: MemoFlowMigrationSenderPhase.completed,
      result: result,
      statusMessage: 'Migration completed.',
      errorMessage: null,
      uploadProgress: 1,
    );
  }
}
