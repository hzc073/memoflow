import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_bundle.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_codec.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_device_name_resolver.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_client.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_package_builder.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/state/migration/memoflow_migration_sender_controller.dart';
import 'package:memos_flutter_app/state/migration/memoflow_migration_state.dart';

class _SequencePackageBuilder extends MemoFlowMigrationPackageBuilder {
  _SequencePackageBuilder(this._responses)
    : super(
        codec: const ConfigTransferCodec(),
        readConfigBundle: (_) async => const ConfigTransferBundle(),
      );

  final List<Object> _responses;

  @override
  Future<MemoFlowMigrationPackageBuildResult> buildPackage({
    required LocalLibrary sourceLibrary,
    required bool includeMemos,
    required Set<MemoFlowMigrationConfigType> configTypes,
    required String senderDeviceName,
    required String senderPlatform,
  }) async {
    final next = _responses.removeAt(0);
    if (next is MemoFlowMigrationPackageBuildResult) {
      return next;
    }
    throw next;
  }
}

void main() {
  test(
    'buildPackage clears stale package result after rebuild failure',
    () async {
      final packageDir = await Directory.systemTemp.createTemp(
        'memoflow_sender_controller_test_',
      );
      final packageFile = File(
        '${packageDir.path}${Platform.pathSeparator}package.zip',
      );
      await packageFile.writeAsString('package', flush: true);

      final packageResult = MemoFlowMigrationPackageBuildResult(
        packageFile: packageFile,
        manifest: MemoFlowMigrationPackageManifest(
          schemaVersion: 1,
          protocolVersion: 'migration-v1',
          exportedAt: DateTime.utc(2025, 1, 1),
          senderDeviceName: 'Sender',
          senderPlatform: 'windows',
          sourceWorkspaceName: 'Local Workspace',
          includeMemos: true,
          includeSettings: false,
          memoCount: 1,
          attachmentCount: 0,
          totalBytes: 7,
          sha256: 'abc',
          configTypes: const <MemoFlowMigrationConfigType>{},
        ),
      );
      final library = const LocalLibrary(
        key: 'local-1',
        name: 'Local Workspace',
        storageKind: LocalLibraryStorageKind.managedPrivate,
        rootPath: '/tmp/local-1',
      );
      final controller = MemoFlowMigrationSenderController(
        initialLibrary: library,
        currentLibrary: () => library,
        packageBuilder: _SequencePackageBuilder(<Object>[
          packageResult,
          StateError('failed to rebuild package'),
        ]),
        client: MemoFlowMigrationClient(),
        deviceNameResolver: const MemoFlowDeviceNameResolver(),
      );

      addTearDown(() async {
        await controller.disposeResources();
        if (await packageDir.exists()) {
          await packageDir.delete(recursive: true);
        }
      });

      await controller.buildPackage();
      expect(controller.state.phase, MemoFlowMigrationSenderPhase.packageReady);
      expect(controller.state.packageResult, same(packageResult));

      await controller.buildPackage();

      expect(controller.state.phase, MemoFlowMigrationSenderPhase.failed);
      expect(controller.state.packageResult, isNull);
      expect(
        controller.state.errorMessage,
        contains('failed to rebuild package'),
      );
    },
  );
}
