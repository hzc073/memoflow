## 1. Layout Wiring

- [x] 1.1 Inspect current `NoteInputFullscreenCompose` constructor arguments and confirm no new compose state or submit/visibility callbacks are needed.
- [x] 1.2 Refactor full-screen top chrome so the close control is rendered on the left and the collapse-to-sheet control is rendered on the right.
- [x] 1.3 Remove toolbar row rendering from the full-screen top chrome while keeping the header title-free.
- [x] 1.4 Preserve existing `expandCollapseKey`, `closeKey`, and full-screen visibility/send keys or update call-site wiring only where presentation keys require it.

## 2. Bottom Toolbar

- [x] 2.1 Move `MemoToolbarRow.top` and `MemoToolbarRow.bottom` rendering into a bottom toolbar area inside `NoteInputFullscreenCompose`.
- [x] 2.2 Keep toolbar actions backed by the existing `MemoComposeToolbarActionSpec` list and `MemoToolbarPreferences` visible row ordering.
- [x] 2.3 Add the bottom-right vertical control rail with visibility/permission above the 30px lightweight send/voice button.
- [x] 2.4 Size and pad the bottom toolbar so both right-rail controls keep usable tap targets without covering the editor.
- [x] 2.5 Preserve existing keyboard inset handling so the bottom toolbar and editor remain visible above the system keyboard.

## 3. Behavior Preservation

- [x] 3.1 Verify collapse returns from full-screen mode to compact bottom sheet without losing text, attachments, linked memos, location, visibility, pending media, or tag autocomplete state.
- [x] 3.2 Verify top-left close continues using the existing draft-aware close behavior.
- [x] 3.3 Verify bottom toolbar send/voice continues calling the existing `_submitOrVoice` path.
- [x] 3.4 Verify bottom toolbar visibility continues opening the existing visibility menu from `_visibilityMenuKey`.

## 4. Tests And Guardrails

- [x] 4.1 Update `memos_flutter_app/test/features/memos/note_input_sheet_fullscreen_test.dart` layout assertions for the new top chrome and bottom toolbar placement.
- [x] 4.2 Add or adjust a focused widget assertion that the visibility control is above the full-screen send control in the bottom-right rail.
- [x] 4.3 Keep existing focused tests for content preservation, visibility preservation, collapse, and submit path behavior passing.
- [x] 4.4 Run `flutter test test/features/memos/note_input_sheet_fullscreen_test.dart` from `memos_flutter_app`.
- [x] 4.5 Run `flutter test test/architecture/note_input_decoupling_guardrail_test.dart` from `memos_flutter_app` to confirm no new lower-layer presentation dependency.
- [x] 4.6 If focused tests pass, run `flutter test test/features/memos` from `memos_flutter_app`.

## 5. Review

- [x] 5.1 Review imports in touched files for no new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies.
- [x] 5.2 Confirm the implementation remains presentation-only and does not touch API routes, request/response models, database schema, sync behavior, or private/commercial hooks.
- [x] 5.3 Update this task list with completed checks and any verification gaps before marking the change ready.

## 6. Status Bar Safe Area Follow-up

- [x] 6.1 Preserve the device top system inset when `NoteInputSheet.show` opens the modal bottom sheet route.
- [x] 6.2 Add focused widget coverage that expands through the real modal entry path and keeps full-screen top chrome below the status bar inset.
- [x] 6.3 Re-run focused fullscreen note input tests after the safe-area fix.

## 7. Full-screen Keyboard Follow-up

- [x] 7.1 Request editor focus after switching from compact bottom-sheet mode into full-screen compose mode so the soft keyboard opens automatically.
- [x] 7.2 Guard delayed focus requests so stale callbacks do not focus the editor after the presentation mode has changed again.
- [x] 7.3 Add focused widget coverage that expands with `autoFocus: false` and verifies the full-screen editor requests keyboard input.
- [x] 7.4 Re-run focused fullscreen note input tests after the keyboard-focus change.
- [x] 7.5 Reset the old editor input connection before switching presentation modes so the newly mounted editor owns the caret and text input client.
- [x] 7.6 Add focused widget coverage for expanding when the shared editor focus node already owns focus, including typed input reaching the full-screen editor.

## 8. Full-screen Bottom Toolbar Density Follow-up

- [x] 8.1 Remove decorative circular backgrounds from the full-screen visibility and send controls while preserving their 30px tap targets.
- [x] 8.2 Reduce full-screen bottom toolbar vertical padding and inter-row spacing so the two toolbar rows sit closer together above the keyboard.
- [x] 8.3 Re-run focused full-screen note input layout tests after the density change.
- [x] 8.4 Re-run the note input architecture guardrail after the density change.
