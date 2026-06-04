const String memoUpdateTimePayloadKey = 'update_time';

int encodeMemoUpdateTimePayload(DateTime updateTime) {
  return updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
}

Map<String, Object?> memoUpdateTimePayload(DateTime updateTime) {
  return <String, Object?>{
    memoUpdateTimePayloadKey: encodeMemoUpdateTimePayload(updateTime),
  };
}

Map<String, Object?> memoUpdateTimePayloadFromSeconds(int updateTimeSec) {
  return <String, Object?>{memoUpdateTimePayloadKey: updateTimeSec};
}

DateTime? decodeMemoUpdateTimePayload(Map<String, dynamic> payload) {
  return parseMemoPayloadTime(
    payload[memoUpdateTimePayloadKey] ?? payload['updateTime'],
  );
}

DateTime? parseMemoPayloadTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is int) return memoEpochToDateTime(raw);
  if (raw is double) return memoEpochToDateTime(raw.round());
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return memoEpochToDateTime(asInt);
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed.isUtc ? parsed : parsed.toUtc();
  }
  return null;
}

DateTime memoEpochToDateTime(int value) {
  final ms = value > 1000000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
