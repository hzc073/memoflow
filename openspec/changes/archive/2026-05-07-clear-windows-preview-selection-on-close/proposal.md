## Why

Windows desktop wide layout currently allows the preview pane to be hidden while `DesktopHomePaneState.selectedMemoUid` remains set. This leaves a memo visually or behaviorally selected after the user has closed preview, so plain `Enter` can still target an old memo even though the preview surface is gone.

This change completes the previous Windows preview-selection behavior: closing preview should also exit the memo selection state.

## What Changes

- Treat user-visible preview close actions as memo deselection actions.
- Clear the selected memo keyboard target when the right-side preview pane is closed from the pane close button, `Escape`, or the Windows desktop preview toolbar toggle.
- Keep the existing behavior where focusing inline compose may preserve the visible preview and selected memo until the user explicitly closes or deselects it.
- Preserve inline compose/editor state when closing preview clears memo selection.
- Add regression coverage for the close paths so the hidden-preview/selected-memo split cannot return.
- Avoid API, storage, sync, private hook, billing, or localization changes.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `windows-home-inline-compose-keyboard`: Extend Windows desktop selected preview behavior so closing the preview pane clears the selected memo target and visual selection.

## Impact

- Affected UI behavior: Windows desktop home wide layout and any expanded desktop layout that supports the secondary preview pane.
- Likely touched runtime files:
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/state/memos/desktop_home_pane_state.dart` only if a clearer state-controller method name is needed; existing `deselectMemo()` may be sufficient.
- Likely touched tests:
  - `memos_flutter_app/test/features/memos/memos_list_screen_test.dart`
  - `memos_flutter_app/test/state/memos/desktop_home_pane_state_test.dart` only if state-controller behavior changes.
- No API, data model, storage, sync, commercial/private hook, or localization changes are expected.
- Architecture phase: `evolve_modularity`.
  - Touches checklist item `10.` because the change is in the coupled `MemosListScreen` preview/selection area and must leave that area equal or better structured.
  - The scoped modularity improvement is to reuse or centralize the existing deselect path instead of adding another close-only state mutation, plus tests that guard the close-selection boundary.
