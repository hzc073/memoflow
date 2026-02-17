import 'dart:convert';

class MemoVersion {
  const MemoVersion({
    required this.id,
    required this.memoUid,
    required this.snapshotTime,
    required this.summary,
    required this.payload,
  });

  final int id;
  final String memoUid;
  final DateTime snapshotTime;
  final String summary;
  final Map<String, dynamic> payload;

  factory MemoVersion.fromDb(Map<String, dynamic> row) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    final rawPayload = (row['payload_json'] as String?) ?? '{}';
    Map<String, dynamic> payload = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map) {
        payload = decoded.cast<String, dynamic>();
      }
    } catch (_) {}

    final snapshotMs = readInt(row['snapshot_time']);
    return MemoVersion(
      id: readInt(row['id']),
      memoUid: (row['memo_uid'] as String?) ?? '',
      snapshotTime: DateTime.fromMillisecondsSinceEpoch(
        snapshotMs,
        isUtc: true,
      ).toLocal(),
      summary: (row['summary'] as String?) ?? '',
      payload: payload,
    );
  }
}
