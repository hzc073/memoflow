enum NotificationSource {
  modern,
  legacy,
}

class AppNotification {
  const AppNotification({
    required this.name,
    required this.sender,
    required this.status,
    required this.type,
    required this.createTime,
    required this.activityId,
    required this.source,
  });

  final String name;
  final String sender;
  final String status;
  final String type;
  final DateTime createTime;
  final int? activityId;
  final NotificationSource source;

  bool get isUnread => status.toUpperCase() == 'UNREAD';

  String get id {
    final raw = name.trim();
    if (raw.isEmpty) return '';
    final parts = raw.split('/');
    return parts.isNotEmpty ? parts.last : raw;
  }

  factory AppNotification.fromModernJson(Map<String, dynamic> json) {
    return _fromJson(json, NotificationSource.modern);
  }

  factory AppNotification.fromLegacyJson(Map<String, dynamic> json) {
    return _fromJson(json, NotificationSource.legacy);
  }

  static AppNotification _fromJson(Map<String, dynamic> json, NotificationSource source) {
    final name = _readString(json['name']);
    final sender = _readString(json['sender']);
    final status = _readString(json['status']);
    final type = _readString(json['type']);
    final createTime = _parseTime(json['createTime'] ?? json['create_time']);
    final activityId = _readInt(json['activityId'] ?? json['activity_id']);

    return AppNotification(
      name: name,
      sender: sender,
      status: status,
      type: type,
      createTime: createTime,
      activityId: activityId > 0 ? activityId : null,
      source: source,
    );
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value == null) return '';
    return value.toString().trim();
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static DateTime _parseTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
