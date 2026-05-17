## Context

The memo list already has a floating collapse flow:

- Expanded long memo cards publish `MemoFloatingCollapseGeometry`.
- `MemosListFloatingCollapseController` chooses the active memo whose inline collapse control is outside the viewport grace area.
- `MemosListScreen` receives the floating button tap and calls `MemoListCardState.collapseFromFloating()` on the active memo.

The missing behavior is viewport restoration. When memo A is expanded and the reader scrolls deep enough that memo B or C is near the current viewport, collapsing A removes a large amount of content above the current scroll offset. Flutter then keeps or clamps the old offset against the much shorter list, so the viewport can land on C instead of returning to A.

Architecture phase is `evolve_modularity`. The touched area is feature UI composition under `features/memos`; it is not one of the known `state -> features`, `application -> features`, or `core -> higher-layer` hotspots. The change should preserve dependency direction by keeping anchor capture and restoration in the memo-list feature seam.

## Goals / Non-Goals

**Goals:**

- After the floating collapse action collapses active memo A, restore the viewport to A's collapsed card anchor.
- Preserve existing active memo selection, floating button visibility, bottom action stack placement, accessibility, and haptics behavior.
- Make the behavior deterministic enough to cover with a screen-level widget regression test.
- Fail safely if the active memo state, render object, or scroll controller is unavailable.

**Non-Goals:**

- Change inline card `Expand` / `Collapse` toggle behavior.
- Change long memo truncation thresholds, Markdown rendering, media loading, or search expansion behavior.
- Add global scroll restoration infrastructure outside `features/memos`.
- Touch API compatibility code, data models, sync logic, public/private extension seams, or commercial hooks.

## Decisions

### Decision 1: Restore to the collapsed memo's card-top anchor

The floating collapse action means "exit the long memo currently being read." The most predictable result is to bring that memo's collapsed card back into view, with the card top used as the target anchor when available.

Alternative considered: preserve the current visible B position. This would keep nearby content stable but makes the floating action feel less tied to memo A and can still hide the memo the user just collapsed. Returning to A better matches the user's expectation from the exploration.

Alternative considered: preserve the old raw scroll offset. This is the current problematic behavior and can land on C after A's height collapses.

### Decision 2: Capture the anchor before collapse, apply it after layout

`MemosListScreen` should capture the active memo card's reveal offset before calling `collapseFromFloating()`. It should then schedule a post-frame restoration after the card has rebuilt in collapsed form, clamp the target to the new scroll extent, and use `jumpTo` if the current offset differs.

Using the pre-collapse card-top offset is stable because collapsing A changes A's height, not the vertical position of A's top relative to the sliver content. The post-frame step is still needed so the new `maxScrollExtent` is available before clamping.

Alternative considered: compute the target after collapse from the same card render object. This can work but is more sensitive to the card being rebuilt, temporarily unmounted, or replaced while the layout is changing.

Alternative considered: animate to the target. This would make a structural layout correction feel like user-initiated navigation and could create a visible sweep from C back to A. A direct `jumpTo` is more appropriate for anchor restoration.

### Decision 3: Keep anchor ownership inside the memo-list feature seam

The screen already owns the `ScrollController`, the animated memo-card keys, and the floating collapse callback. Anchor capture should stay there, with a small card-state helper if needed to expose the current card reveal offset.

Dependency direction before the change:

- `features/memos/memos_list_screen.dart` coordinates `ScrollController`, `MemosListAnimatedListController`, `MemosListFloatingCollapseController`, and `MemoListCardState`.
- `features/memos/widgets/memos_list_memo_card.dart` publishes floating geometry to the feature controller.

Dependency direction after the change:

- The same feature-local dependencies remain.
- No `state`, `application`, or `core` layer imports from `features/memos` are added.
- No shared domain logic is moved into screen or widget files; the new logic is UI viewport behavior specific to this screen.

## Risks / Trade-offs

- [Risk] The active memo is removed, filtered, or unmounted between tap and restoration. → Mitigation: capture only when the card state and scroll controller are available; skip restoration otherwise.
- [Risk] The target offset exceeds the new scroll extent after collapse. → Mitigation: clamp the target after the post-collapse frame.
- [Risk] A direct jump can feel abrupt. → Mitigation: treat it as a layout anchor correction and only jump when the offset actually changes; avoid animation that would visually travel through unrelated memos.
- [Risk] Existing tests may not naturally drive real floating geometry in a compact test viewport. → Mitigation: add a focused screen-level regression that either drives the real scroll path or uses existing test-visible seams to establish the active floating collapse candidate.
- [Risk] Anchor code could spread into lower layers. → Mitigation: keep the change scoped to `features/memos` and prefer feature-local helpers over state/application/core changes.

## Migration Plan

1. Add feature-local anchor capture/restoration support around the existing floating collapse callback.
2. Add widget regression coverage for the A/B/C collapse-anchor scenario and safe fallback behavior.
3. Run focused memo tests that cover floating collapse and the new scroll-anchor behavior.

Rollback strategy: remove the anchor restoration wrapper and return `_collapseActiveMemoFromFloatingButton()` to only calling `collapseFromFloating()`. Existing floating collapse visibility and placement behavior can remain unchanged.

## Open Questions

- None. The desired product behavior is to return to memo A after floating collapse.
