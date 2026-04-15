import 'dart:convert';

import '../../core/tags.dart';

enum MemoCollectionType { smart, manual }

enum CollectionTagMatchMode { any, all }

enum CollectionVisibilityScope { all, privateOnly, publicOnly }

enum CollectionDateRuleType { all, lastDays, customRange }

enum CollectionAttachmentRule { any, required, excluded, imagesOnly }

enum CollectionCoverMode { auto, attachment, icon }

enum CollectionLayoutMode { shelf, timeline, list }

enum CollectionSectionMode { none, month, quarter, year }

enum CollectionSortMode {
  displayTimeDesc,
  displayTimeAsc,
  updateTimeDesc,
  updateTimeAsc,
  manualOrder,
}

class CollectionDateRule {
  const CollectionDateRule({
    required this.type,
    this.lastDays,
    this.startTimeSec,
    this.endTimeSecExclusive,
  });

  static const CollectionDateRule defaults = CollectionDateRule(
    type: CollectionDateRuleType.all,
  );

  final CollectionDateRuleType type;
  final int? lastDays;
  final int? startTimeSec;
  final int? endTimeSecExclusive;

  bool get hasConstraint {
    return switch (type) {
      CollectionDateRuleType.all => false,
      CollectionDateRuleType.lastDays => (lastDays ?? 0) > 0,
      CollectionDateRuleType.customRange =>
        startTimeSec != null || endTimeSecExclusive != null,
    };
  }

  CollectionDateRule copyWith({
    CollectionDateRuleType? type,
    Object? lastDays = _unset,
    Object? startTimeSec = _unset,
    Object? endTimeSecExclusive = _unset,
  }) {
    return CollectionDateRule(
      type: type ?? this.type,
      lastDays: identical(lastDays, _unset) ? this.lastDays : lastDays as int?,
      startTimeSec: identical(startTimeSec, _unset)
          ? this.startTimeSec
          : startTimeSec as int?,
      endTimeSecExclusive: identical(endTimeSecExclusive, _unset)
          ? this.endTimeSecExclusive
          : endTimeSecExclusive as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'lastDays': lastDays,
    'startTimeSec': startTimeSec,
    'endTimeSecExclusive': endTimeSecExclusive,
  };

  factory CollectionDateRule.fromJson(Map<String, dynamic> json) {
    return CollectionDateRule(
      type: _readEnum(
        json['type'],
        CollectionDateRuleType.values,
        defaults.type,
      ),
      lastDays: _readNullableInt(json['lastDays']),
      startTimeSec: _readNullableInt(json['startTimeSec']),
      endTimeSecExclusive: _readNullableInt(json['endTimeSecExclusive']),
    );
  }
}

class CollectionRuleSet {
  const CollectionRuleSet({
    required this.tagPaths,
    required this.tagMatchMode,
    required this.includeDescendants,
    required this.visibility,
    required this.dateRule,
    required this.attachmentRule,
    required this.pinnedOnly,
  });

  static const CollectionRuleSet defaults = CollectionRuleSet(
    tagPaths: <String>[],
    tagMatchMode: CollectionTagMatchMode.any,
    includeDescendants: true,
    visibility: CollectionVisibilityScope.all,
    dateRule: CollectionDateRule.defaults,
    attachmentRule: CollectionAttachmentRule.any,
    pinnedOnly: false,
  );

  final List<String> tagPaths;
  final CollectionTagMatchMode tagMatchMode;
  final bool includeDescendants;
  final CollectionVisibilityScope visibility;
  final CollectionDateRule dateRule;
  final CollectionAttachmentRule attachmentRule;
  final bool pinnedOnly;

  List<String> get normalizedTagPaths {
    final normalized = <String>{};
    for (final raw in tagPaths) {
      final path = normalizeTagPath(raw);
      if (path.isEmpty) continue;
      normalized.add(path);
    }
    final list = normalized.toList(growable: false)..sort();
    return list;
  }

  bool get hasAnyConstraint {
    return normalizedTagPaths.isNotEmpty ||
        visibility != CollectionVisibilityScope.all ||
        dateRule.hasConstraint ||
        attachmentRule != CollectionAttachmentRule.any ||
        pinnedOnly;
  }

  CollectionRuleSet copyWith({
    List<String>? tagPaths,
    CollectionTagMatchMode? tagMatchMode,
    bool? includeDescendants,
    CollectionVisibilityScope? visibility,
    CollectionDateRule? dateRule,
    CollectionAttachmentRule? attachmentRule,
    bool? pinnedOnly,
  }) {
    return CollectionRuleSet(
      tagPaths: tagPaths ?? this.tagPaths,
      tagMatchMode: tagMatchMode ?? this.tagMatchMode,
      includeDescendants: includeDescendants ?? this.includeDescendants,
      visibility: visibility ?? this.visibility,
      dateRule: dateRule ?? this.dateRule,
      attachmentRule: attachmentRule ?? this.attachmentRule,
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'tagPaths': normalizedTagPaths,
    'tagMatchMode': tagMatchMode.name,
    'includeDescendants': includeDescendants,
    'visibility': visibility.name,
    'dateRule': dateRule.toJson(),
    'attachmentRule': attachmentRule.name,
    'pinnedOnly': pinnedOnly,
  };

  factory CollectionRuleSet.fromJson(Map<String, dynamic> json) {
    final rawTagPaths = json['tagPaths'];
    final tagPaths = <String>[];
    if (rawTagPaths is List) {
      for (final item in rawTagPaths) {
        if (item is! String) continue;
        final normalized = normalizeTagPath(item);
        if (normalized.isEmpty) continue;
        tagPaths.add(normalized);
      }
    }
    return CollectionRuleSet(
      tagPaths: tagPaths,
      tagMatchMode: _readEnum(
        json['tagMatchMode'],
        CollectionTagMatchMode.values,
        defaults.tagMatchMode,
      ),
      includeDescendants:
          (json['includeDescendants'] as bool?) ?? defaults.includeDescendants,
      visibility: _readEnum(
        json['visibility'],
        CollectionVisibilityScope.values,
        defaults.visibility,
      ),
      dateRule: () {
        final raw = json['dateRule'];
        if (raw is Map) {
          return CollectionDateRule.fromJson(raw.cast<String, dynamic>());
        }
        return defaults.dateRule;
      }(),
      attachmentRule: _readEnum(
        json['attachmentRule'],
        CollectionAttachmentRule.values,
        defaults.attachmentRule,
      ),
      pinnedOnly: (json['pinnedOnly'] as bool?) ?? defaults.pinnedOnly,
    );
  }
}

class CollectionCoverSpec {
  const CollectionCoverSpec({
    required this.mode,
    this.memoUid,
    this.attachmentUid,
    this.iconKey,
  });

  static const CollectionCoverSpec defaults = CollectionCoverSpec(
    mode: CollectionCoverMode.auto,
  );

  final CollectionCoverMode mode;
  final String? memoUid;
  final String? attachmentUid;
  final String? iconKey;

  CollectionCoverSpec copyWith({
    CollectionCoverMode? mode,
    Object? memoUid = _unset,
    Object? attachmentUid = _unset,
    Object? iconKey = _unset,
  }) {
    return CollectionCoverSpec(
      mode: mode ?? this.mode,
      memoUid: identical(memoUid, _unset) ? this.memoUid : memoUid as String?,
      attachmentUid: identical(attachmentUid, _unset)
          ? this.attachmentUid
          : attachmentUid as String?,
      iconKey: identical(iconKey, _unset) ? this.iconKey : iconKey as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'memoUid': memoUid,
    'attachmentUid': attachmentUid,
    'iconKey': iconKey,
  };

  factory CollectionCoverSpec.fromJson(Map<String, dynamic> json) {
    return CollectionCoverSpec(
      mode: _readEnum(json['mode'], CollectionCoverMode.values, defaults.mode),
      memoUid: _readNullableString(json['memoUid']),
      attachmentUid: _readNullableString(json['attachmentUid']),
      iconKey: _readNullableString(json['iconKey']),
    );
  }
}

class CollectionViewPreferences {
  const CollectionViewPreferences({
    required this.defaultLayout,
    required this.sectionMode,
    required this.sortMode,
    required this.showStats,
  });

  static const CollectionViewPreferences defaults = CollectionViewPreferences(
    defaultLayout: CollectionLayoutMode.shelf,
    sectionMode: CollectionSectionMode.none,
    sortMode: CollectionSortMode.displayTimeDesc,
    showStats: true,
  );

  final CollectionLayoutMode defaultLayout;
  final CollectionSectionMode sectionMode;
  final CollectionSortMode sortMode;
  final bool showStats;

  CollectionViewPreferences copyWith({
    CollectionLayoutMode? defaultLayout,
    CollectionSectionMode? sectionMode,
    CollectionSortMode? sortMode,
    bool? showStats,
  }) {
    return CollectionViewPreferences(
      defaultLayout: defaultLayout ?? this.defaultLayout,
      sectionMode: sectionMode ?? this.sectionMode,
      sortMode: sortMode ?? this.sortMode,
      showStats: showStats ?? this.showStats,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultLayout': defaultLayout.name,
    'sectionMode': sectionMode.name,
    'sortMode': sortMode.name,
    'showStats': showStats,
  };

  factory CollectionViewPreferences.fromJson(Map<String, dynamic> json) {
    return CollectionViewPreferences(
      defaultLayout: _readEnum(
        json['defaultLayout'],
        CollectionLayoutMode.values,
        defaults.defaultLayout,
      ),
      sectionMode: _readEnum(
        json['sectionMode'],
        CollectionSectionMode.values,
        defaults.sectionMode,
      ),
      sortMode: _readEnum(
        json['sortMode'],
        CollectionSortMode.values,
        defaults.sortMode,
      ),
      showStats: (json['showStats'] as bool?) ?? defaults.showStats,
    );
  }
}

class MemoCollection {
  const MemoCollection({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.iconKey,
    required this.accentColorHex,
    required this.rules,
    required this.cover,
    required this.view,
    required this.pinned,
    required this.archived,
    required this.hideWhenEmpty,
    required this.sortOrder,
    required this.createdTime,
    required this.updatedTime,
  });

  static const String defaultIconKey = 'auto_stories';

  static MemoCollection createSmart({
    required String id,
    required String title,
    String description = '',
    String iconKey = defaultIconKey,
    String? accentColorHex,
    CollectionRuleSet rules = CollectionRuleSet.defaults,
    CollectionCoverSpec cover = CollectionCoverSpec.defaults,
    CollectionViewPreferences view = CollectionViewPreferences.defaults,
    bool pinned = false,
    bool archived = false,
    bool hideWhenEmpty = false,
    int sortOrder = 0,
    DateTime? createdTime,
    DateTime? updatedTime,
  }) {
    final now = DateTime.now();
    return MemoCollection(
      id: id,
      title: title,
      description: description,
      type: MemoCollectionType.smart,
      iconKey: iconKey,
      accentColorHex: accentColorHex,
      rules: rules,
      cover: cover,
      view: view,
      pinned: pinned,
      archived: archived,
      hideWhenEmpty: hideWhenEmpty,
      sortOrder: sortOrder,
      createdTime: createdTime ?? now,
      updatedTime: updatedTime ?? now,
    );
  }

  static MemoCollection createManual({
    required String id,
    required String title,
    String description = '',
    String iconKey = defaultIconKey,
    String? accentColorHex,
    CollectionCoverSpec cover = CollectionCoverSpec.defaults,
    CollectionViewPreferences view = const CollectionViewPreferences(
      defaultLayout: CollectionLayoutMode.shelf,
      sectionMode: CollectionSectionMode.none,
      sortMode: CollectionSortMode.manualOrder,
      showStats: true,
    ),
    bool pinned = false,
    bool archived = false,
    bool hideWhenEmpty = false,
    int sortOrder = 0,
    DateTime? createdTime,
    DateTime? updatedTime,
  }) {
    final now = DateTime.now();
    return MemoCollection(
      id: id,
      title: title,
      description: description,
      type: MemoCollectionType.manual,
      iconKey: iconKey,
      accentColorHex: accentColorHex,
      rules: CollectionRuleSet.defaults,
      cover: cover,
      view: view,
      pinned: pinned,
      archived: archived,
      hideWhenEmpty: hideWhenEmpty,
      sortOrder: sortOrder,
      createdTime: createdTime ?? now,
      updatedTime: updatedTime ?? now,
    );
  }

  final String id;
  final String title;
  final String description;
  final MemoCollectionType type;
  final String iconKey;
  final String? accentColorHex;
  final CollectionRuleSet rules;
  final CollectionCoverSpec cover;
  final CollectionViewPreferences view;
  final bool pinned;
  final bool archived;
  final bool hideWhenEmpty;
  final int sortOrder;
  final DateTime createdTime;
  final DateTime updatedTime;

  bool get isSmart => type == MemoCollectionType.smart;
  bool get isManual => type == MemoCollectionType.manual;

  MemoCollection copyWith({
    String? id,
    String? title,
    String? description,
    MemoCollectionType? type,
    String? iconKey,
    Object? accentColorHex = _unset,
    CollectionRuleSet? rules,
    CollectionCoverSpec? cover,
    CollectionViewPreferences? view,
    bool? pinned,
    bool? archived,
    bool? hideWhenEmpty,
    int? sortOrder,
    DateTime? createdTime,
    DateTime? updatedTime,
  }) {
    return MemoCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      accentColorHex: identical(accentColorHex, _unset)
          ? this.accentColorHex
          : accentColorHex as String?,
      rules: rules ?? this.rules,
      cover: cover ?? this.cover,
      view: view ?? this.view,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      hideWhenEmpty: hideWhenEmpty ?? this.hideWhenEmpty,
      sortOrder: sortOrder ?? this.sortOrder,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'iconKey': iconKey,
    'accentColorHex': accentColorHex,
    'rules': rules.toJson(),
    'cover': cover.toJson(),
    'view': view.toJson(),
    'pinned': pinned,
    'archived': archived,
    'hideWhenEmpty': hideWhenEmpty,
    'sortOrder': sortOrder,
    'createdTime': createdTime.toUtc().millisecondsSinceEpoch ~/ 1000,
    'updatedTime': updatedTime.toUtc().millisecondsSinceEpoch ~/ 1000,
  };

  factory MemoCollection.fromJson(Map<String, dynamic> json) {
    return MemoCollection(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      type: _readEnum(
        json['type'],
        MemoCollectionType.values,
        MemoCollectionType.smart,
      ),
      iconKey: (json['iconKey'] as String?) ?? defaultIconKey,
      accentColorHex: _readNullableString(json['accentColorHex']),
      rules: () {
        final raw = json['rules'];
        if (raw is Map) {
          return CollectionRuleSet.fromJson(raw.cast<String, dynamic>());
        }
        return CollectionRuleSet.defaults;
      }(),
      cover: () {
        final raw = json['cover'];
        if (raw is Map) {
          return CollectionCoverSpec.fromJson(raw.cast<String, dynamic>());
        }
        return CollectionCoverSpec.defaults;
      }(),
      view: () {
        final raw = json['view'];
        if (raw is Map) {
          return CollectionViewPreferences.fromJson(
            raw.cast<String, dynamic>(),
          );
        }
        return CollectionViewPreferences.defaults;
      }(),
      pinned: (json['pinned'] as bool?) ?? false,
      archived: (json['archived'] as bool?) ?? false,
      hideWhenEmpty: (json['hideWhenEmpty'] as bool?) ?? false,
      sortOrder: _readNullableInt(json['sortOrder']) ?? 0,
      createdTime: _readDateTimeSeconds(json['createdTime']),
      updatedTime: _readDateTimeSeconds(json['updatedTime']),
    );
  }

  factory MemoCollection.fromDb(Map<String, dynamic> row) {
    Map<String, dynamic> parseJsonObject(dynamic raw) {
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded.cast<String, dynamic>();
          }
        } catch (_) {}
      }
      return <String, dynamic>{};
    }

    return MemoCollection(
      id: (row['id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      type: _readEnum(
        row['type'],
        MemoCollectionType.values,
        MemoCollectionType.smart,
      ),
      iconKey: (row['icon_key'] as String?) ?? defaultIconKey,
      accentColorHex: _readNullableString(row['accent_color_hex']),
      rules: CollectionRuleSet.fromJson(parseJsonObject(row['rules_json'])),
      cover: CollectionCoverSpec.fromJson(parseJsonObject(row['cover_json'])),
      view: CollectionViewPreferences.fromJson(
        parseJsonObject(row['view_json']),
      ),
      pinned: ((row['pinned'] as int?) ?? 0) == 1,
      archived: ((row['archived'] as int?) ?? 0) == 1,
      hideWhenEmpty: ((row['hide_when_empty'] as int?) ?? 0) == 1,
      sortOrder: (row['sort_order'] as int?) ?? 0,
      createdTime: _readDateTimeSeconds(row['created_time']),
      updatedTime: _readDateTimeSeconds(row['updated_time']),
    );
  }
}

const Object _unset = Object();

T _readEnum<T>(Object? raw, List<T> values, T fallback) {
  if (raw is String) {
    for (final value in values) {
      if ('$value'.split('.').last == raw) {
        return value;
      }
    }
  }
  return fallback;
}

String? _readNullableString(Object? raw) {
  if (raw is String) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

int? _readNullableInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

DateTime _readDateTimeSeconds(Object? raw) {
  final seconds = _readNullableInt(raw) ?? 0;
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
}
