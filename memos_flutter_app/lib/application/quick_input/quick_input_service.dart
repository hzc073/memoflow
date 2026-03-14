import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_request.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/memo_location.dart';
import '../../state/memos/create_memo_outbox_payload.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';

class QuickInputService {
  QuickInputService({required AppBootstrapAdapter bootstrapAdapter})
    : _bootstrapAdapter = bootstrapAdapter;

  final AppBootstrapAdapter _bootstrapAdapter;

  List<Map<String, dynamic>> parsePayloadMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = <String, dynamic>{};
      item.forEach((key, value) {
        final normalizedKey = key?.toString().trim() ?? '';
        if (normalizedKey.isEmpty) return;
        map[normalizedKey] = value;
      });
      if (map.isNotEmpty) {
        list.add(map);
      }
    }
    return list;
  }

  MemoLocation? parseLocation(dynamic raw) {
    if (raw is! Map) return null;
    final map = <String, dynamic>{};
    raw.forEach((key, value) {
      final normalizedKey = key?.toString().trim() ?? '';
      if (normalizedKey.isEmpty) return;
      map[normalizedKey] = value;
    });
    return MemoLocation.fromJson(map);
  }

  String resolveVisibility(WidgetRef ref) {
    final settings = _bootstrapAdapter.readUserGeneralSetting(ref);
    final value = (settings?.memoVisibility ?? '').trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<void> submitDesktopQuickInput(
    WidgetRef ref,
    String rawContent, {
    List<Map<String, dynamic>> attachmentPayloads =
        const <Map<String, dynamic>>[],
    MemoLocation? location,
    List<Map<String, dynamic>> relations = const <Map<String, dynamic>>[],
  }) async {
    final content = rawContent.trimRight();
    if (content.trim().isEmpty && attachmentPayloads.isEmpty) return;

    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final uid = generateUid();
    final visibility = resolveVisibility(ref);
    final db = _bootstrapAdapter.readDatabase(ref);
    final tags = extractTags(content);
    final attachments = <Map<String, dynamic>>[];
    final uploadPayloads = <Map<String, dynamic>>[];
    for (final payload in attachmentPayloads) {
      final rawUid = (payload['uid'] as String? ?? '').trim();
      final filePath = (payload['file_path'] as String? ?? '').trim();
      final filename = (payload['filename'] as String? ?? '').trim();
      final mimeType = (payload['mime_type'] as String? ?? '').trim();
      final fileSize = _readInt(payload['file_size']);
      if (filePath.isEmpty || filename.isEmpty) continue;
      final attachmentUid = rawUid.isEmpty ? generateUid() : rawUid;
      final externalLink = filePath.startsWith('content://')
          ? filePath
          : Uri.file(filePath).toString();
      attachments.add(
        Attachment(
          name: 'attachments/$attachmentUid',
          filename: filename,
          type: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
          size: fileSize,
          externalLink: externalLink,
        ).toJson(),
      );
      uploadPayloads.add({
        'uid': attachmentUid,
        'memo_uid': uid,
        'file_path': filePath,
        'filename': filename,
        'mime_type': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        'file_size': fileSize,
      });
    }
    final normalizedRelations = relations
        .where((relation) => relation.isNotEmpty)
        .toList(growable: false);
    final hasAttachments = attachments.isNotEmpty;

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: nowSec,
      updateTimeSec: nowSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: 0,
      syncState: 1,
    );

    await db.enqueueOutbox(
      type: 'create_memo',
      payload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        createTimeSec: nowSec,
        hasAttachments: hasAttachments,
        location: location,
        relations: normalizedRelations,
      ),
    );

    for (final payload in uploadPayloads) {
      await db.enqueueOutbox(type: 'upload_attachment', payload: payload);
    }

    unawaited(
      _bootstrapAdapter.requestSync(
        ref,
        const SyncRequest(
          kind: SyncRequestKind.memos,
          reason: SyncRequestReason.manual,
        ),
      ),
    );
  }
}
