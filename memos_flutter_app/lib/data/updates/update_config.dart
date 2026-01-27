class UpdateAnnouncementConfig {
  const UpdateAnnouncementConfig({
    required this.versionInfo,
    required this.announcement,
    required this.donors,
  });

  final UpdateVersionInfo versionInfo;
  final UpdateAnnouncement announcement;
  final List<UpdateDonor> donors;

  bool get hasDonors => donors.isNotEmpty;

  factory UpdateAnnouncementConfig.fromJson(Map<String, dynamic> json) {
    final versionInfo = UpdateVersionInfo.fromJson(_readMap(json['version_info']) ?? json);
    final announcement = UpdateAnnouncement.fromJson(_readMap(json['announcement']) ?? json);
    final donors = _readList(json['donors'])
        .whereType<Map>()
        .map((raw) => UpdateDonor.fromJson(raw.cast<String, dynamic>()))
        .where((donor) => donor.name.trim().isNotEmpty || donor.avatar.trim().isNotEmpty)
        .toList(growable: false);
    return UpdateAnnouncementConfig(
      versionInfo: versionInfo,
      announcement: announcement,
      donors: donors,
    );
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static List<dynamic> _readList(dynamic value) {
    if (value is List) return value;
    return const [];
  }
}

class UpdateVersionInfo {
  const UpdateVersionInfo({
    required this.latestVersion,
    required this.isForce,
    required this.downloadUrl,
  });

  final String latestVersion;
  final bool isForce;
  final String downloadUrl;

  factory UpdateVersionInfo.fromJson(Map<String, dynamic> json) {
    return UpdateVersionInfo(
      latestVersion: _readString(json, 'latest_version', fallbackKey: 'latestVersion'),
      isForce: _readBool(json, 'is_force', fallbackKey: 'isForce'),
      downloadUrl: _readString(json, 'download_url', fallbackKey: 'downloadUrl'),
    );
  }
}

class UpdateAnnouncement {
  const UpdateAnnouncement({
    required this.id,
    required this.title,
    required this.contentsByLocale,
    required this.fallbackContents,
    required this.newDonorIds,
  });

  final int id;
  final String title;
  final Map<String, List<String>> contentsByLocale;
  final List<String> fallbackContents;
  final List<String> newDonorIds;

  factory UpdateAnnouncement.fromJson(Map<String, dynamic> json) {
    var contentsByLocale = _readLocalizedContents(json['contents']);
    var fallbackContents = contentsByLocale.isEmpty ? _readStringList(json['contents']) : const <String>[];

    if (contentsByLocale.isEmpty && fallbackContents.isEmpty) {
      contentsByLocale = _readLocalizedContents(json['update_log']);
    }
    if (contentsByLocale.isEmpty && fallbackContents.isEmpty) {
      fallbackContents = _readStringList(json['update_log']);
    }
    return UpdateAnnouncement(
      id: _readInt(json, 'id'),
      title: _readString(json, 'title'),
      contentsByLocale: contentsByLocale,
      fallbackContents: fallbackContents,
      newDonorIds: _readIdList(json['new_donor_ids']),
    );
  }

  List<String> contentsForLanguageCode(String languageCode) {
    final normalized = _normalizeLangKey(languageCode);
    if (normalized.isNotEmpty) {
      final exact = contentsByLocale[normalized];
      if (exact != null && exact.isNotEmpty) return exact;
    }
    if (contentsByLocale.isNotEmpty) {
      final zh = contentsByLocale['zh'];
      if (zh != null && zh.isNotEmpty) return zh;
      final en = contentsByLocale['en'];
      if (en != null && en.isNotEmpty) return en;
      for (final entries in contentsByLocale.values) {
        if (entries.isNotEmpty) return entries;
      }
    }
    return fallbackContents;
  }

  List<UpdateDonor> newDonorsFrom(List<UpdateDonor> allDonors) {
    if (newDonorIds.isEmpty || allDonors.isEmpty) return const [];
    final target = newDonorIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (target.isEmpty) return const [];
    return allDonors.where((donor) => target.contains(donor.id)).toList(growable: false);
  }
}

class UpdateDonor {
  const UpdateDonor({
    required this.id,
    required this.name,
    required this.avatar,
  });

  final String id;
  final String name;
  final String avatar;

  factory UpdateDonor.fromJson(Map<String, dynamic> json) {
    final name = _readString(json, 'name');
    return UpdateDonor(
      id: _readString(json, 'id', fallbackKey: 'uid').ifEmpty(name),
      name: name,
      avatar: _readString(json, 'avatar', fallbackKey: 'avatar_url'),
    );
  }
}

String _readString(Map<String, dynamic> json, String key, {String? fallbackKey}) {
  final raw = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);
  if (raw is String) return raw.trim();
  return '';
}

bool _readBool(Map<String, dynamic> json, String key, {String? fallbackKey}) {
  final raw = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final lowered = raw.toLowerCase();
    if (lowered == 'true' || lowered == '1') return true;
    if (lowered == 'false' || lowered == '0') return false;
  }
  return false;
}

int _readInt(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    return [trimmed];
  }
  return const [];
}

List<String> _readIdList(dynamic value) {
  if (value is List) {
    final out = <String>[];
    for (final entry in value) {
      if (entry is String) {
        final trimmed = entry.trim();
        if (trimmed.isNotEmpty) out.add(trimmed);
      } else if (entry is num) {
        out.add(entry.toString());
      }
    }
    return out;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    return [trimmed];
  }
  if (value is num) {
    return [value.toString()];
  }
  return const [];
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

Map<String, List<String>> _readLocalizedContents(dynamic value) {
  if (value is! Map) return const {};
  final result = <String, List<String>>{};
  value.forEach((key, rawValue) {
    if (key is! String) return;
    final normalized = _normalizeLangKey(key);
    if (normalized.isEmpty) return;
    final entries = _readStringList(rawValue);
    if (entries.isEmpty) return;
    result[normalized] = entries;
  });
  return result;
}

String _normalizeLangKey(String code) {
  final trimmed = code.trim().toLowerCase();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.replaceAll('_', '-');
  if (normalized.startsWith('zh')) return 'zh';
  if (normalized.startsWith('en')) return 'en';
  return normalized.split('-').first;
}
