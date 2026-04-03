import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memo_relations.dart';
import '../sync/sync_request.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/memo_location.dart';
import '../attachments/queued_attachment_stager.dart';
import '../../state/memos/create_memo_outbox_enqueue.dart';
import '../../state/memos/create_memo_outbox_payload.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';

class QuickInputService {
  QuickInputService({
    required AppBootstrapAdapter bootstrapAdapter,
    QueuedAttachmentStager? queuedAttachmentStager,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _queuedAttachmentStager =
           queuedAttachmentStager ?? QueuedAttachmentStager();

  final AppBootstrapAdapter _bootstrapAdapter;
  final QueuedAttachmentStager _queuedAttachmentStager;

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

  Future<void> submitQuickInput(
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
    final uploadPayloads = <Map<String, dynamic>>[];
    for (final payload in attachmentPayloads) {
      final rawUid = (payload['uid'] as String? ?? '').trim();
      final filePath = (payload['file_path'] as String? ?? '').trim();
      final filename = (payload['filename'] as String? ?? '').trim();
      final mimeType = (payload['mime_type'] as String? ?? '').trim();
      final fileSize = _readInt(payload['file_size']);
      if (filePath.isEmpty || filename.isEmpty) continue;
      final attachmentUid = rawUid.isEmpty ? generateUid() : rawUid;
      uploadPayloads.add({
        'uid': attachmentUid,
        'memo_uid': uid,
        'file_path': filePath,
        'filename': filename,
        'mime_type': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        'file_size': fileSize,
      });
    }
    final stagedUploadPayloads = await _queuedAttachmentStager
        .stageUploadPayloads(uploadPayloads, scopeKey: uid);
    final attachments = mergePendingAttachmentPlaceholders(
      attachments: const <Map<String, dynamic>>[],
      pendingAttachments: stagedUploadPayloads,
    );
    final normalizedRelations = relations
        .where((relation) => relation.isNotEmpty)
        .toList(growable: false);
    final hasAttachments = attachments.isNotEmpty;
    final cachedRelations = mergeOutgoingReferenceRelations(
      memoUid: uid,
      existingRelations: const [],
      nextRelations: normalizedRelations,
      memoSnippet: content,
    );
    final relationCount = countReferenceRelations(
      memoUid: uid,
      relations: cachedRelations,
    );

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
      relationCount: relationCount,
      syncState: 1,
    );
    if (cachedRelations.isEmpty) {
      await db.deleteMemoRelationsCache(uid);
    } else {
      await db.upsertMemoRelationsCache(
        uid,
        relationsJson: encodeMemoRelationsJson(cachedRelations),
      );
    }

    await enqueueCreateMemoWithAttachmentUploads(
      read: ref.read,
      db: db,
      createPayload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        createTimeSec: nowSec,
        hasAttachments: hasAttachments,
        location: location,
        relations: normalizedRelations,
      ),
      attachmentPayloads: stagedUploadPayloads,
    );

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

  Future<void> submitDesktopQuickInput(
    WidgetRef ref,
    String rawContent, {
    List<Map<String, dynamic>> attachmentPayloads =
        const <Map<String, dynamic>>[],
    MemoLocation? location,
    List<Map<String, dynamic>> relations = const <Map<String, dynamic>>[],
  }) {
    return submitQuickInput(
      ref,
      rawContent,
      attachmentPayloads: attachmentPayloads,
      location: location,
      relations: relations,
    );
  }
}
