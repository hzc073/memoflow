## 1. Confirm Current Close Paths

- [x] 1.1 Trace all user-visible desktop preview close entry points in `memos_flutter_app/lib/features/memos/memos_list_screen.dart`: preview pane close button, `Escape`, and `desktop-preview-pane-toggle`.
- [x] 1.2 Confirm which close paths currently call `_closeDesktopPreview()` and whether any path bypasses the shared close helper.
- [x] 1.3 Confirm `DesktopHomePaneStateController.deselectMemo()` preserves `composeDraftTarget` and `editorSurfaceMode` while clearing `selectedMemoUid` and `secondaryPaneMode`.

## 2. Implement Close-As-Deselect Behavior

- [x] 2.1 Update the shared desktop preview close path so closing preview clears the selected memo target by reusing `_deselectDesktopMemo()` or `DesktopHomePaneStateController.deselectMemo()`.
- [x] 2.2 Preserve the existing preview hidden preference update when the user closes preview.
- [x] 2.3 Keep open-preview behavior unchanged for memo taps and the preview toolbar toggle when preview is currently hidden.
- [x] 2.4 Avoid introducing new `state -> features`, `application -> features`, or `core -> higher-layer` imports.

## 3. Regression Coverage

- [x] 3.1 Update the existing `windows wide layout closes preview pane on escape` widget test to assert `selectedMemoUid` is cleared and plain `Enter` no longer opens `MemoDetailScreen`.
- [x] 3.2 Add or update a widget test for the preview pane close button asserting preview hidden, card deselected, and selected memo target cleared.
- [x] 3.3 Add or update a widget test for the `desktop-preview-pane-toggle` close path asserting preview hidden, card deselected, and selected memo target cleared.
- [x] 3.4 Add or update a widget test proving preview close preserves active inline compose draft text.

## 4. Verification

- [x] 4.1 Run `flutter test test/features/memos/memos_list_screen_test.dart` from `memos_flutter_app`.
- [x] 4.2 Run `flutter test test/state/memos/desktop_home_pane_state_test.dart` from `memos_flutter_app` if state-controller code is changed.
- [x] 4.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.4 Run `openspec status --change "clear-windows-preview-selection-on-close"` and confirm the change remains apply-ready.
