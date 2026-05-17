## Context

Windows desktop home wide layout stores selected preview state in `DesktopHomePaneState`:

```text
DesktopHomePaneState
  selectedMemoUid       -> card highlight and selected-memo keyboard target
  secondaryPaneMode     -> right-side preview pane visibility
  composeDraftTarget    -> inline/desktop compose draft owner
  editorSurfaceMode     -> compose surface visibility
```

The previous Windows preview-selection change added a scoped `deselectMemo()` path and made clicking the already-selected memo clear both `selectedMemoUid` and `secondaryPaneMode`. The remaining split is that `_closeDesktopPreview()` still calls `closeSecondaryPane()`, which hides the pane while preserving `selectedMemoUid`.

Current close flow:

```text
preview close button / Escape / toolbar toggle
  -> _closeDesktopPreview()
  -> DesktopHomePaneStateController.closeSecondaryPane()
  -> selectedMemoUid remains set
  -> previewVisible becomes false
```

Desired close flow:

```text
preview close button / Escape / toolbar toggle
  -> shared close-as-deselect path
  -> DesktopHomePaneStateController.deselectMemo()
  -> selectedMemoUid becomes null
  -> previewVisible becomes false
  -> compose/editor state is preserved
```

The active architecture phase is `evolve_modularity`. This change touches the coupled `MemosListScreen` preview/selection area, so it should keep dependency direction stable and add guardrail coverage rather than broadening screen logic.

Dependency direction before and after should remain:

```text
features/memos/memos_list_screen.dart
  -> state/memos/desktop_home_pane_state.dart
  -> features/memos/widgets/memos_list_desktop_preview_pane.dart
```

No new `state -> features`, `application -> features`, or `core -> higher-layer` dependency should be introduced.

## Goals / Non-Goals

**Goals:**

- Closing the visible desktop preview pane clears `selectedMemoUid`.
- The memo card is no longer rendered selected after preview close.
- Plain `Enter` no longer opens the previously previewed memo after preview close.
- Close behavior is consistent across the preview pane close button, `Escape`, and the Windows desktop preview toolbar toggle.
- Inline compose/editor state is preserved when preview close clears memo selection.
- Add focused regression tests for the close-selection behavior.

**Non-Goals:**

- Do not redesign desktop preview pane layout, animation, or loading behavior.
- Do not split `previewMemoUid`, visual selection, and keyboard target into separate state fields.
- Do not change memo detail navigation when a memo is actively selected and preview is visible.
- Do not change mobile memo list behavior, sync, API, database, or private extension hooks.
- Do not add a user-facing preference for sticky selection.

## Decisions

### Decision: Treat preview close as deselect

User-visible preview close actions should use the same semantic outcome as clicking the selected memo again: clear the selected memo and hide the preview pane.

Rationale: A hidden preview with a retained selected memo creates a split-brain state. The user has dismissed preview, but the app still has a keyboard target and may still render selection. Reusing the deselect semantics keeps the behavior predictable.

Alternatives considered:

- Keep `selectedMemoUid` after close so `Enter`, edit, and copy shortcuts still target the last memo. This preserves a keyboard target but conflicts with the user's explicit close intent.
- Only clear selection for the close button, but preserve it for `Escape` or toolbar toggle. This creates inconsistent close semantics and makes the bug path dependent.
- Clear all desktop pane state with `clear()`. This risks dropping compose/editor state and is broader than needed.

### Decision: Reuse the existing scoped deselect path

The implementation should prefer `_deselectDesktopMemo()` or `DesktopHomePaneStateController.deselectMemo()` over adding another close-only mutation. `deselectMemo()` already preserves `composeDraftTarget` and `editorSurfaceMode` while clearing selection and preview.

Rationale: The state model already has the exact operation this change needs. Reusing it is the scoped modularity improvement for this coupled screen area because it reduces divergent state transitions.

Alternative considered:

- Change `closeSecondaryPane()` to clear `selectedMemoUid`. This may be too broad if that method remains useful as a low-level state operation that only hides secondary UI. Keeping `deselectMemo()` as the user-close operation makes intent clearer.

### Decision: Keep open-preview behavior unchanged

Opening the preview pane from the toolbar when no memo is selected may still show the existing empty preview pane. Opening a memo preview by clicking a memo should still select that memo and show preview.

Rationale: The requested behavior only concerns closing preview. Reopening behavior and warmup/loading logic should remain stable.

### Decision: Guard all close paths with tests

Tests should cover:

- `Escape` closes preview and clears `selectedMemoUid`.
- The preview pane close button closes preview and clears `selectedMemoUid`.
- The Windows desktop preview toolbar toggle closes preview and clears `selectedMemoUid`.
- At least one close path verifies a subsequent plain `Enter` does not open `MemoDetailScreen`.
- Closing preview preserves inline compose draft text if the editor is active.

Rationale: This area already has screen-level coupling around preview state, selected cards, keyboard handling, and inline compose. Focused tests are the lowest-risk guardrail.

## Risks / Trade-offs

- [Risk] A helper rename could churn a coupled screen file. -> Mitigation: prefer reusing existing `_deselectDesktopMemo()` and avoid unrelated refactors.
- [Risk] Clearing selection on toolbar toggle could surprise users who expected the last memo to remain a keyboard target. -> Mitigation: align all visible close actions with the user's stated close intent and cover the new behavior in specs.
- [Risk] `closeSecondaryPane()` may still be used by future code and reintroduce the split state. -> Mitigation: tests should target public/user close paths; optional naming cleanup can make close-only semantics explicit if needed.
- [Risk] Widget tests may be sensitive to desktop layout size or animation timing. -> Mitigation: reuse existing Windows wide-layout harness patterns and pump durations from current preview tests.

## Migration Plan

No data migration is needed.

Implementation can ship as a narrow behavioral fix. Rollback is limited to restoring `_closeDesktopPreview()` to the old hide-only path and reverting the new regression tests.

## Open Questions

- Should `closeSecondaryPane()` remain as a low-level hide-only operation for future non-selection secondary panes, or should it be renamed to make its sticky-selection behavior explicit?
- Should a future refactor split preview identity, visual card selection, and keyboard target into separate state fields? This change intentionally avoids that broader state-model redesign.
