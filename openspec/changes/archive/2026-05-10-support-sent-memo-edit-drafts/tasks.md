## 1. Draft Data Model And Persistence

- [x] 1.1 Extend `ComposeDraftRecord` / `ComposeDraftSnapshot` with `ComposeDraftKind`, target memo metadata, and serialized existing memo attachments while defaulting absent data to create drafts.
- [x] 1.2 Add additive `compose_drafts` schema migration fields and any suitable index/upsert support for one edit draft per `(workspace_key, target_memo_uid)`.
- [x] 1.3 Add explicit `ComposeDraftRepository` methods for saving, reading, and deleting sent memo edit drafts without overwriting the legacy new-note draft mirror.
- [x] 1.4 Update draft transfer, WebDAV backup, and local migration serialization so create drafts and edit drafts round-trip with optional new fields.

## 2. Edit Draft Session Seam

- [x] 2.1 Extract reusable memo editor edit-draft snapshot/restore mapping into a focused state/helper module outside feature presentation widgets.
- [x] 2.2 Cover the helper with unit tests for content, visibility, location, existing attachments, pending attachments, target memo metadata, and empty/default decode behavior.
- [x] 2.3 Add or tighten an architecture guardrail so edit draft mapping/persistence does not introduce lower-layer imports of memo editor or Draft Box presentation widgets.

## 3. Memo Editor Close Flow

- [x] 3.1 Add a memo editor entry path that can restore an edit draft for an existing `LocalMemo` without treating it as a create draft.
- [x] 3.2 Route page back, app bar close, desktop close, and Escape through a single close-request path for `MemoEditorScreen`.
- [x] 3.3 Implement the unsaved-edit confirmation for existing memos with continue editing, discard changes, and add to Draft Box choices.
- [x] 3.4 Ensure add to Draft Box saves/updates the visible edit draft, clears conflicting hidden recovery state, and closes without updating the original memo.
- [x] 3.5 Ensure discard closes without applying changes and removes any active visible edit draft for that editor session.
- [x] 3.6 Ensure successful save of a restored edit draft updates the original memo and removes that edit draft from Draft Box.
- [x] 3.7 Add localized strings for the prompt, choices, edit draft badge/label, and target-unavailable feedback.

## 4. Draft Box Routing And Presentation

- [x] 4.1 Update Draft Box cards to distinguish edit drafts from create drafts with a clear edit-draft label while preserving existing create-draft presentation.
- [x] 4.2 Update navigation-launched Draft Box selection to route create drafts to `NoteInputSheet(initialDraftUid)` and edit drafts to the existing memo editor.
- [x] 4.3 Add target-memo lookup handling for edit drafts, including a non-create fallback when the original memo cannot be loaded.
- [x] 4.4 Ensure Draft Box refreshes after closing either create-draft or edit-draft editors and does not show duplicate edit drafts for one original memo.

## 5. Tests

- [x] 5.1 Add repository/model tests for create-draft backward compatibility, edit-draft upsert uniqueness, edit-draft delete, and existing attachment serialization.
- [x] 5.2 Add transfer/backup tests proving edit draft metadata and existing attachments round-trip while legacy create draft behavior remains unchanged.
- [x] 5.3 Add memo editor widget tests for close with no changes, continue editing, discard changes, add to Draft Box, and save restored edit draft.
- [x] 5.4 Add Draft Box routing widget tests for create draft selection, edit draft selection, missing target memo, and refresh after editor close.
- [x] 5.5 Run architecture guardrail tests covering compose draft writes and lower-layer presentation imports.

## 6. Verification

- [x] 6.1 Run focused tests for compose draft repository, memo editor draft session, Draft Box, and memo editor flows.
- [x] 6.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.3 Run `flutter test` from `memos_flutter_app`.
