part of memos_api;

const Duration _attachmentTimeout = Duration(seconds: 120);

const Duration _largeListReceiveTimeout = Duration(seconds: 90);

const Object _unset = Object();

InstanceProfile _instanceProfileFromStatus(Map<String, dynamic> body) {
  final profile = _readMap(body['profile']);
  final version = _readString(profile?['version']);
  final mode = _readString(profile?['mode']);

  final customizedProfile = _readMap(
    body['customizedProfile'] ?? body['customized_profile'],
  );
  final instanceUrl = _readString(
    customizedProfile?['externalUrl'] ??
        customizedProfile?['external_url'] ??
        customizedProfile?['instanceUrl'] ??
        customizedProfile?['instance_url'],
  );

  final host = _readMap(body['host']);
  final owner = _readString(
    host?['name'] ?? host?['username'] ?? host?['nickname'] ?? host?['id'],
  );

  return InstanceProfile(
    version: version,
    mode: mode,
    instanceUrl: instanceUrl,
    owner: owner,
  );
}

String? _tryExtractNumericUserId(String userNameOrId) {
  final raw = userNameOrId.trim();
  if (raw.isEmpty) return null;
  final last = raw.contains('/') ? raw.split('/').last : raw;
  final id = int.tryParse(last.trim());
  if (id == null) return null;
  return id.toString();
}

Map<String, dynamic> _unwrapWebhookPayload(Map<String, dynamic> body) {
  final inner = body['webhook'];
  if (inner is Map) {
    return inner.cast<String, dynamic>();
  }
  return body;
}

Map<String, dynamic> _legacyUserSettingPayload(
  String name, {
  required UserGeneralSetting setting,
}) {
  final data = <String, dynamic>{'name': name};
  if (setting.locale != null && setting.locale!.trim().isNotEmpty) {
    data['locale'] = setting.locale!.trim();
  }
  if (setting.memoVisibility != null &&
      setting.memoVisibility!.trim().isNotEmpty) {
    data['memoVisibility'] = setting.memoVisibility!.trim();
  }
  if (setting.theme != null && setting.theme!.trim().isNotEmpty) {
    data['appearance'] = setting.theme!.trim();
  }
  return data;
}

String _normalizeGeneralSettingMask(List<String> fields) {
  final mapped = <String>{};
  for (final field in fields) {
    final trimmed = field.trim();
    if (trimmed.isEmpty) continue;
    switch (trimmed) {
      case 'memoVisibility':
      case 'memo_visibility':
      case 'generalSetting.memoVisibility':
      case 'general_setting.memo_visibility':
        mapped.add('memo_visibility');
        break;
      case 'locale':
      case 'generalSetting.locale':
      case 'general_setting.locale':
        mapped.add('locale');
        break;
      case 'theme':
      case 'appearance':
      case 'generalSetting.theme':
      case 'general_setting.theme':
      case 'generalSetting.appearance':
      case 'general_setting.appearance':
        mapped.add('theme');
        break;
      default:
        mapped.add(trimmed);
    }
  }
  return mapped.join(',');
}

String _normalizeLegacyGeneralSettingMask(List<String> fields) {
  final mapped = <String>[];
  for (final field in fields) {
    final trimmed = field.trim();
    if (trimmed.isEmpty) continue;
    switch (trimmed) {
      case 'theme':
      case 'appearance':
      case 'generalSetting.theme':
      case 'general_setting.theme':
      case 'generalSetting.appearance':
      case 'general_setting.appearance':
        mapped.add('appearance');
        break;
      case 'memoVisibility':
      case 'memo_visibility':
      case 'generalSetting.memoVisibility':
      case 'general_setting.memo_visibility':
        mapped.add('memo_visibility');
        break;
      case 'locale':
      case 'generalSetting.locale':
      case 'general_setting.locale':
        mapped.add('locale');
        break;
      default:
        mapped.add(trimmed);
    }
  }
  return mapped.toSet().join(',');
}

String _normalizeLegacyReactionType(String reactionType) {
  final trimmed = reactionType.trim();
  if (trimmed.isEmpty) return 'HEART';
  if (trimmed == 'HEART' || trimmed == 'THUMBS_UP') return trimmed;
  if (trimmed == '\u{2764}\u{FE0F}' ||
      trimmed == '\u{2764}' ||
      trimmed == '\u{2665}')
    return 'HEART';
  if (trimmed == '\u{1F44D}') return 'THUMBS_UP';
  return 'HEART';
}

String _extractExploreModernContentQuery(String filter) {
  final normalized = filter.trim();
  if (normalized.isEmpty) return '';
  final match = RegExp(
    r'''content\.contains\("((?:\\.|[^"\\])*)"\)''',
  ).firstMatch(normalized);
  if (match == null) return '';
  return _decodeEscapedFilterString(match.group(1) ?? '');
}

String _decodeEscapedFilterString(String escaped) {
  if (escaped.isEmpty) return '';
  try {
    final decoded = jsonDecode('"$escaped"');
    if (decoded is String) return decoded;
  } catch (_) {
    // Fall back to a conservative unescape for malformed payloads.
  }
  return escaped.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
}

String _normalizeMemoUid(String memoUid) {
  final trimmed = memoUid.trim();
  if (trimmed.startsWith('memos/')) {
    return trimmed.substring('memos/'.length);
  }
  return trimmed;
}

String _normalizeAttachmentUid(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('attachments/')) {
    return trimmed.substring('attachments/'.length);
  }
  if (trimmed.startsWith('resources/')) {
    return trimmed.substring('resources/'.length);
  }
  return trimmed;
}

Memo _legacyPlaceholderMemo(String memoUid, {required bool pinned}) {
  final normalizedUid = memoUid.trim();
  final name = normalizedUid.isEmpty ? '' : 'memos/$normalizedUid';
  return Memo(
    name: name,
    creator: '',
    content: '',
    contentFingerprint: computeContentFingerprint(''),
    visibility: 'PRIVATE',
    pinned: pinned,
    state: 'NORMAL',
    createTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updateTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    tags: const [],
    attachments: const [],
  );
}

Memo _copyMemoWithPinned(Memo memo, bool pinned) {
  return Memo(
    name: memo.name,
    creator: memo.creator,
    content: memo.content,
    contentFingerprint: memo.contentFingerprint,
    visibility: memo.visibility,
    pinned: pinned,
    state: memo.state,
    createTime: memo.createTime,
    updateTime: memo.updateTime,
    tags: memo.tags,
    attachments: memo.attachments,
    displayTime: memo.displayTime,
    location: memo.location,
    relations: memo.relations,
    reactions: memo.reactions,
  );
}

Memo _memoFromLegacy(Map<String, dynamic> json) {
  final id = _readString(json['id']);
  final rawName = _readString(json['name']);
  final name = id.isNotEmpty
      ? 'memos/$id'
      : rawName.startsWith('memos/')
      ? rawName
      : rawName.isNotEmpty
      ? 'memos/$rawName'
      : '';

  final creatorId = _readString(json['creatorId'] ?? json['creator_id']);
  final creatorName = _readString(
    json['creatorName'] ?? json['creator_name'],
  );
  final creator = creatorId.isNotEmpty ? 'users/$creatorId' : creatorName;

  final stateRaw = _readString(
    json['rowStatus'] ?? json['row_status'] ?? json['state'],
  );
  final state = _normalizeLegacyRowStatus(stateRaw) ?? 'NORMAL';

  final attachments = _readLegacyAttachments(
    json['resourceList'] ?? json['resources'] ?? json['attachments'],
  );

  final content = _readString(json['content']);

  return Memo(
    name: name,
    creator: creator,
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: _readString(json['visibility']).isNotEmpty
        ? _readString(json['visibility'])
        : 'PRIVATE',
    pinned: _readBool(json['pinned']),
    state: state,
    createTime: _readLegacyTime(
      json['createdTs'] ?? json['created_ts'] ?? json['createTime'],
    ),
    updateTime: _readLegacyTime(
      json['updatedTs'] ?? json['updated_ts'] ?? json['updateTime'],
    ),
    tags: const [],
    attachments: attachments,
  );
}

List<Attachment> _readLegacyAttachments(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => _attachmentFromLegacy(e.cast<String, dynamic>()))
        .toList(growable: false);
  }
  return const [];
}

Attachment _attachmentFromLegacy(Map<String, dynamic> json) {
  final id = _readString(json['id']);
  final nameRaw = _readString(json['name']);
  final uidRaw = _readString(json['uid']);
  final externalRaw = _readString(
    json['externalLink'] ?? json['external_link'],
  );
  var name = nameRaw.isNotEmpty ? nameRaw : uidRaw;
  if (name.isEmpty && id.isNotEmpty) {
    name = id;
  }
  if (name.isNotEmpty && !name.startsWith('resources/')) {
    name = 'resources/$name';
  }
  final externalLink = externalRaw.isNotEmpty
      ? externalRaw
      : (uidRaw.isNotEmpty ? '/o/r/$uidRaw' : '');
  return Attachment(
    name: name,
    filename: _readString(json['filename']),
    type: _readString(json['type']),
    size: _readInt(json['size']),
    externalLink: externalLink,
  );
}

List<dynamic> _readListPayload(dynamic value) {
  if (value is List) return value;
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return _readListPayload(decoded);
    } catch (_) {
      return const [];
    }
  }
  if (value is Map) {
    final map = value.cast<String, dynamic>();
    final list =
        map['memos'] ??
        map['memoList'] ??
        map['resources'] ??
        map['attachments'] ??
        map['data'];
    if (list is List) return list;
  }
  return const [];
}

String _readString(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

Map<String, dynamic>? _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return false;
}

DateTime _readLegacyTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim()) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  final seconds = _readInt(value);
  if (seconds <= 0)
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

DateTime? _parseStatsDateKey(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    return DateTime.tryParse('${trimmed}T00:00:00Z');
  }
  final parsed = DateTime.tryParse(trimmed);
  return parsed?.toUtc();
}

DateTime? _readTimestamp(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    return parsed?.toUtc();
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

String? _normalizeLegacyRowStatus(String? raw) {
  final normalized = (raw ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return null;
  if (normalized.contains('ARCHIVED')) return 'ARCHIVED';
  if (normalized == 'ACTIVE' || normalized.endsWith('_ACTIVE')) {
    return 'NORMAL';
  }
  if (normalized.contains('NORMAL')) return 'NORMAL';
  return normalized;
}

int? _tryParseLegacyCreatorId(String? filter) {
  final raw = (filter ?? '').trim();
  if (raw.isEmpty) return null;
  final creatorIdMatch = RegExp(r'creator_id\s*==\s*(\d+)').firstMatch(raw);
  if (creatorIdMatch != null) {
    return int.tryParse(creatorIdMatch.group(1) ?? '');
  }
  final creatorNameMatch = RegExp(
    r'''creator\s*==\s*['"]users/(\d+)['"]''',
  ).firstMatch(raw);
  if (creatorNameMatch == null) return null;
  return int.tryParse(creatorNameMatch.group(1) ?? '');
}

String? _buildLegacyV2SearchFilter({
  required String searchQuery,
  int? creatorId,
  String? state,
  String? tag,
  int? startTimeSec,
  int? endTimeSecExclusive,
  required int limit,
}) {
  final conditions = <String>[];

  if (creatorId != null) {
    conditions.add("creator == 'users/$creatorId'");
  }

  final normalizedState = _normalizeLegacyRowStatus(state);
  if (normalizedState != null && normalizedState.isNotEmpty) {
    conditions.add(
      "row_status == '${_escapeLegacyFilterString(normalizedState)}'",
    );
  }

  final terms = <String>{};
  final normalizedSearch = searchQuery.trim();
  if (normalizedSearch.isNotEmpty) {
    terms.add(normalizedSearch);
  }

  final normalizedTag = _normalizeLegacySearchTag(tag);
  if (normalizedTag.isNotEmpty) {
    terms.add('#$normalizedTag');
    terms.add(normalizedTag);
  }

  if (terms.isNotEmpty) {
    final quotedTerms = terms
        .map((term) => "'${_escapeLegacyFilterString(term)}'")
        .join(', ');
    conditions.add('content_search == [$quotedTerms]');
  }

  if (startTimeSec != null) {
    conditions.add('display_time_after == $startTimeSec');
  }
  if (endTimeSecExclusive != null) {
    final endInclusive = endTimeSecExclusive - 1;
    if (endInclusive >= 0) {
      conditions.add('display_time_before == $endInclusive');
    }
  }

  var effectiveLimit = limit;
  if (effectiveLimit <= 0) {
    effectiveLimit = 10;
  }
  if (effectiveLimit > 1000) {
    effectiveLimit = 1000;
  }
  conditions.add('limit == $effectiveLimit');

  if (conditions.isEmpty) return null;
  return conditions.join(' && ');
}

String _normalizeLegacySearchTag(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return '';
  return trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
}

String _escapeLegacyFilterString(String raw) {
  return raw
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', ' ');
}

int? _tryParseLegacyResourceId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.startsWith('resources/')
      ? trimmed.substring('resources/'.length)
      : trimmed;
  final numeric = int.tryParse(normalized);
  if (numeric != null) return numeric;
  return int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
}

Object _legacyMemoIdValue(String memoUid) {
  final trimmed = memoUid.trim();
  final id = int.tryParse(trimmed);
  return id ?? trimmed;
}

Map<String, dynamic> _expectJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is String) {
    final trimmed = value.trimLeft();
    if (_looksLikeHtml(trimmed)) {
      throw const FormatException(
        'Unexpected HTML response. Check server URL or reverse proxy.',
      );
    }
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  throw const FormatException('Expected JSON object');
}

bool _looksLikeHtml(String text) {
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  return lower.startsWith('<!doctype html') || lower.startsWith('<html');
}

String _readStringField(
  Map<String, dynamic> body,
  String key,
  String altKey,
) {
  final primary = body[key];
  if (primary is String) return primary;
  if (primary is num) return primary.toString();
  final alt = body[altKey];
  if (alt is String) return alt;
  if (alt is num) return alt.toString();
  return '';
}

PersonalAccessToken _personalAccessTokenFromLegacyJson(
  Map<String, dynamic> json, {
  required String tokenValue,
}) {
  final issuedAt = _readString(json['issuedAt'] ?? json['issued_at']);
  final expiresAt = _readString(json['expiresAt'] ?? json['expires_at']);
  final description = _readString(json['description']);
  return PersonalAccessToken.fromJson({
    'name': tokenValue,
    'description': description,
    if (issuedAt.isNotEmpty) 'createdAt': issuedAt,
    if (expiresAt.isNotEmpty) 'expiresAt': expiresAt,
  });
}

PersonalAccessToken _personalAccessTokenFromV025Json(
  Map<String, dynamic> json, {
  required String tokenValue,
}) {
  final issuedAt = _readString(json['issuedAt'] ?? json['issued_at']);
  final expiresAt = _readString(json['expiresAt'] ?? json['expires_at']);
  final description = _readString(json['description']);
  final name = _readString(json['name']);
  return PersonalAccessToken.fromJson({
    'name': name.isNotEmpty ? name : tokenValue,
    'description': description,
    if (issuedAt.isNotEmpty) 'createdAt': issuedAt,
    if (expiresAt.isNotEmpty) 'expiresAt': expiresAt,
  });
}
