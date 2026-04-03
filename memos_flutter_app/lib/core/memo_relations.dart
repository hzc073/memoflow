import 'dart:convert';

import '../data/models/memo_relation.dart';

typedef ReferenceRelationPatch = ({
  List<Map<String, dynamic>> relations,
  bool shouldSync,
});

typedef MemoRelationsSidecarSnapshot = ({
  List<MemoRelation> relations,
  int relationCount,
  bool relationsComplete,
});

int countReferenceRelations({
  required String memoUid,
  required List<MemoRelation> relations,
}) {
  final trimmed = memoUid.trim();
  if (trimmed.isEmpty || relations.isEmpty) return 0;
  final currentName = trimmed.startsWith('memos/') ? trimmed : 'memos/$trimmed';

  final referencing = <String>{};
  final referencedBy = <String>{};
  for (final relation in relations) {
    final type = relation.type.trim().toUpperCase();
    if (type != 'REFERENCE') continue;
    final memoName = relation.memo.name.trim();
    final relatedName = relation.relatedMemo.name.trim();
    if (memoName == currentName && relatedName.isNotEmpty) {
      referencing.add(relatedName);
    } else if (relatedName == currentName && memoName.isNotEmpty) {
      referencedBy.add(memoName);
    }
  }
  return referencing.length + referencedBy.length;
}

List<MemoRelation> mergeOutgoingReferenceRelations({
  required String memoUid,
  required List<MemoRelation> existingRelations,
  required List<Map<String, dynamic>> nextRelations,
  String memoSnippet = '',
}) {
  final currentName = _normalizeMemoRelationName(memoUid);
  if (currentName.isEmpty) {
    return existingRelations.toList(growable: false);
  }

  final merged = <MemoRelation>[];
  for (final relation in existingRelations) {
    final type = relation.type.trim().toUpperCase();
    final memoName = relation.memo.name.trim();
    if (type == 'REFERENCE' && memoName == currentName) {
      continue;
    }
    merged.add(relation);
  }

  merged.addAll(
    _buildOutgoingReferenceRelations(
      memoUid: memoUid,
      relations: nextRelations,
      memoSnippet: memoSnippet,
    ),
  );
  return merged.toList(growable: false);
}

List<Map<String, dynamic>> normalizeReferenceRelationPayloads({
  required String memoUid,
  required List<Map<String, dynamic>> relations,
}) {
  final currentName = _normalizeMemoRelationName(memoUid);
  if (currentName.isEmpty || relations.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final normalizedRelations = <Map<String, dynamic>>[];
  final seenNames = <String>{};
  for (final relation in relations) {
    final relatedName = _readRelatedMemoNameFromPayload(relation);
    final normalizedName = _normalizeMemoRelationName(relatedName);
    if (normalizedName.isEmpty || normalizedName == currentName) {
      continue;
    }
    if (!seenNames.add(normalizedName)) {
      continue;
    }
    normalizedRelations.add(<String, dynamic>{
      'relatedMemo': <String, dynamic>{'name': normalizedName},
      'type': 'REFERENCE',
    });
  }
  return normalizedRelations;
}

ReferenceRelationPatch prepareReferenceRelationPatch({
  required String memoUid,
  required List<Map<String, dynamic>> relations,
}) {
  final currentName = _normalizeMemoRelationName(memoUid);
  if (currentName.isEmpty) {
    return (relations: const <Map<String, dynamic>>[], shouldSync: false);
  }
  return (
    relations: normalizeReferenceRelationPayloads(
      memoUid: memoUid,
      relations: relations,
    ),
    shouldSync: true,
  );
}

MemoRelationsSidecarSnapshot resolveMemoRelationsSidecarSnapshot({
  required int relationCount,
  String? relationsJson,
}) {
  final normalizedRelationCount = relationCount < 0 ? 0 : relationCount;
  final trimmedRelationsJson = relationsJson?.trim();
  if (trimmedRelationsJson == null || trimmedRelationsJson.isEmpty) {
    return (
      relations: const <MemoRelation>[],
      relationCount: normalizedRelationCount,
      relationsComplete: normalizedRelationCount <= 0,
    );
  }

  final relations = decodeMemoRelationsJson(trimmedRelationsJson);
  return (
    relations: relations,
    relationCount: normalizedRelationCount,
    relationsComplete: relations.isNotEmpty || normalizedRelationCount <= 0,
  );
}

String encodeMemoRelationsJson(Iterable<MemoRelation> relations) {
  return jsonEncode(
    relations.map((relation) => relation.toJson()).toList(growable: false),
  );
}

List<MemoRelation> decodeMemoRelationsJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const <MemoRelation>[];
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => MemoRelation.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    }
  } catch (_) {}
  return const <MemoRelation>[];
}

List<MemoRelation> _buildOutgoingReferenceRelations({
  required String memoUid,
  required List<Map<String, dynamic>> relations,
  required String memoSnippet,
}) {
  final currentName = _normalizeMemoRelationName(memoUid);
  if (currentName.isEmpty || relations.isEmpty) {
    return const <MemoRelation>[];
  }

  final items = <MemoRelation>[];
  final seenNames = <String>{};
  final trimmedMemoSnippet = memoSnippet.trim();
  for (final relation in relations) {
    final relatedName = _normalizeMemoRelationName(
      _readRelatedMemoNameFromPayload(relation),
    );
    if (relatedName.isEmpty ||
        relatedName == currentName ||
        !seenNames.add(relatedName)) {
      continue;
    }
    items.add(
      MemoRelation(
        memo: MemoRelationMemo(name: currentName, snippet: trimmedMemoSnippet),
        relatedMemo: MemoRelationMemo(
          name: relatedName,
          snippet: _readRelatedMemoSnippetFromPayload(relation),
        ),
        type: 'REFERENCE',
      ),
    );
  }
  return items.toList(growable: false);
}

String _readRelatedMemoNameFromPayload(Map<String, dynamic> relation) {
  final relatedRaw = relation['relatedMemo'] ?? relation['related_memo'];
  if (relatedRaw is Map) {
    final name = relatedRaw['name'];
    if (name is String) {
      return name.trim();
    }
  }

  final relatedMemoId =
      relation['relatedMemoId'] ?? relation['related_memo_id'];
  if (relatedMemoId is String) {
    return relatedMemoId.trim();
  }
  return '';
}

String _readRelatedMemoSnippetFromPayload(Map<String, dynamic> relation) {
  final relatedRaw = relation['relatedMemo'] ?? relation['related_memo'];
  if (relatedRaw is Map) {
    final snippet = relatedRaw['snippet'];
    if (snippet is String) {
      return snippet.trim();
    }
  }
  return '';
}

String _normalizeMemoRelationName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('memos/')) {
    return trimmed;
  }
  return 'memos/$trimmed';
}
