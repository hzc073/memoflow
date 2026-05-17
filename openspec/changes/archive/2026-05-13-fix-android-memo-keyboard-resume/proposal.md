## Why

On Android, users who are creating or editing a memo can switch to another app and return to find that the system keyboard has disappeared even though the editor context remains visible. This interrupts writing flow in the primary memo compose paths and was reported as GitHub issue `#199`.

The active architecture phase is `evolve_modularity`. This change touches feature UI surfaces and the modularity checklist items most relevant here are `4.` shared reusable behavior must not remain hidden inside screen/widget files, `8.` guardrails should protect high-risk behavior where practical, and `10.` touched areas must remain equal or better structured.

## What Changes

- Add Android-only keyboard resume behavior for memo editing surfaces that were actively editing before the app backgrounded.
- Cover these memo compose/edit surfaces:
  - `NoteInputSheet` compact add-memo editor.
  - `NoteInputSheet` full-screen add-memo editor, which shares the same editor focus node.
  - `MemoEditorScreen` edit/new editor.
  - Home inline compose editor in `MemosListScreen` / `MemosListInlineComposeCard`.
- Restore the keyboard only when the same editor was focused and the keyboard was visible before backgrounding.
- Avoid global keyboard restoration from `app.dart`, so unrelated text fields do not unexpectedly reopen the keyboard.
- Extract the reusable lifecycle/IME restoration decision into a feature-local helper or controller seam instead of duplicating the same behavior across screen files.
- No API route, data model, sync, or persistence behavior changes.

## Capabilities

### New Capabilities
- `android-memo-keyboard-resume`: Defines Android keyboard restoration behavior for memo create/edit surfaces after app lifecycle resume.

### Modified Capabilities
- None.

## Impact

- Affected Flutter UI and feature coordination code:
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/memos/memo_editor_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - Potential new feature-local helper under `memos_flutter_app/lib/features/memos/`
- Platform scope: Android only.
- Architecture impact:
  - Must not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies.
  - Should reduce duplication by keeping shared lifecycle restoration policy out of individual screen implementations where possible.
- Testing impact:
  - Add focused widget/unit coverage for the restoration decision policy where possible.
  - Include Android manual verification because system IME visibility is platform-owned and may not be fully assertable in pure widget tests.
