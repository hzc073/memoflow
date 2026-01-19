class UserGeneralSetting {
  const UserGeneralSetting({
    this.locale,
    this.memoVisibility,
    this.theme,
  });

  final String? locale;
  final String? memoVisibility;
  final String? theme;

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
    required this.createTime,
    required this.updateTime,
    required this.legacyId,
  });

  final String name;
  final String url;
  final String displayName;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? legacyId;

  bool get isLegacy => legacyId != null && legacyId! > 0;

  factory UserWebhook.fromJson(Map<String, dynamic> json) {
    final name = _readString(json['name']);
    final url = _readString(json['url']);
    final displayName = _readString(
      json['displayName'] ?? json['display_name'] ?? json['title'] ?? json['name'],
    );
    final legacyIdRaw = json['id'] ?? json['webhookId'] ?? json['webhook_id'];
    final legacyId = _readInt(legacyIdRaw);
    final createTime = _parseTime(json['createTime'] ?? json['create_time'] ?? json['createdTime'] ?? json['created_time']);
    final updateTime = _parseTime(json['updateTime'] ?? json['update_time'] ?? json['updatedTime'] ?? json['updated_time']);
    return UserWebhook(
      name: name,
      url: url,
      displayName: displayName.isEmpty ? name : displayName,
      createTime: createTime,
      updateTime: updateTime,
      legacyId: legacyId > 0 ? legacyId : null,
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
    final id = legacyId;
    if (id != null && id > 0) {
      data['id'] = id;
    }
    return data;
  }
}

class UserWebhooksSetting {
  const UserWebhooksSetting({required this.webhooks});

  final List<UserWebhook> webhooks;

  factory UserWebhooksSetting.fromJson(Map<String, dynamic> json) {
    final list = json['webhooks'];
    final webhooks = <UserWebhook>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          webhooks.add(UserWebhook.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return UserWebhooksSetting(webhooks: webhooks);
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
    UserWebhooksSetting? webhooksSetting;

    final generalValue = json['generalSetting'] ?? json['general_setting'] ?? json['general'];
    if (generalValue is Map) {
      generalSetting = UserGeneralSetting.fromJson(generalValue.cast<String, dynamic>());
    } else if (_hasGeneralFields(json)) {
      generalSetting = UserGeneralSetting.fromJson(json);
    }

    final webhooksValue = json['webhooksSetting'] ?? json['webhooks_setting'];
    if (webhooksValue is Map) {
      webhooksSetting = UserWebhooksSetting.fromJson(webhooksValue.cast<String, dynamic>());
    } else if (json['webhooks'] is List) {
      webhooksSetting = UserWebhooksSetting.fromJson(json);
    }

    return UserSetting(
      name: name,
      generalSetting: generalSetting,
      webhooksSetting: webhooksSetting,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (name.trim().isNotEmpty) {
      data['name'] = name.trim();
    }
    final general = generalSetting;
    if (general != null) {
      data['generalSetting'] = general.toJson();
    }
    final webhooks = webhooksSetting;
    if (webhooks != null) {
      data['webhooksSetting'] = webhooks.toJson();
    }
    return data;
  }
}

bool _hasGeneralFields(Map<String, dynamic> json) {
  return json.containsKey('locale') ||
      json.containsKey('memoVisibility') ||
      json.containsKey('memo_visibility') ||
      json.containsKey('theme') ||
      json.containsKey('appearance');
}

String _readString(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

DateTime? _parseTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is Map) {
    final seconds = _readInt(value['seconds'] ?? value['Seconds']);
    final nanos = _readInt(value['nanos'] ?? value['Nanos']);
    if (seconds <= 0) return null;
    final millis = seconds * 1000 + (nanos ~/ 1000000);
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }
  if (value is int || value is num) {
    final raw = _readInt(value);
    if (raw <= 0) return null;
    if (raw > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true).toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true).toLocal();
  }
  return null;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
