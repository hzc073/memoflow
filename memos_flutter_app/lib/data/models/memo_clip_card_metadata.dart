import 'package:flutter/foundation.dart';

enum MemoClipKind { article }

enum MemoClipPlatform { wechat, xiaohongshu, bilibili, coolapk, web }

MemoClipKind memoClipKindFromValue(String? value) {
  return switch ((value ?? '').trim().toLowerCase()) {
    'article' => MemoClipKind.article,
    _ => MemoClipKind.article,
  };
}

String memoClipKindValue(MemoClipKind value) {
  return switch (value) {
    MemoClipKind.article => 'article',
  };
}

MemoClipPlatform memoClipPlatformFromValue(String? value) {
  return switch ((value ?? '').trim().toLowerCase()) {
    'wechat' => MemoClipPlatform.wechat,
    'xiaohongshu' => MemoClipPlatform.xiaohongshu,
    'bilibili' => MemoClipPlatform.bilibili,
    'coolapk' => MemoClipPlatform.coolapk,
    'web' => MemoClipPlatform.web,
    _ => MemoClipPlatform.web,
  };
}

String memoClipPlatformValue(MemoClipPlatform value) {
  return switch (value) {
    MemoClipPlatform.wechat => 'wechat',
    MemoClipPlatform.xiaohongshu => 'xiaohongshu',
    MemoClipPlatform.bilibili => 'bilibili',
    MemoClipPlatform.coolapk => 'coolapk',
    MemoClipPlatform.web => 'web',
  };
}

@immutable
class MemoClipCardMetadata {
  const MemoClipCardMetadata({
    required this.memoUid,
    required this.clipKind,
    required this.platform,
    required this.sourceName,
    required this.sourceAvatarUrl,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.sourceUrl,
    required this.leadImageUrl,
    required this.parserTag,
    required this.createdTime,
    required this.updatedTime,
  });

  final String memoUid;
  final MemoClipKind clipKind;
  final MemoClipPlatform platform;
  final String sourceName;
  final String sourceAvatarUrl;
  final String authorName;
  final String authorAvatarUrl;
  final String sourceUrl;
  final String leadImageUrl;
  final String parserTag;
  final DateTime createdTime;
  final DateTime updatedTime;

  factory MemoClipCardMetadata.fromDb(Map<String, dynamic> row) {
    int readInt(String key) {
      final raw = row[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }

    return MemoClipCardMetadata(
      memoUid: (row['memo_uid'] as String? ?? '').trim(),
      clipKind: memoClipKindFromValue(row['clip_kind'] as String?),
      platform: memoClipPlatformFromValue(row['platform'] as String?),
      sourceName: (row['source_name'] as String? ?? '').trim(),
      sourceAvatarUrl: (row['source_avatar_url'] as String? ?? '').trim(),
      authorName: (row['author_name'] as String? ?? '').trim(),
      authorAvatarUrl: (row['author_avatar_url'] as String? ?? '').trim(),
      sourceUrl: (row['source_url'] as String? ?? '').trim(),
      leadImageUrl: (row['lead_image_url'] as String? ?? '').trim(),
      parserTag: (row['parser_tag'] as String? ?? '').trim(),
      createdTime: DateTime.fromMillisecondsSinceEpoch(
        readInt('created_time') * 1000,
        isUtc: true,
      ).toLocal(),
      updatedTime: DateTime.fromMillisecondsSinceEpoch(
        readInt('updated_time') * 1000,
        isUtc: true,
      ).toLocal(),
    );
  }

  factory MemoClipCardMetadata.fromJson(
    Map<String, dynamic> json, {
    required String memoUid,
    required DateTime fallbackTime,
  }) {
    DateTime readTime(String key) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(raw.trim());
        if (parsed != null) return parsed.toLocal();
      }
      return fallbackTime.toLocal();
    }

    return MemoClipCardMetadata(
      memoUid: memoUid.trim(),
      clipKind: memoClipKindFromValue(json['clipKind'] as String?),
      platform: memoClipPlatformFromValue(json['platform'] as String?),
      sourceName: (json['sourceName'] as String? ?? '').trim(),
      sourceAvatarUrl: (json['sourceAvatarUrl'] as String? ?? '').trim(),
      authorName: (json['authorName'] as String? ?? '').trim(),
      authorAvatarUrl: (json['authorAvatarUrl'] as String? ?? '').trim(),
      sourceUrl: (json['sourceUrl'] as String? ?? '').trim(),
      leadImageUrl: (json['leadImageUrl'] as String? ?? '').trim(),
      parserTag: (json['parserTag'] as String? ?? '').trim(),
      createdTime: readTime('createdTime'),
      updatedTime: readTime('updatedTime'),
    );
  }

  Map<String, Object?> toDbRow() {
    return <String, Object?>{
      'memo_uid': memoUid.trim(),
      'clip_kind': memoClipKindValue(clipKind),
      'platform': memoClipPlatformValue(platform),
      'source_name': sourceName.trim(),
      'source_avatar_url': sourceAvatarUrl.trim(),
      'author_name': authorName.trim(),
      'author_avatar_url': authorAvatarUrl.trim(),
      'source_url': sourceUrl.trim(),
      'lead_image_url': leadImageUrl.trim(),
      'parser_tag': parserTag.trim(),
      'created_time': createdTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      'updated_time': updatedTime.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'clipKind': memoClipKindValue(clipKind),
      'platform': memoClipPlatformValue(platform),
      'sourceName': sourceName.trim(),
      'sourceAvatarUrl': sourceAvatarUrl.trim(),
      'authorName': authorName.trim(),
      'authorAvatarUrl': authorAvatarUrl.trim(),
      'sourceUrl': sourceUrl.trim(),
      'leadImageUrl': leadImageUrl.trim(),
      'parserTag': parserTag.trim(),
    };
  }

  MemoClipCardMetadata copyWith({
    String? memoUid,
    MemoClipKind? clipKind,
    MemoClipPlatform? platform,
    String? sourceName,
    String? sourceAvatarUrl,
    String? authorName,
    String? authorAvatarUrl,
    String? sourceUrl,
    String? leadImageUrl,
    String? parserTag,
    DateTime? createdTime,
    DateTime? updatedTime,
  }) {
    return MemoClipCardMetadata(
      memoUid: memoUid ?? this.memoUid,
      clipKind: clipKind ?? this.clipKind,
      platform: platform ?? this.platform,
      sourceName: sourceName ?? this.sourceName,
      sourceAvatarUrl: sourceAvatarUrl ?? this.sourceAvatarUrl,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      leadImageUrl: leadImageUrl ?? this.leadImageUrl,
      parserTag: parserTag ?? this.parserTag,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }
}
