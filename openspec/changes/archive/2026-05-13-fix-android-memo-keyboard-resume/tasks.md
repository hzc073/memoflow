## 1. Shared Keyboard Resume Policy

- [x] 1.1 Add a feature-local Android memo keyboard resume helper/controller under `memos_flutter_app/lib/features/memos/` with platform gating, lifecycle intent capture, delayed resume restore, and injectable keyboard-show callback for tests.
- [x] 1.2 Implement conservative restore guards: Android only, editor focus owned before backgrounding, keyboard visible before backgrounding, route/surface still current, and surface still eligible after resume.
- [x] 1.3 Ensure the helper does not own memo business state and only receives `FocusNode`, lifecycle, route/currentness, keyboard visibility, and surface eligibility callbacks from each UI owner.

## 2. Surface Integration

- [x] 2.1 Wire `NoteInputSheet` to the shared helper so compact add-memo compose restores keyboard after Android resume.
- [x] 2.2 Verify `NoteInputSheet` full-screen compose is covered through the shared `_editorFocusNode` and remains in full-screen mode after resume.
- [x] 2.3 Wire `MemoEditorScreen` to the shared helper so editing existing memos or edit drafts restores keyboard after Android resume.
- [x] 2.4 Wire `MemosListScreen` home inline compose to the shared helper with inline-compose visibility and `enableCompose` guards.
- [x] 2.5 Confirm keyboard restoration does not trigger memo submit, save, discard, draft mutation, attachment mutation, visibility changes, or sync work.

## 3. Modularity And Guardrails

- [x] 3.1 Keep the restore policy out of `app.dart` and avoid global keyboard restoration for unrelated text inputs.
- [x] 3.2 Confirm no new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies are introduced.
- [x] 3.3 Add or tighten focused tests around the helper policy so shared lifecycle behavior is not duplicated across `NoteInputSheet`, `MemoEditorScreen`, and `MemosListScreen`.

## 4. Verification

- [x] 4.1 Run focused tests for the new helper and affected memo compose/editor behavior.
- [x] 4.2 Run `flutter test test/architecture/modularity_dependency_guardrail_test.dart`.
- [x] 4.3 Run `flutter analyze`.
- [x] 4.4 Run `flutter test`.
- [ ] 4.5 Manually verify on Android: compact note input, full-screen note input, memo editor, and home inline compose each restore keyboard after app switch/resume.
- [ ] 4.6 Manually verify negative cases on Android: keyboard hidden before background, editor unfocused before background, and another modal/route above the editor do not reopen the keyboard.
