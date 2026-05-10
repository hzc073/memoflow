import '../../data/models/attachment.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_location.dart';
import 'memo_composer_state.dart';
import 'note_input_draft_session.dart';

class MemoEditorDraftSessionHelper {
  const MemoEditorDraftSessionHelper();

  ComposeDraftSnapshot buildEditDraftSnapshot({
    required String content,
    required String visibility,
    required List<MemoComposerLinkedMemo> linkedMemos,
    required List<Attachment> existingAttachments,
    required List<MemoComposerPendingAttachment> pendingAttachments,
    required MemoLocation? location,
  }) {
    return ComposeDraftSnapshot(
      content: content,
      visibility: visibility,
      relations: linkedMemos
          .map((memo) => memo.toRelationJson())
          .toList(growable: false),
      attachments: pendingAttachments
          .map(ComposeDraftAttachment.fromPendingAttachment)
          .toList(growable: false),
      existingAttachments: List<Attachment>.from(existingAttachments),
      location: location,
    );
  }

  MemoEditorEditDraftRestoreState restoreEditDraft(
    ComposeDraftRecord draft, {
    required LocalMemo targetMemo,
  }) {
    final snapshot = draft.snapshot;
    final visibility = snapshot.visibility.trim().isEmpty
        ? targetMemo.visibility
        : snapshot.visibility.trim();
    final existingAttachments = List<Attachment>.from(
      snapshot.existingAttachments,
    );
    final pendingAttachments = snapshot.attachments
        .map((attachment) => attachment.toPendingAttachment())
        .toList(growable: false);
    final existingKeys = _attachmentKeySet(existingAttachments);
    final attachmentsToDelete = targetMemo.attachments
        .where(
          (attachment) => !existingKeys.contains(_attachmentKey(attachment)),
        )
        .toList(growable: false);
    final targetMemoUid = draft.targetMemoUid?.trim();
    final contentFingerprint = draft.targetMemoContentFingerprint?.trim();

    return MemoEditorEditDraftRestoreState(
      draftUid: draft.uid,
      targetMemoUid: targetMemoUid == null || targetMemoUid.isEmpty
          ? targetMemo.uid
          : targetMemoUid,
      targetMemoContentFingerprint:
          contentFingerprint == null || contentFingerprint.isEmpty
          ? targetMemo.contentFingerprint
          : contentFingerprint,
      targetMemoUpdateTime: draft.targetMemoUpdateTime ?? targetMemo.updateTime,
      content: snapshot.content,
      visibility: visibility,
      location: snapshot.location,
      linkedMemos: const NoteInputDraftSessionHelper().linkedMemosFromRelations(
        snapshot.relations,
      ),
      existingAttachments: existingAttachments,
      pendingAttachments: pendingAttachments,
      attachmentsToDelete: attachmentsToDelete,
    );
  }

  Set<String> attachmentKeySet(Iterable<Attachment> attachments) {
    return _attachmentKeySet(attachments);
  }
}

class MemoEditorEditDraftRestoreState {
  const MemoEditorEditDraftRestoreState({
    required this.draftUid,
    required this.targetMemoUid,
    required this.targetMemoContentFingerprint,
    required this.targetMemoUpdateTime,
    required this.content,
    required this.visibility,
    required this.location,
    required this.linkedMemos,
    required this.existingAttachments,
    required this.pendingAttachments,
    required this.attachmentsToDelete,
  });

  final String draftUid;
  final String targetMemoUid;
  final String targetMemoContentFingerprint;
  final DateTime targetMemoUpdateTime;
  final String content;
  final String visibility;
  final MemoLocation? location;
  final List<MemoComposerLinkedMemo> linkedMemos;
  final List<Attachment> existingAttachments;
  final List<MemoComposerPendingAttachment> pendingAttachments;
  final List<Attachment> attachmentsToDelete;
}

String _attachmentKey(Attachment attachment) {
  final name = attachment.name.trim();
  if (name.isNotEmpty) return 'name:$name';
  final uid = attachment.uid.trim();
  if (uid.isNotEmpty) return 'uid:$uid';
  return [
    'file',
    attachment.filename.trim(),
    attachment.type.trim(),
    attachment.size.toString(),
    attachment.externalLink.trim(),
  ].join('|');
}

Set<String> _attachmentKeySet(Iterable<Attachment> attachments) {
  return attachments.map(_attachmentKey).where((key) => key.isNotEmpty).toSet();
}
