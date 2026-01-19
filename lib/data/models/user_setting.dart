class UserGeneralSetting {
  const UserGeneralSetting({
    this.locale,
    this.memoVisibility,
    this.theme,
  });

  final String? locale;
  final String? memoVisibility;
  final String? theme;

  bool get isEmpty {
    return (locale ?? '').trim().isEmpty &&
        (memoVisibility ?? '').trim().isEmpty &&
        (theme ?? '').trim().isEmpty;
  }

  UserGeneralSetting copyWith({
    String? locale,
    String? memoVisibility,
    String? theme,
  }) {
    return UserGeneralSetting(
      locale: locale ?? this.locale,
      memoVisibility: memoVisibility ?? this.memoVisibility,
      theme: theme ?? this.theme,
    );
  }

  factory UserGeneralSetting.fromJson(Map<String, dynamic> json) {
    final locale = _readString(json['locale']);
    final memoVisibility = _readString(json['memoVisibility'] ?? json['memo_visibility']);
    final theme = _readString(json['theme'] ?? json['appearance']);

    return UserGeneralSetting(
      locale: locale.isEmpty ? null : locale,
      memoVisibility: memoVisibility.isEmpty ? null : memoVisibility,
      theme: theme.isEmpty ? null : theme,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (locale != null && locale!.trim().isNotEmpty) {
      data['locale'] = locale!.trim();
    }
    if (memoVisibility != null && memoVisibility!.trim().isNotEmpty) {
      data['memoVisibility'] = memoVisibility!.trim();
    }
    if (theme != null && theme!.trim().isNotEmpty) {
      data['theme'] = theme!.trim();
    }
    return data;
  }
}

class UserWebhook {
  const UserWebhook({
    required this.name,
    required this.url,
    required this.displayName,
    this.createTime,
    this.updateTime,
    this.legacyId,
    this.creator,
  });

  final String name;
  final String url;
  final String displayName;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? legacyId;
  final String? creator;

  bool get isLegacy => (legacyId ?? 0) > 0;

  factory UserWebhook.fromJson(Map<String, dynamic> json) {
    final legacyId = _readInt(json['id'] ?? json['webhookId']);
    var name = _readString(json['name']);
    if (name.isEmpty && legacyId > 0) {
      name = 'webhooks/$legacyId';
    }
    final url = _readString(json['url']);
    final displayName = _readString(json['displayName'] ?? json['display_name']);
    final creator = _readCreator(json['creator'] ?? json['creator_id']);
    final createTime = _parseTimestamp(
      json['createTime'] ?? json['create_time'] ?? json['createdTime'] ?? json['created_time'],
    );
    final updateTime = _parseTimestamp(
      json['updateTime'] ?? json['update_time'] ?? json['updatedTime'] ?? json['updated_time'],
    );

    return UserWebhook(
      name: name,
      url: url,
      displayName: displayName,
      createTime: createTime,
      updateTime: updateTime,
      legacyId: legacyId > 0 ? legacyId : null,
      creator: creator,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'url': url,
    };
    if (displayName.trim().isNotEmpty) {
      data['displayName'] = displayName.trim();
    }
    return data;
  }
}

class UserWebhooksSetting {
  const UserWebhooksSetting({required this.webhooks});

  final List<UserWebhook> webhooks;

  factory UserWebhooksSetting.fromJson(Map<String, dynamic> json) {
    final list = json['webhooks'];
    if (list is List) {
      return UserWebhooksSetting(
        webhooks: list.whereType<Map>().map((e) => UserWebhook.fromJson(e.cast<String, dynamic>())).toList(growable: false),
      );
    }
    return const UserWebhooksSetting(webhooks: []);
  }

  Map<String, dynamic> toJson() => {
        'webhooks': webhooks.map((w) => w.toJson()).toList(growable: false),
      };
}

class UserSetting {
  const UserSetting({
    required this.name,
    this.generalSetting,
    this.webhooksSetting,
  });

  final String name;
  final UserGeneralSetting? generalSetting;
  final UserWebhooksSetting? webhooksSetting;

  factory UserSetting.fromJson(Map<String, dynamic> json) {
    final name = _readString(json['name']);

    UserGeneralSetting? generalSetting;
    final generalRaw = json['generalSetting'] ??
        json['general_setting'] ??
        json['general'] ??
        json['GENERAL'] ??
        json['GeneralSetting'];
    if (generalRaw is Map) {
      generalSetting = UserGeneralSetting.fromJson(generalRaw.cast<String, dynamic>());
    }

    UserWebhooksSetting? webhooksSetting;
    final webhooksRaw = json['webhooksSetting'] ?? json['webhooks_setting'];
    if (webhooksRaw is Map) {
      webhooksSetting = UserWebhooksSetting.fromJson(webhooksRaw.cast<String, dynamic>());
    }

    if (generalSetting == null) {
      final fallback = UserGeneralSetting.fromJson(json);
      if (!fallback.isEmpty) {
        generalSetting = fallback;
      }
    }

    return UserSetting(
      name: name,
      generalSetting: generalSetting,
      webhooksSetting: webhooksSetting,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
    };
    if (generalSetting != null) {
      data['generalSetting'] = generalSetting!.toJson();
    }
    if (webhooksSetting != null) {
      data['webhooksSetting'] = webhooksSetting!.toJson();
    }
    return data;
  }
}

String _readString(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

String _readCreator(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  final id = _readInt(value);
  if (id <= 0) return '';
  return 'users/$id';
}

DateTime? _parseTimestamp(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is Map) {
    final seconds = _readInt(value['seconds'] ?? value['Seconds']);
    final nanos = _readInt(value['nanos'] ?? value['Nanos']);
    if (seconds <= 0) return null;
    final millis = seconds * 1000 + (nanos ~/ 1000000);
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
  if (value is int || value is num) {
    final raw = _readInt(value);
    if (raw <= 0) return null;
    if (raw > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
  }
  return null;
}
