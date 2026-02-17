import 'dart:convert';

enum RecycleBinItemType { memo, attachment }

class RecycleBinItem {
  const RecycleBinItem({
    required this.id,
    required this.type,
    required this.memoUid,
    required this.summary,
    required this.deletedTime,
    required this.expireTime,
    required this.payload,
  });

  final int id;
  final RecycleBinItemType type;
  final String memoUid;
  final String summary;
  final DateTime deletedTime;
  final DateTime expireTime;
  final Map<String, dynamic> payload;

  bool get isExpired => DateTime.now().isAfter(expireTime);

  factory RecycleBinItem.fromDb(Map<String, dynamic> row) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    RecycleBinItemType parseType(String raw) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'attachment') return RecycleBinItemType.attachment;
      return RecycleBinItemType.memo;
    }

    final rawPayload = (row['payload_json'] as String?) ?? '{}';
    Map<String, dynamic> payload = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map) {
        payload = decoded.cast<String, dynamic>();
      }
    } catch (_) {}

    final deletedMs = readInt(row['deleted_time']);
    final expireMs = readInt(row['expire_time']);

    return RecycleBinItem(
      id: readInt(row['id']),
      type: parseType((row['item_type'] as String?) ?? ''),
      memoUid: (row['memo_uid'] as String?) ?? '',
      summary: (row['summary'] as String?) ?? '',
      deletedTime: DateTime.fromMillisecondsSinceEpoch(
        deletedMs,
        isUtc: true,
      ).toLocal(),
      expireTime: DateTime.fromMillisecondsSinceEpoch(
        expireMs,
        isUtc: true,
      ).toLocal(),
      payload: payload,
    );
  }
}
