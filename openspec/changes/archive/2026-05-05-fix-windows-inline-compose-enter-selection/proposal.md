## Why

Windows 首页宽布局中，用户点击笔记会打开右侧 preview 并保留 `selectedMemoUid`。当用户随后聚焦首页 inline compose `TextField` 写新笔记时，普通 `Enter` 有机会被全局 desktop shortcut handler 解释为“打开选中笔记”，导致不能换行。

This change fixes the keyboard ownership conflict so inline compose editing wins over memo-selection shortcuts.

## What Changes

- Prevent plain `Enter` from opening the selected memo while the home inline compose editor is active/focused.
- Add a fallback deselect gesture: clicking the already-selected memo card clears the selected memo state instead of re-opening the same preview.
- Preserve existing Windows wide-layout behavior where plain `Enter` opens the selected preview memo when no text editor owns keyboard input.
- Keep `Shift+Enter` / configured publish shortcuts for inline compose behavior unchanged.
- Add regression coverage for the focused inline compose case and the existing selected-memo Enter case.
- Avoid introducing new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.

## Capabilities

### New Capabilities
- `windows-home-inline-compose-keyboard`: Covers Windows desktop home inline compose keyboard ownership, especially interaction with selected memo preview shortcuts.

### Modified Capabilities
- None.

## Impact

- Affected UI behavior: Windows desktop wide layout on the memo list/home screen.
- Likely touched runtime files:
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/state/memos/desktop_home_pane_state.dart` if a scoped deselect method is needed to avoid using the broader `clear()` reset
  - Possibly `memos_flutter_app/lib/features/memos/memos_list_desktop_shortcut_delegate.dart` if shortcut arbitration is moved behind the existing delegate seam.
- Likely touched tests:
  - `memos_flutter_app/test/features/memos/memos_list_screen_test.dart`
  - Possibly `memos_flutter_app/test/features/memos/memos_list_desktop_shortcut_delegate_test.dart`
- No API, data model, storage, sync, commercial/private hook, or localization changes are expected.
- Architecture phase: `evolve_modularity`.
  - Touches checklist item `10.` because the change is in a coupled UI area and must leave the touched shortcut/selection behavior equal or better structured.
  - The preferred modularity improvement is a guardrail test around desktop shortcut arbitration so the coupled area cannot regress silently.
