import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_client.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_import_service.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_server.dart';

class _FakeImportService implements MemoFlowMigrationImportService {
  @override
  Future<MemoFlowMigrationResult> importPackage({
    required File packageFile,
    required MemoFlowMigrationProposal proposal,
    required MemoFlowMigrationReceiveMode receiveMode,
    required Set<MemoFlowMigrationConfigType> allowedConfigTypes,
    bool activateImportedWorkspace = true,
    void Function(MemoFlowMigrationTransferStage stage, {String? message})?
    onProgress,
  }) async {
    onProgress?.call(
      MemoFlowMigrationTransferStage.importingFiles,
      message: 'Importing package.',
    );
    return MemoFlowMigrationResult(
      sourceDeviceName: proposal.senderDeviceName,
      receiveMode: receiveMode,
      memoCount: proposal.manifest.memoCount,
      attachmentCount: proposal.manifest.attachmentCount,
      appliedConfigTypes: allowedConfigTypes,
      skippedConfigTypes: proposal.manifest.configTypes.difference(
        allowedConfigTypes,
      ),
      workspaceName: proposal.manifest.sourceWorkspaceName,
      workspaceKey: receiveMode == MemoFlowMigrationReceiveMode.newWorkspace
          ? 'migration_workspace'
          : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
}

void main() {
  group('MemoFlowMigrationServer', () {
    test('does not expose remote accept endpoint', () async {
      final fixture = await _createPackageFixture();
      final server = MemoFlowMigrationServer(
        importService: _FakeImportService(),
        enableBroadcast: false,
        temporaryDirectoryResolver: () async => fixture.tempDir,
      );

      try {
        final descriptor = _loopback(
          await server.startSession(
            receiverDeviceName: 'Receiver',
            receiverPlatform: 'windows',
          ),
        );
        await MemoFlowMigrationClient().submitProposal(
          descriptor: descriptor,
          manifest: fixture.manifest,
          senderDeviceName: 'Sender',
          senderPlatform: 'windows',
        );

        final response = await _postJson(
          descriptor,
          '/migration/v1/accept',
          <String, dynamic>{
            'receiveMode': MemoFlowMigrationReceiveMode.newWorkspace.name,
          },
        );

        expect(response.statusCode, HttpStatus.notFound);
        expect(response.body['error'], 'Not found.');
        expect(
          server.currentState.status.stage,
          MemoFlowMigrationTransferStage.awaitingAccept,
        );
        expect(server.currentState.status.uploadToken, isNull);
      } finally {
        await server.dispose();
        await fixture.tempDir.delete(recursive: true);
      }
    });

    test('does not expose remote cancel endpoint', () async {
      final fixture = await _createPackageFixture();
      final server = MemoFlowMigrationServer(
        importService: _FakeImportService(),
        enableBroadcast: false,
        temporaryDirectoryResolver: () async => fixture.tempDir,
      );

      try {
        final descriptor = _loopback(
          await server.startSession(
            receiverDeviceName: 'Receiver',
            receiverPlatform: 'windows',
          ),
        );
        await MemoFlowMigrationClient().submitProposal(
          descriptor: descriptor,
          manifest: fixture.manifest,
          senderDeviceName: 'Sender',
          senderPlatform: 'windows',
        );

        final response = await _postJson(
          descriptor,
          '/migration/v1/cancel',
          const <String, dynamic>{},
        );

        expect(response.statusCode, HttpStatus.notFound);
        expect(response.body['error'], 'Not found.');
        expect(
          server.currentState.status.stage,
          MemoFlowMigrationTransferStage.awaitingAccept,
        );
      } finally {
        await server.dispose();
        await fixture.tempDir.delete(recursive: true);
      }
    });

    test(
      'falls back to manual transfer when broadcast startup fails',
      () async {
        final fixture = await _createPackageFixture();
        final server = MemoFlowMigrationServer(
          importService: _FakeImportService(),
          broadcastStarter: (_) async {
            throw StateError('mdns unavailable');
          },
          temporaryDirectoryResolver: () async => fixture.tempDir,
        );

        try {
          final descriptor = _loopback(
            await server.startSession(
              receiverDeviceName: 'Receiver',
              receiverPlatform: 'windows',
            ),
          );

          expect(
            server.currentState.status.stage,
            MemoFlowMigrationTransferStage.waitingProposal,
          );

          final proposalId = await MemoFlowMigrationClient().submitProposal(
            descriptor: descriptor,
            manifest: fixture.manifest,
            senderDeviceName: 'Sender',
            senderPlatform: 'windows',
          );

          expect(proposalId, isNotEmpty);
          expect(
            server.currentState.status.stage,
            MemoFlowMigrationTransferStage.awaitingAccept,
          );
        } finally {
          await server.dispose();
          await fixture.tempDir.delete(recursive: true);
        }
      },
    );

    test('preserves completed state after the upload timeout window', () async {
      final fixture = await _createPackageFixture();
      final server = MemoFlowMigrationServer(
        importService: _FakeImportService(),
        sessionTimeout: const Duration(seconds: 10),
        uploadTimeout: const Duration(milliseconds: 300),
        enableBroadcast: false,
        temporaryDirectoryResolver: () async => fixture.tempDir,
      );

      try {
        final descriptor = _loopback(
          await server.startSession(
            receiverDeviceName: 'Receiver',
            receiverPlatform: 'windows',
          ),
        );
        await MemoFlowMigrationClient().submitProposal(
          descriptor: descriptor,
          manifest: fixture.manifest,
          senderDeviceName: 'Sender',
          senderPlatform: 'windows',
        );

        final acceptance = await server.acceptProposal(
          receiveMode: MemoFlowMigrationReceiveMode.newWorkspace,
          acceptedSensitiveConfigTypes: const <MemoFlowMigrationConfigType>{},
        );
        try {
          final uploadResponse = await MemoFlowMigrationClient().uploadPackage(
            descriptor: descriptor,
            uploadToken: acceptance.uploadToken,
            packageFile: fixture.packageFile,
          );
          expect(uploadResponse.result, isNotNull);
          expect(uploadResponse.result?.memoCount, 1);
        } on DioException catch (error) {
          fail(
            'upload failed: '
            'status=${error.response?.statusCode}, '
            'body=${error.response?.data}, '
            'serverStage=${server.currentState.status.stage}, '
            'serverError=${server.currentState.status.error}',
          );
        }

        expect(
          server.currentState.status.stage,
          MemoFlowMigrationTransferStage.completed,
        );

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(
          server.currentState.status.stage,
          MemoFlowMigrationTransferStage.completed,
        );
        expect(server.currentState.status.error, isNull);
      } finally {
        await server.dispose();
        await fixture.tempDir.delete(recursive: true);
      }
    });
  });
}

MemoFlowMigrationSessionDescriptor _loopback(
  MemoFlowMigrationSessionDescriptor descriptor,
) {
  return MemoFlowMigrationSessionDescriptor(
    sessionId: descriptor.sessionId,
    pairingCode: descriptor.pairingCode,
    host: InternetAddress.loopbackIPv4.address,
    port: descriptor.port,
    receiverDeviceName: descriptor.receiverDeviceName,
    receiverPlatform: descriptor.receiverPlatform,
    protocolVersion: descriptor.protocolVersion,
  );
}

Future<
  ({
    MemoFlowMigrationPackageManifest manifest,
    File packageFile,
    Directory tempDir,
  })
>
_createPackageFixture() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'memoflow_migration_server_test_',
  );
  final archive = Archive();
  final random = math.Random(42);
  final payloadBytes = List<int>.generate(
    512 * 1024,
    (_) => random.nextInt(256),
    growable: false,
  );
  archive.addFile(
    ArchiveFile('memos/test.md', payloadBytes.length, payloadBytes),
  );
  final zipBytes = ZipEncoder().encode(archive);
  final packageFile = File(
    '${tempDir.path}${Platform.pathSeparator}package.zip',
  );
  await packageFile.writeAsBytes(zipBytes, flush: true);

  return (
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
      totalBytes: zipBytes.length,
      sha256: crypto.sha256.convert(zipBytes).toString(),
      configTypes: const <MemoFlowMigrationConfigType>{},
    ),
    packageFile: packageFile,
    tempDir: tempDir,
  );
}

Future<_JsonResponse> _postJson(
  MemoFlowMigrationSessionDescriptor descriptor,
  String path,
  Map<String, dynamic> payload,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(_buildUri(descriptor, path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return _JsonResponse(
      statusCode: response.statusCode,
      body: (jsonDecode(body) as Map).cast<String, dynamic>(),
    );
  } finally {
    client.close(force: true);
  }
}

Uri _buildUri(MemoFlowMigrationSessionDescriptor descriptor, String path) {
  return Uri(
    scheme: 'http',
    host: descriptor.host,
    port: descriptor.port,
    path: path,
  );
}
