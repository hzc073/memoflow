part of 'memos_list_providers.dart';

Map<String, dynamic> _decodeOutboxPayload(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {}
  return <String, dynamic>{};
}

String? _extractOutboxMemoUid(String type, Map<String, dynamic> payload) {
  return switch (type) {
    'create_memo' ||
    'update_memo' ||
    'delete_memo' => payload['uid'] as String?,
    'upload_attachment' ||
    'delete_attachment' => payload['memo_uid'] as String?,
    _ => null,
  };
}

String _apiVersionBandLabel(MemosVersionNumber? version) {
  if (version == null) return '-';
  if (version.major == 0 && version.minor >= 20 && version.minor < 30) {
    return '0.2x';
  }
  return '${version.major}.${version.minor}x';
}

String _buildDebugApiVersionText(MemosVersionResolution? resolution) {
  if (resolution == null) return 'API -';
  final band = _apiVersionBandLabel(resolution.parsedVersion);
  final effective = resolution.effectiveVersion.trim();
  if (effective.isEmpty) return 'API $band';
  return 'API $band ($effective)';
}
