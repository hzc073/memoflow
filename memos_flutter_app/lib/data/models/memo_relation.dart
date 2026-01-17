class MemoRelationMemo {
  const MemoRelationMemo({
    required this.name,
    required this.snippet,
  });

  final String name;
  final String snippet;

  factory MemoRelationMemo.fromJson(Map<String, dynamic> json) {
    return MemoRelationMemo(
      name: (json['name'] as String?) ?? '',
      snippet: (json['snippet'] as String?) ?? '',
    );
  }
}

class MemoRelation {
  const MemoRelation({
    required this.memo,
    required this.relatedMemo,
    required this.type,
  });

  final MemoRelationMemo memo;
  final MemoRelationMemo relatedMemo;
  final String type;

  factory MemoRelation.fromJson(Map<String, dynamic> json) {
    final memoRaw = json['memo'];
    final relatedRaw = json['relatedMemo'] ?? json['related_memo'];
    return MemoRelation(
      memo: memoRaw is Map ? MemoRelationMemo.fromJson(memoRaw.cast<String, dynamic>()) : const MemoRelationMemo(name: '', snippet: ''),
      relatedMemo: relatedRaw is Map
          ? MemoRelationMemo.fromJson(relatedRaw.cast<String, dynamic>())
          : const MemoRelationMemo(name: '', snippet: ''),
      type: (json['type'] as String?) ?? '',
    );
  }
}
