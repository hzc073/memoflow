import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/logs/log_manager.dart';
import '../settings/workspace_preferences_provider.dart';
import '../sync/sync_coordinator_provider.dart';
export 'note_input_controller.dart'
    show
        NoteInputPendingAttachment,
        NoteInputSubmitCoordinator,
        NoteInputSubmitDraft,
        NoteInputSubmitResult,
        PreparedNoteInputSubmitDraft,
        filterNoteInputDeferredInlineImageRequestsForContent,
        filterNoteInputPendingAttachmentsForContent,
        noteInputAttachmentJsonFromPendingAttachment,
        noteInputPendingUploadFromComposerAttachment,
        noteInputPendingUploadFromShareAttachmentSeed,
        prepareNoteInputSubmitDraft;
import 'note_input_controller.dart';

final noteInputControllerProvider = Provider<NoteInputController>((ref) {
  return NoteInputController(ref);
});

final noteInputSubmitCoordinatorProvider = Provider<NoteInputSubmitCoordinator>(
  (ref) {
    return NoteInputSubmitCoordinator(
      controller: ref.watch(noteInputControllerProvider),
      requestSync: () => ref
          .read(syncCoordinatorProvider.notifier)
          .requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          ),
      logInfo: (message, {context}) {
        LogManager.instance.info(message, context: context);
      },
      logWarn: (message, {error, stackTrace, context}) {
        LogManager.instance.warn(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      },
      currentTagRecognitionPolicy: () =>
          ref.read(currentWorkspacePreferencesProvider).tagRecognitionPolicy,
    );
  },
);
