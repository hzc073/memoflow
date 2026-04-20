import 'dart:io';

import 'memoflow_migration_models.dart';

const memoFlowMigrationProtocolVersion = 'migration-v1';
const memoFlowMigrationServiceType = '_memoflow-migrate._tcp';

Uri buildMemoFlowMigrationConnectUri(
  MemoFlowMigrationSessionDescriptor descriptor,
) {
  return Uri(
    scheme: 'memoflow',
    host: 'migration',
    path: '/connect',
    queryParameters: <String, String>{
      'host': descriptor.host,
      'port': descriptor.port.toString(),
      'sid': descriptor.sessionId,
      'code': descriptor.pairingCode,
      'name': descriptor.receiverDeviceName,
      'platform': descriptor.receiverPlatform,
      'v': '1',
    },
  );
}

MemoFlowMigrationSessionDescriptor? parseMemoFlowMigrationConnectUri(
  String raw,
) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != 'memoflow') return null;
  if (uri.host.toLowerCase() != 'migration') return null;
  final host = uri.queryParameters['host']?.trim() ?? '';
  final sessionId = uri.queryParameters['sid']?.trim() ?? '';
  final pairingCode = uri.queryParameters['code']?.trim() ?? '';
  final port = int.tryParse(uri.queryParameters['port']?.trim() ?? '');
  if (host.isEmpty ||
      sessionId.isEmpty ||
      pairingCode.isEmpty ||
      port == null) {
    return null;
  }
  return MemoFlowMigrationSessionDescriptor(
    sessionId: sessionId,
    pairingCode: pairingCode,
    host: host,
    port: port,
    receiverDeviceName: uri.queryParameters['name']?.trim() ?? '',
    receiverPlatform: uri.queryParameters['platform']?.trim() ?? '',
    protocolVersion: memoFlowMigrationProtocolVersion,
  );
}

String resolveMigrationPlatformLabel() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
