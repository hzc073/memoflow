## 1. Shortcut Arbitration

- [x] 1.1 Add a focused helper or equivalent guard in `MemosListScreen` so selected-memo plain `Enter` is disabled while `_inlineComposeFocusNode.hasFocus`.
- [x] 1.2 Preserve the existing selected-memo plain `Enter` path when no inline editor or other text input owns focus.
- [x] 1.3 Preserve existing inline compose editor shortcuts, including `Shift+Enter` publish fallback and configured publish/formatting shortcuts.
- [x] 1.4 Add a selected-card click toggle so clicking the already-selected memo clears selection instead of re-opening the same preview.
- [x] 1.5 If needed, add a scoped `DesktopHomePaneStateController` deselect method that clears selected memo and preview state without resetting unrelated editor state.

## 2. Regression Coverage

- [x] 2.1 Add a Windows wide-layout widget test where a selected preview memo plus focused home inline compose receives plain `Enter` without opening `MemoDetailScreen`.
- [x] 2.2 Keep or tighten the existing Windows wide-layout test that plain `Enter` opens the selected memo when the inline compose editor is not focused.
- [x] 2.3 Add assertions that the focused inline compose case continues to route editor-owned shortcut behavior without selected-memo navigation.
- [x] 2.4 Add a Windows wide-layout widget test where clicking the already-selected memo clears selected/highlighted state and hides the preview pane.
- [x] 2.5 Add coverage that selected-card deselect preserves inline compose draft text.

## 3. Modularity Guardrail

- [x] 3.1 Keep the fix within the existing `features/memos` screen/delegate seam or a same-layer helper.
- [x] 3.2 Verify the change does not add new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies.

## 4. Validation

- [x] 4.1 Run the focused widget tests for `memos_list_screen_test.dart`.
- [x] 4.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.3 Run `flutter test` from `memos_flutter_app` before PR handoff.
