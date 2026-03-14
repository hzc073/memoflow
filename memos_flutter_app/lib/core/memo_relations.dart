import '../data/models/memo_relation.dart';

typedef ReferenceRelationPatch = ({
  List<Map<String, dynamic>> relations,
  bool shouldSync,
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
