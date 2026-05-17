## Extraction Order

This change is applied in behavior-preserving slices. Runtime code should be edited in this order:

1. Baseline focused tests and API-scope confirmation.
2. Remove the concrete `state -> features` tag autocomplete dependency.
3. Extract dependency-free MIME resolution and update note input usage.
4. Split full-screen and compact presentation widgets from `NoteInputSheet`.
5. Extract draft session mapping and submit request assembly.
6. Extract deferred inline image and deferred video orchestration.
7. Tighten architecture guardrails and run verification.

## Responsibility Map

- `NoteInputSheet`: presentation shell, provider wiring, UI callbacks, user-facing snackbars/toasts, empty-content voice fallback.
- `MemoComposerController`: text editing, markdown actions, undo/redo, pending attachments, linked memos, tag autocomplete state.
- `NoteInputController` / future submit coordinator: memo creation, submit payload assembly, deferred inline image append, best-effort sync request.
- `QueuedAttachmentStager`: managed draft/upload file staging.
- Future draft session helper: compose draft snapshot/restore/clear mapping.
- Future deferred media coordinator: share inline image/video progress, cancellation, cleanup, and staged attachment admission.

## Guardrail Intent

The first required modularity improvement is removing `memo_composer_controller.dart -> features/memos/tag_autocomplete.dart` from the architecture allowlist. Later guardrails should prevent lower layers from depending on note input presentation widgets and prevent extracted shared logic from returning to `note_input_sheet.dart`.
