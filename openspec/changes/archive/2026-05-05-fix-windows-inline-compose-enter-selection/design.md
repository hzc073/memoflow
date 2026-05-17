## Context

Windows wide home layout currently supports a desktop preview workflow: clicking a memo opens the right-side preview pane and stores the memo uid in `DesktopHomePaneState.selectedMemoUid`. The same selected uid also drives card highlight and the plain `Enter` shortcut that opens the full `MemoDetailScreen`.

首页 inline compose is a multiline `TextField`, so plain `Enter` should insert a line break while it owns focus. The bug appears when `HardwareKeyboard.instance.addHandler(_handleDesktopShortcuts)` observes the key before the current `_isTextInputFocused()` check reliably classifies the inline composer as text input. The result is a conflict:

```
selected memo exists
  + plain Enter
  + Windows wide layout
  + text-input guard misses inline compose
  = open selected memo instead of newline
```

The active architecture phase is `evolve_modularity`. This change touches a coupled UI area (`MemosListScreen` shortcut/selection behavior), so it must leave the touched area equal or better structured. It does not require API, database, sync, or lower-layer changes.

Dependency direction before the change:

```
features/memos/memos_list_screen.dart
  -> state/memos/desktop_home_pane_state.dart
  -> features/memos/memos_list_desktop_shortcut_delegate.dart
  -> core/desktop/shortcuts.dart
```

Dependency direction after the change should remain the same. No `state -> features`, `application -> features`, or `core -> higher-layer` dependency may be added.

## Goals / Non-Goals

**Goals:**
- Ensure plain `Enter` in the focused home inline compose editor inserts a line break and does not open the selected memo.
- Let users cancel the stuck selected state by clicking the already-selected memo card again.
- Preserve the existing plain `Enter` behavior for opening the selected memo when no editor owns keyboard input.
- Preserve inline compose submit/formatting shortcuts, including configured publish shortcut handling and the existing `Shift+Enter` fallback.
- Add a regression test that guards the keyboard ownership boundary.

**Non-Goals:**
- Do not redesign the preview pane or selection model broadly.
- Do not change memo detail navigation, memo editor screens, mobile `NoteInputSheet`, sync, storage, or API behavior.
- Do not add a user-facing preference for this behavior in this change.

## Decisions

### Decision: Gate selected-memo `Enter` behind inline compose keyboard ownership

When `_handleDesktopShortcuts` considers opening the selected memo, it should treat the home inline compose focus node as a keyboard owner. A helper-level guard can combine:

- existing `EditableText` detection from `_isTextInputFocused()`
- explicit `_inlineComposeFocusNode.hasFocus`
- existing modifier checks for plain `Enter`

Rationale: the bug is about shortcut arbitration, not about the preview selection itself. Blocking the selected-memo shortcut while the editor is active fixes the accidental navigation without removing useful preview context.

Alternatives considered:
- Clear `selectedMemoUid` whenever inline compose receives focus. This would also prevent Enter navigation, but it removes selection/highlight state and can make the preview feel unstable while drafting.
- Close the preview pane whenever inline compose receives focus. This is more disruptive and contradicts the current desktop workflow where preview and compose can coexist.
- Move all selected-memo shortcut handling into `MemosListDesktopShortcutDelegate`. This could be cleaner long-term, but it is broader than needed for this focused bug fix.

### Decision: Preserve selection and preview while composing

The preview pane may stay visible and the memo card may remain selected while the inline composer has focus. The important rule is that keyboard input belongs to the editor until it loses focus.

Rationale: users may want to reference the preview while drafting a new memo. Visual selection is not itself harmful; the harmful behavior is allowing the selected memo to consume plain `Enter`.

### Decision: Treat clicking the selected memo as a deselect fallback

When Windows desktop preview interaction is enabled and the user clicks the memo card whose uid already equals `DesktopHomePaneState.selectedMemoUid`, the screen should clear the selected memo state instead of re-opening the same preview.

The preferred behavior is:

```
selectedMemoUid == tappedMemo.uid
  + normal memo-card click
  = selectedMemoUid becomes null
  = secondary preview pane closes or becomes hidden
  = inline compose/editor state is preserved
```

Because the current right-side preview is derived from `selectedMemoUid`, clearing selection should also hide the preview pane. Keeping an old preview visible while the card is no longer selected would create a split-brain state: no selected memo, but a stale preview still shown.

Implementation should avoid using the broad `DesktopHomePaneStateController.clear()` if that would reset unrelated desktop editor state. A scoped method such as `deselectMemo()` or `clearSelection()` can clear `selectedMemoUid` and hide `secondaryPaneMode` while preserving `composeDraftTarget` and `editorSurfaceMode`.

Alternatives considered:
- Keep preview visible but remove card highlight. This requires splitting `previewMemoUid` from visual/keyboard selection, which is a larger state-model refactor.
- Only provide `Escape` as the deselect path. This does not satisfy mouse-first users and leaves the selected card feeling sticky.
- Toggle only when inline compose is focused. This is less predictable; the same selected card should be cancellable regardless of current editor focus.

### Decision: Use tests as the scoped modularity guardrail

The implementation should add or tighten tests around the screen-level shortcut arbitration:

- Focused inline compose + selected preview memo + plain `Enter` MUST NOT open `MemoDetailScreen`.
- Unfocused editor + selected preview memo + plain `Enter` MUST still open `MemoDetailScreen`.
- Clicking the already-selected memo card MUST clear the selection/preview state without disrupting inline compose.

Rationale: `MemosListScreen` is already a coupled area. A focused regression test is the lowest-risk modularity improvement because it freezes the intended boundary without broad rewrites.

## Risks / Trade-offs

- [Risk] Flutter desktop focus internals may still make `EditableText` detection unreliable → Mitigation: explicitly check `_inlineComposeFocusNode.hasFocus` for the home inline compose path.
- [Risk] Over-broad guards could disable valid selected-memo keyboard navigation → Mitigation: limit the guard to editor ownership and keep existing no-editor Enter behavior covered by tests.
- [Risk] A broad clear operation could close unrelated desktop editor state → Mitigation: prefer a scoped deselect operation that only clears memo selection and the dependent preview pane.
- [Risk] Tests may be platform-sensitive because the behavior only applies to Windows wide layout → Mitigation: use existing `debugDefaultTargetPlatformOverride`, wide viewport setup, and screen harness patterns from `memos_list_screen_test.dart`.
- [Risk] Adding more logic directly into `MemosListScreen` can worsen coupling → Mitigation: keep the change small, prefer a named helper for keyboard ownership, and add a regression guardrail.

## Migration Plan

No data migration is needed.

Implementation can ship as a behavioral fix. Rollback is limited to reverting the shortcut guard and tests. Existing user settings and selected preview state remain compatible.

## Open Questions

- Should `Escape` also clear `selectedMemoUid` after closing the preview pane, or should it continue preserving selection for keyboard navigation? This proposal does not change `Escape`.
- Should a future refactor separate `previewMemoUid`, visual selection, and keyboard target into distinct state fields? That is a larger desktop interaction design change and remains out of scope.
