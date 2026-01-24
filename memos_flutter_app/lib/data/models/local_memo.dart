import 'dart:convert';

import 'content_fingerprint.dart';
import 'attachment.dart';

enum SyncState {
  synced,
  pending,
  error,
}

class LocalMemo {
  const LocalMemo({
    required this.uid,
    required this.content,
    required this.contentFingerprint,
    required this.visibility,
    required this.pinned,
    required this.state,
    required this.createTime,
    required this.updateTime,
    required this.tags,
    required this.attachments,
    required this.syncState,
    required this.lastError,
  });

  final String uid;
  final String content;
  final String contentFingerprint;
  final String visibility;
  final bool pinned;
  final String state;
  final DateTime createTime;
  final DateTime updateTime;
  final List<String> tags;
  final List<Attachment> attachments;
  final SyncState syncState;
  final String? lastError;

  factory LocalMemo.fromDb(Map<String, dynamic> row) {
    final content = (row['content'] as String?) ?? '';
    final tagsText = (row['tags'] as String?) ?? '';
    final attachmentsJson = (row['attachments_json'] as String?) ?? '[]';

    final attachments = <Attachment>[];
    try {
      final decoded = jsonDecode(attachmentsJson);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            attachments.add(Attachment.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
    } catch (_) {}

    final syncStateInt = (row['sync_state'] as int?) ?? 0;
    final syncState = switch (syncStateInt) {
      1 => SyncState.pending,
      2 => SyncState.error,
      _ => SyncState.synced,
    };

    final contentFingerprint = computeContentFingerprint(content);

    return LocalMemo(
      uid: (row['uid'] as String?) ?? '',
      content: content,
      contentFingerprint: contentFingerprint,
      visibility: (row['visibility'] as String?) ?? 'PRIVATE',
      pinned: ((row['pinned'] as int?) ?? 0) == 1,
      state: (row['state'] as String?) ?? 'NORMAL',
      createTime: DateTime.fromMillisecondsSinceEpoch(((row['create_time'] as int?) ?? 0) * 1000, isUtc: true).toLocal(),
      updateTime: DateTime.fromMillisecondsSinceEpoch(((row['update_time'] as int?) ?? 0) * 1000, isUtc: true).toLocal(),
      tags: tagsText.isEmpty ? const [] : tagsText.split(' ').where((t) => t.isNotEmpty).toList(growable: false),
      attachments: attachments,
      syncState: syncState,
      lastError: row['last_error'] as String?,
    );
  }
}
