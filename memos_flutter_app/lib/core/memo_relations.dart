import '../data/models/memo_relation.dart';

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
