import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/migration/memoflow_device_name_resolver.dart';
import '../../application/sync/migration/memoflow_migration_models.dart';
import '../../application/sync/migration/memoflow_migration_protocol.dart';
import '../../application/sync/migration/memoflow_migration_server.dart';
import '../../data/models/local_library.dart';
import 'memoflow_migration_state.dart';

class MemoFlowMigrationReceiverController
    extends StateNotifier<MemoFlowMigrationReceiverState> {
  MemoFlowMigrationReceiverController({
    required this.server,
    required this.deviceNameResolver,
    required this.currentLibrary,
  }) : super(MemoFlowMigrationReceiverState.initial());

  final MemoFlowMigrationServer server;
  final MemoFlowDeviceNameResolver deviceNameResolver;
  final LocalLibrary? Function() currentLibrary;

  StreamSubscription<MemoFlowMigrationServerState>? _subscription;

  Future<void> startSession() async {
    state = state.copyWith(
      phase: MemoFlowMigrationReceiverPhase.startingSession,
      statusMessage: '正在创建接收会话…',
      errorMessage: null,
      result: null,
    );

    await _subscription?.cancel();
    _subscription = server.events.listen(_handleServerState);

    try {
      final deviceName = await deviceNameResolver.resolve();
      final descriptor = await server.startSession(
        receiverDeviceName: deviceName,
        receiverPlatform: resolveMigrationPlatformLabel(),
      );
      state = state.copyWith(
        phase: MemoFlowMigrationReceiverPhase.waitingProposal,
        sessionDescriptor: descriptor,
        qrPayload: buildMemoFlowMigrationConnectUri(descriptor).toString(),
        statusMessage: '等待发送方连接…',
        canOverwriteCurrentWorkspace: currentLibrary() != null,
        acceptedSensitiveConfigTypes: const <MemoFlowMigrationConfigType>{},
      );
    } catch (error) {
      state = state.copyWith(
        phase: MemoFlowMigrationReceiverPhase.failed,
        errorMessage: error.toString(),
      );
    }
  }

  void setReceiveMode(MemoFlowMigrationReceiveMode mode) {
    if (mode == MemoFlowMigrationReceiveMode.overwriteCurrent &&
        !state.canOverwriteCurrentWorkspace) {
      return;
    }
    state = state.copyWith(selectedReceiveMode: mode);
  }

  void toggleSensitiveConfigType(MemoFlowMigrationConfigType type, bool value) {
    final next = <MemoFlowMigrationConfigType>{
      ...state.acceptedSensitiveConfigTypes,
    };
    if (value) {
      next.add(type);
    } else {
      next.remove(type);
    }
    state = state.copyWith(acceptedSensitiveConfigTypes: next);
  }

  Future<void> acceptProposal() async {
    try {
      await server.acceptProposal(
        receiveMode: state.selectedReceiveMode,
        acceptedSensitiveConfigTypes: state.acceptedSensitiveConfigTypes,
      );
    } catch (error) {
      state = state.copyWith(
        phase: MemoFlowMigrationReceiverPhase.failed,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> rejectProposal() async {
    await server.cancelCurrentProposal(message: '接收方已拒绝本次迁移。');
  }

  Future<void> stopSession() async {
    await _subscription?.cancel();
    _subscription = null;
    await server.stopSession();
    state = MemoFlowMigrationReceiverState.initial();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(server.stopSession());
    super.dispose();
  }

  void _handleServerState(MemoFlowMigrationServerState next) {
    final descriptor = next.sessionDescriptor;
    final proposal = next.proposal;
    final status = next.status;
    final canOverwrite =
        currentLibrary() != null && (proposal?.manifest.includeMemos ?? false);

    switch (status.stage) {
      case MemoFlowMigrationTransferStage.waitingProposal:
        state = state.copyWith(
          phase: MemoFlowMigrationReceiverPhase.waitingProposal,
          sessionDescriptor: descriptor,
          qrPayload: descriptor == null
              ? state.qrPayload
              : buildMemoFlowMigrationConnectUri(descriptor).toString(),
          proposal: null,
          latestStatus: status,
          statusMessage: '等待发送方连接…',
          canOverwriteCurrentWorkspace: canOverwrite,
          acceptedSensitiveConfigTypes: const <MemoFlowMigrationConfigType>{},
        );
      case MemoFlowMigrationTransferStage.awaitingAccept:
        final defaultMode = canOverwrite
            ? MemoFlowMigrationReceiveMode.newWorkspace
            : MemoFlowMigrationReceiveMode.newWorkspace;
        state = state.copyWith(
          phase: MemoFlowMigrationReceiverPhase.reviewingProposal,
          sessionDescriptor: descriptor,
          proposal: proposal,
          latestStatus: status,
          statusMessage: '已收到迁移提案，请确认导入方式。',
          canOverwriteCurrentWorkspace: canOverwrite,
          selectedReceiveMode: defaultMode,
          acceptedSensitiveConfigTypes: const <MemoFlowMigrationConfigType>{},
        );
      case MemoFlowMigrationTransferStage.awaitingUpload ||
          MemoFlowMigrationTransferStage.receiving ||
          MemoFlowMigrationTransferStage.validating ||
          MemoFlowMigrationTransferStage.importingFiles ||
          MemoFlowMigrationTransferStage.scanning ||
          MemoFlowMigrationTransferStage.applyingConfig:
        state = state.copyWith(
          phase: MemoFlowMigrationReceiverPhase.receiving,
          sessionDescriptor: descriptor,
          proposal: proposal,
          latestStatus: status,
          statusMessage: status.message,
          canOverwriteCurrentWorkspace: canOverwrite,
        );
      case MemoFlowMigrationTransferStage.completed:
        state = state.copyWith(
          phase: MemoFlowMigrationReceiverPhase.completed,
          proposal: proposal,
          latestStatus: status,
          result: status.result,
          statusMessage: status.message,
        );
      case MemoFlowMigrationTransferStage.failed:
        state = state.copyWith(
          phase: MemoFlowMigrationReceiverPhase.failed,
          proposal: proposal,
          latestStatus: status,
          errorMessage: status.error ?? status.message,
        );
      case MemoFlowMigrationTransferStage.cancelled:
        state = state.copyWith(
          phase: MemoFlowMigrationReceiverPhase.cancelled,
          proposal: proposal,
          latestStatus: status,
          statusMessage: status.message,
          errorMessage: status.error,
        );
      case MemoFlowMigrationTransferStage.idle:
        state = MemoFlowMigrationReceiverState.initial();
    }
  }
}
