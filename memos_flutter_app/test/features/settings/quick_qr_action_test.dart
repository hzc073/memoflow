import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_protocol.dart';
import 'package:memos_flutter_app/features/settings/quick_qr_action.dart';

void main() {
  test('classifyQuickQrPayload recognizes MemoFlow migration QR first', () {
    final payload = buildMemoFlowMigrationConnectUri(
      const MemoFlowMigrationSessionDescriptor(
        sessionId: 'session-1',
        pairingCode: '654321',
        host: '192.168.1.18',
        port: 4224,
        receiverDeviceName: 'Receiver',
        receiverPlatform: 'android',
        protocolVersion: memoFlowMigrationProtocolVersion,
      ),
    ).toString();

    final target = classifyQuickQrPayload(payload);

    expect(target, isNotNull);
    expect(target?.kind, QuickQrActionKind.migrationSender);
    expect(target?.rawPayload, payload);
  });

  test('classifyQuickQrPayload recognizes bridge pairing QR', () {
    const payload =
        'memoflow://pair?host=192.168.1.20&port=3000&pairCode=123456&api=bridge-v1';

    final target = classifyQuickQrPayload(payload);

    expect(target, isNotNull);
    expect(target?.kind, QuickQrActionKind.bridgePairing);
    expect(target?.rawPayload, payload);
  });

  test('classifyQuickQrPayload rejects unsupported QR data', () {
    expect(classifyQuickQrPayload('hello world'), isNull);
  });
}
