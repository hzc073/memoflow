## 1. Shared Full-Screen Compose Surface

- [x] 1.1 Extract a feature-local `MemoComposeFullscreenSurface` or equivalent shared presentation widget from the existing note input full-screen layout.
- [x] 1.2 Keep the shared surface presentation-only: it receives state, slots, and callbacks, and does not own draft persistence, attachment staging, submit/save orchestration, sync, or mutations.
- [x] 1.3 Adapt `NoteInputFullscreenCompose` to use the shared surface while preserving its existing keys, toolbar rows, close/collapse behavior, visibility behavior, send/voice behavior, and focus behavior.
- [x] 1.4 Add or keep focused regression coverage for note input full-screen layout and state preservation.

## 2. Memo Editor Full-Screen Entry

- [x] 2.1 Add local full-screen compose presentation state to `MemoEditorScreen` for normal mobile/page presentation without opening a new route.
- [x] 2.2 Replace the normal page AppBar top-right save action with a full-screen entry action.
- [x] 2.3 Build memo editor full-screen mode through the shared full-screen surface with editor-specific save/check primary action semantics.
- [x] 2.4 Ensure entering full-screen preserves text, selection, attachments, linked memos, location, visibility, tag autocomplete state, toolbar preferences, and draft identity.
- [x] 2.5 Ensure entering full-screen resets/re-requests editor focus so the active text input client follows the new full-screen editor.

## 3. Close, Collapse, and Save Behavior

- [x] 3.1 Wire full-screen editor close to the existing draft-aware close path.
- [x] 3.2 Wire full-screen editor collapse to return to the normal editor layout without saving and without close confirmation.
- [x] 3.3 Wire full-screen editor save/check primary action to the existing `_save()` path.
- [x] 3.4 Preserve existing Ctrl/Cmd+Enter save shortcuts.
- [x] 3.5 Ensure new memo creation through `MemoEditorScreen(existing: null)` also supports the full-screen entry and save behavior.

## 4. Duplicate Save UI Cleanup

- [x] 4.1 Remove the duplicate header save action from desktop modal editor chrome while keeping fullscreen/restore and close controls.
- [x] 4.2 Remove the duplicate header save action from desktop fullscreen editor chrome while keeping restore and close controls.
- [x] 4.3 Remove the duplicate header save action from embedded editor chrome if the bottom save action remains visible.
- [x] 4.4 Keep the bottom circular save button as the primary save affordance in normal, full-screen, desktop, and embedded editor presentations.

## 5. Tests and Guardrails

- [x] 5.1 Add widget coverage that mobile/page `MemoEditorScreen` shows a full-screen AppBar action instead of a top save action.
- [x] 5.2 Add widget coverage that tapping the editor full-screen action switches to full-screen compose mode and preserves text.
- [x] 5.3 Add widget coverage that full-screen collapse restores the normal editor layout without saving or prompting.
- [x] 5.4 Add widget coverage that full-screen close uses the existing draft-aware close behavior for unsaved existing memo edits.
- [x] 5.5 Add widget coverage that full-screen save uses the existing save path exactly once.
- [x] 5.6 Add widget coverage that desktop/embedded editor chrome does not expose duplicate header save UI when the bottom save action is present.
- [x] 5.7 Add or update architecture/structure guardrail coverage if needed to ensure lower layers do not import the shared full-screen presentation widget.

## 6. Verification

- [x] 6.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 6.2 Run focused memo editor and note input full-screen widget tests.
- [x] 6.3 Run relevant architecture guardrail tests.
- [x] 6.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.5 Run `flutter test` from `memos_flutter_app`.
