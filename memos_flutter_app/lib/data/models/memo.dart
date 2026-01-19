import 'attachment.dart';
import 'memo_relation.dart';
import 'reaction.dart';

class Memo {
  const Memo({
    required this.name,
    required this.creator,
    required this.content,
    required this.visibility,
    required this.pinned,
    required this.state,
    required this.createTime,
    required this.updateTime,
    required this.tags,
    required this.attachments,
    this.displayTime,
    this.relations = const [],
    this.reactions = const [],
  });

  final String name;
  final String creator;
  final String content;
  final String visibility;
  final bool pinned;
  final String state;
  final DateTime createTime;
  final DateTime updateTime;
  final DateTime? displayTime;
  final List<String> tags;
  final List<Attachment> attachments;
  final List<MemoRelation> relations;
  final List<Reaction> reactions;

  String get uid => name.startsWith('memos/') ? name.substring('memos/'.length) : name;

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      name: (json['name'] as String?) ?? '',
      creator: (json['creator'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      visibility: (json['visibility'] as String?) ?? 'PRIVATE',
      pinned: (json['pinned'] as bool?) ?? false,
      state: (json['state'] as String?) ?? 'NORMAL',
      createTime: _parseTime(json['createTime']),
      updateTime: _parseTime(json['updateTime']),
      displayTime: _parseOptionalTime(json['displayTime'] ?? json['display_time']),
      tags: _parseStringList(json['tags']),
      attachments: _parseAttachmentList(json['attachments'] ?? json['resources']),
      relations: _parseRelations(json['relations']),
      reactions: _parseReactions(json['reactions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'creator': creator,
      'content': content,
      'visibility': visibility,
      'pinned': pinned,
      'state': state,
      'createTime': createTime.toUtc().toIso8601String(),
      'updateTime': updateTime.toUtc().toIso8601String(),
      if (displayTime != null) 'displayTime': displayTime!.toUtc().toIso8601String(),
      'tags': tags,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'relations': relations
          .map(
            (r) => {
              'memo': {'name': r.memo.name, 'snippet': r.memo.snippet},
              'relatedMemo': {'name': r.relatedMemo.name, 'snippet': r.relatedMemo.snippet},
              'type': r.type,
            },
          )
          .toList(),
      'reactions': reactions
          .map((r) => r.toJson())
          .toList(),
    };
  }

  static DateTime _parseTime(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static List<String> _parseStringList(dynamic v) {
    if (v is List) {
      return v.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static List<Attachment> _parseAttachmentList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Attachment.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    }
    return const [];
  }

  static DateTime? _parseOptionalTime(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  static List<MemoRelation> _parseRelations(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => MemoRelation.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    }
    return const [];
  }

  static List<Reaction> _parseReactions(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Reaction.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    }
    return const [];
  }
}
