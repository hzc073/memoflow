import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_bundle.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_codec.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_device_name_resolver.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_client.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_package_builder.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_protocol.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/features/settings/migration/memoflow_migration_send_method_screen.dart';
import 'package:memos_flutter_app/features/settings/migration/memoflow_migration_sender_screen.dart';
import 'package:memos_flutter_app/state/migration/memoflow_migration_sender_controller.dart';
import 'package:memos_flutter_app/state/migration/memoflow_migration_providers.dart';
import 'package:memos_flutter_app/state/migration/memoflow_migration_state.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';

import 'settings_test_harness.dart';

class _FakePackageBuilder extends MemoFlowMigrationPackageBuilder {
  _FakePackageBuilder(this.result)
    : super(
        codec: const ConfigTransferCodec(),
        readConfigBundle: (_) async => const ConfigTransferBundle(),
      );

  final MemoFlowMigrationPackageBuildResult result;

  @override
  Future<MemoFlowMigrationPackageBuildResult> buildPackage({
    required LocalLibrary sourceLibrary,
    required bool includeMemos,
    required Set<MemoFlowMigrationConfigType> configTypes,
    required String senderDeviceName,
    required String senderPlatform,
  }) async {
    return result;
  }
}

class _FakeSenderController extends MemoFlowMigrationSenderController {
  _FakeSenderController(MemoFlowMigrationSenderState initialState)
    : super(
        initialLibrary: const LocalLibrary(
          key: 'local-1',
          name: 'Local Workspace',
          storageKind: LocalLibraryStorageKind.managedPrivate,
          rootPath: '/tmp/local-1',
        ),
        currentLibrary: () => const LocalLibrary(
          key: 'local-1',
          name: 'Local Workspace',
          storageKind: LocalLibraryStorageKind.managedPrivate,
          rootPath: '/tmp/local-1',
        ),
        packageBuilder: _FakePackageBuilder(
          MemoFlowMigrationPackageBuildResult(
            packageFile: File('${Directory.systemTemp.path}/memoflow_test.zip'),
            manifest: MemoFlowMigrationPackageManifest(
              schemaVersion: 1,
              protocolVersion: 'migration-v1',
              exportedAt: DateTime.utc(2025, 1, 1),
              senderDeviceName: 'Test Sender',
              senderPlatform: 'windows',
              sourceWorkspaceName: 'Local Workspace',
              includeMemos: true,
              includeSettings: false,
              memoCount: 3,
              attachmentCount: 1,
              totalBytes: 2048,
              sha256: 'abc',
              configTypes: const <MemoFlowMigrationConfigType>{},
            ),
          ),
        ),
        client: MemoFlowMigrationClient(),
        deviceNameResolver: const MemoFlowDeviceNameResolver(),
      ) {
    state = initialState;
  }

  String? lastConnectedQrPayload;

  @override
  Future<void> connectFromQrPayload(String raw) async {
    lastConnectedQrPayload = raw;
  }
}

void main() {
  testWidgets('shows sender defaults for local library migration', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const MemoFlowMigrationSenderScreen(),
        overrides: [
          currentLocalLibraryProvider.overrideWithValue(
            const LocalLibrary(
              key: 'local-1',
              name: 'Local Workspace',
              storageKind: LocalLibraryStorageKind.managedPrivate,
              rootPath: '/tmp/local-1',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("I'm the Sender"), findsOneWidget);
    expect(find.text('Notes content'), findsOneWidget);
    expect(find.text('Settings content'), findsOneWidget);
    expect(find.text('Prepare to send'), findsOneWidget);
  });

  testWidgets('shows send-method screen actions when package is ready', (
    tester,
  ) async {
    final packageResult = MemoFlowMigrationPackageBuildResult(
      packageFile: File('${Directory.systemTemp.path}/memoflow_test.zip'),
      manifest: MemoFlowMigrationPackageManifest(
        schemaVersion: 1,
        protocolVersion: 'migration-v1',
        exportedAt: DateTime.utc(2025, 1, 1),
        senderDeviceName: 'Test Sender',
        senderPlatform: 'windows',
        sourceWorkspaceName: 'Local Workspace',
        includeMemos: true,
        includeSettings: false,
        memoCount: 3,
        attachmentCount: 1,
        totalBytes: 2048,
        sha256: 'abc',
        configTypes: const <MemoFlowMigrationConfigType>{},
      ),
    );
    final controller = _FakeSenderController(
      MemoFlowMigrationSenderState(
        isLocalLibraryMode: true,
        includeMemos: true,
        includeSettings: false,
        selectedConfigTypes: memoFlowMigrationSafeConfigDefaults,
        phase: MemoFlowMigrationSenderPhase.packageReady,
        packageResult: packageResult,
      ),
    );

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const MemoFlowMigrationSendMethodScreen(),
        overrides: [
          memoFlowMigrationSenderControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send method'), findsOneWidget);
    expect(find.text('Package ready'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Search nearby receivers'), findsNothing);

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();

    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);
    expect(find.text('Pair code'), findsOneWidget);
  });

  testWidgets(
    'auto-connects when send-method screen receives a scanned migration QR',
    (tester) async {
      final packageResult = MemoFlowMigrationPackageBuildResult(
        packageFile: File('${Directory.systemTemp.path}/memoflow_test.zip'),
        manifest: MemoFlowMigrationPackageManifest(
          schemaVersion: 1,
          protocolVersion: 'migration-v1',
          exportedAt: DateTime.utc(2025, 1, 1),
          senderDeviceName: 'Test Sender',
          senderPlatform: 'windows',
          sourceWorkspaceName: 'Local Workspace',
          includeMemos: true,
          includeSettings: false,
          memoCount: 3,
          attachmentCount: 1,
          totalBytes: 2048,
          sha256: 'abc',
          configTypes: const <MemoFlowMigrationConfigType>{},
        ),
      );
      final controller = _FakeSenderController(
        MemoFlowMigrationSenderState(
          isLocalLibraryMode: true,
          includeMemos: true,
          includeSettings: false,
          selectedConfigTypes: memoFlowMigrationSafeConfigDefaults,
          phase: MemoFlowMigrationSenderPhase.packageReady,
          packageResult: packageResult,
        ),
      );
      final migrationQr = buildMemoFlowMigrationConnectUri(
        const MemoFlowMigrationSessionDescriptor(
          sessionId: 'session-1',
          pairingCode: '123456',
          host: '192.168.1.8',
          port: 4224,
          receiverDeviceName: 'Receiver',
          receiverPlatform: 'android',
          protocolVersion: memoFlowMigrationProtocolVersion,
        ),
      ).toString();

      await tester.pumpWidget(
        buildSettingsTestApp(
          home: MemoFlowMigrationSendMethodScreen(
            initialReceiverQrPayload: migrationQr,
          ),
          overrides: [
            memoFlowMigrationSenderControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.lastConnectedQrPayload, migrationQr);
    },
  );
}
