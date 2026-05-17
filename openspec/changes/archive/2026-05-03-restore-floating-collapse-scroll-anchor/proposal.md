## Why

When a long memo is expanded and the reader scrolls deep into it, activating the floating collapse action can leave the home memo list at a later memo after the expanded content collapses. This makes the action feel like it lost the user's place because the viewport does not return to the memo that was just collapsed.

## What Changes

- Restore the memo list viewport to the active memo's collapsed card anchor after the floating collapse action is activated.
- Keep the existing floating collapse visibility, active memo selection, icon placement, haptics, and accessibility behavior.
- Add regression coverage for an A/B/C memo list where memo A is expanded, the reader scrolls near memo B, and floating collapse returns the viewport to memo A instead of landing on memo C.
- Handle unavailable anchors safely, including cases where the memo is removed, filtered out, unmounted, or the scroll controller has no clients.
- Do not change memo content truncation, Markdown rendering, API models, sync behavior, or the public/private extension seams.

## Capabilities

### New Capabilities
- `memo-list-floating-collapse-scroll-anchor`: Defines viewport restoration behavior after collapsing an expanded memo from the floating action.

### Modified Capabilities
- None.

## Impact

- Affected runtime code is expected to stay under `memos_flutter_app/lib/features/memos`, primarily `memos_list_screen.dart`, `memos_list_animated_list_controller.dart`, and `widgets/memos_list_memo_card.dart` if a card anchor helper is needed.
- Affected tests are expected under `memos_flutter_app/test/features/memos`, focused on screen-level collapse wiring and scroll-position regression behavior.
- Architecture phase is `evolve_modularity`. This change touches feature UI composition inside `features/memos`, not known `state -> features`, `application -> features`, or `core -> higher-layer` coupling hotspots. The touched area should remain equal or better structured by keeping scroll-anchor restoration owned by the memo-list UI seam instead of spreading it into state, application, or core layers.
- No API route/version changes, no data model changes, no new dependencies, and no commercial/private hook changes.
