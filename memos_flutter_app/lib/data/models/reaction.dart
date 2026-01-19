class Reaction {
  const Reaction({
    required this.name,
    required this.creator,
    required this.contentId,
    required this.reactionType,
    this.legacyId,
  });

  final String name;
  final String creator;
  final String contentId;
  final String reactionType;
  final int? legacyId;

  factory Reaction.fromJson(Map<String, dynamic> json) {
    final legacyIdRaw = json['id'] ?? json['reactionId'] ?? json['reaction_id'];
    final legacyId = legacyIdRaw is num ? legacyIdRaw.toInt() : int.tryParse('${legacyIdRaw ?? ''}');
    return Reaction(
      name: (json['name'] as String?) ?? '',
      creator: (json['creator'] as String?) ?? '',
      contentId: (json['contentId'] as String?) ?? (json['content_id'] as String?) ?? '',
      reactionType: (json['reactionType'] as String?) ?? (json['reaction_type'] as String?) ?? '',
      legacyId: legacyId,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'creator': creator,
      'contentId': contentId,
      'reactionType': reactionType,
    };
    final id = legacyId;
    if (id != null && id > 0) {
      data['id'] = id;
    }
    return data;
  }
}
