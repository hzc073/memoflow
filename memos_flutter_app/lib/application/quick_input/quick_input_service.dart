import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_request.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/memo_location.dart';
import '../attachments/queued_attachment_stager.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/memo_mutation_service.dart';
import '../../state/settings/workspace_preferences_provider.dart';

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
    final tagRecognitionPolicy = ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    final tags = extractTags(content, policy: tagRecognitionPolicy);
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
    final normalizedRelations = relations
        .where((relation) => relation.isNotEmpty)
        .toList(growable: false);
    final pendingAttachments = stagedUploadPayloads
        .map(
          (payload) => MemoComposerPendingAttachment(
            uid: (payload['uid'] as String? ?? '').trim(),
            filePath: (payload['file_path'] as String? ?? '').trim(),
            filename: (payload['filename'] as String? ?? '').trim(),
            mimeType: (payload['mime_type'] as String? ?? '').trim().isEmpty
                ? 'application/octet-stream'
                : (payload['mime_type'] as String).trim(),
            size: _readInt(payload['file_size']),
          ),
        )
        .where(
          (attachment) =>
              attachment.uid.isNotEmpty &&
              attachment.filePath.isNotEmpty &&
              attachment.filename.isNotEmpty,
        )
        .toList(growable: false);

    await ref
        .read(memoMutationServiceProvider)
        .createInlineComposeMemo(
          uid: uid,
          content: content,
          visibility: visibility,
          nowSec: nowSec,
          tags: tags,
          attachments: const <Map<String, dynamic>>[],
          location: location,
          relations: normalizedRelations,
          pendingAttachments: pendingAttachments,
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
