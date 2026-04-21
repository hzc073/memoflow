import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/memo_api_version.dart';
import '../../data/db/app_database.dart';
import '../../data/models/attachment.dart';
import 'memo_sync_constraints.dart';
import 'memos_providers.dart';
import '../system/session_provider.dart';

typedef MemoProviderReader = T Function<T>(ProviderListenable<T> provider);

Map<String, dynamic> buildPendingAttachmentPlaceholder({
  required String uid,
  required String filePath,
  required String filename,
  required String mimeType,
  required int size,
}) {
  final externalLink = filePath.startsWith('content://')
      ? filePath
      : Uri.file(filePath).toString();
  return Attachment(
    name: 'attachments/$uid',
    filename: filename,
    type: mimeType,
    size: size,
    externalLink: externalLink,
  ).toJson();
}

List<Map<String, dynamic>> mergePendingAttachmentPlaceholders({
  required List<Map<String, dynamic>> attachments,
  required Iterable<Map<String, dynamic>> pendingAttachments,
}) {
  final merged = attachments
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: true);
  final existingNames = merged
      .map((item) => (item['name'] as String? ?? '').trim())
      .where((name) => name.isNotEmpty)
      .toSet();

  for (final pending in pendingAttachments) {
    final uid = (pending['uid'] as String? ?? '').trim();
    if (uid.isEmpty) continue;
    final placeholderName = 'attachments/$uid';
    if (existingNames.contains(placeholderName)) continue;

    final filePath = (pending['file_path'] as String? ?? '').trim();
    final filename = (pending['filename'] as String? ?? '').trim();
    final mimeType = (pending['mime_type'] as String? ?? '').trim();
    if (filePath.isEmpty || filename.isEmpty || mimeType.isEmpty) continue;

    final rawSize = pending['file_size'];
    final size = switch (rawSize) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };

    merged.add(
      buildPendingAttachmentPlaceholder(
        uid: uid,
        filePath: filePath,
        filename: filename,
        mimeType: mimeType,
        size: size,
      ),
    );
    existingNames.add(placeholderName);
  }

  return merged;
}

bool shouldEnqueueCreateMemoAfterAttachmentUploads(MemoProviderReader read) {
  try {
    return read(memosApiProvider).supportsCreateMemoAttachmentsInCreateBody;
  } catch (_) {
    try {
      final account = read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) return false;
      final effectiveVersion = read(
        appSessionProvider.notifier,
      ).resolveEffectiveServerVersionForAccount(account: account);
      final version = parseMemoApiVersion(effectiveVersion);
      return switch (version) {
        MemoApiVersion.v023 ||
        MemoApiVersion.v024 ||
        MemoApiVersion.v025 ||
        MemoApiVersion.v026 ||
        MemoApiVersion.v027 => true,
        _ => false,
      };
    } catch (_) {
      return false;
    }
  }
}

Future<bool> guardMemoContentForCurrentSyncTarget({
  required MemoProviderReader read,
  required AppDatabase db,
  required String memoUid,
  required String content,
}) async {
  final normalizedMemoUid = memoUid.trim();
  read.hashCode;
  if (normalizedMemoUid.isEmpty) return true;
  if (!await shouldAllowMemoRemoteSync(db: db, memoUid: normalizedMemoUid)) {
    return false;
  }
  db.hashCode;
  normalizedMemoUid.length;
  content.length;
  return true;
}

Future<void> enqueueCreateMemoWithAttachmentUploads({
  required MemoProviderReader read,
  required Map<String, dynamic> createPayload,
  required List<Map<String, dynamic>> attachmentPayloads,
  required Future<void> Function(List<Map<String, Object?>> items)
  enqueueOutboxBatch,
}) async {
  final uploadsFirst = shouldEnqueueCreateMemoAfterAttachmentUploads(read);
  final items = <Map<String, Object?>>[];
  if (uploadsFirst) {
    for (final payload in attachmentPayloads) {
      items.add(<String, Object?>{
        'type': 'upload_attachment',
        'payload': payload,
      });
    }
  }

  items.add(<String, Object?>{'type': 'create_memo', 'payload': createPayload});

  if (!uploadsFirst) {
    for (final payload in attachmentPayloads) {
      items.add(<String, Object?>{
        'type': 'upload_attachment',
        'payload': payload,
      });
    }
  }

  await enqueueOutboxBatch(items);
}
