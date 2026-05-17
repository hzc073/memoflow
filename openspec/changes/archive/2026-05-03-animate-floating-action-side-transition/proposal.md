## Why

The memo list floating collapse and back-to-top action group now switches between the left and right side instantly after mobile touch-scroll input. The behavior is functionally correct, but the abrupt side jump feels less natural than the rest of the app's motion language and misses the desired iPhone-like elastic, inertial transition.

## What Changes

- Add a spring-like side transition for the memo-list floating action group when mobile touch-scroll input changes the active side.
- Keep the final left/right alignment, bottom offset, vertical reserved slots, visibility rules, pointer ignoring, haptics, and button semantics unchanged.
- Use a subtle group-level motion treatment: horizontal spring/inertia movement with light scale and opacity softening during travel.
- Respect reduced-motion settings by disabling or short-circuiting the spring transition.
- Keep desktop, web, and non-mobile platforms right-aligned without adaptive side animation.
- Do not change memo collapse behavior, scroll-anchor restoration, API/data models, sync logic, or public/private extension seams.

## Capabilities

### New Capabilities

- `memo-list-floating-action-side-transition`: Defines the animated transition behavior for the memo list floating action group when it moves between screen sides.

### Modified Capabilities

- None.

## Impact

- Affected runtime code is expected to stay under `memos_flutter_app/lib/features/memos/widgets`, primarily `memos_list_screen_body.dart` and, if helpful, a feature-local private widget extracted from that file.
- Affected tests are expected under `memos_flutter_app/test/features/memos/widgets`, focused on final alignment compatibility, intermediate animated side movement, reduced-motion behavior, and unchanged desktop alignment.
- Architecture phase is `evolve_modularity`. This change touches feature UI composition inside `features/memos`, not known `state -> features`, `application -> features`, or `core -> higher-layer` coupling hotspots. The touched area should remain equal or better structured by containing side-transition motion in the memo-list UI seam and not adding cross-layer dependencies.
- No API route/version changes, no data model changes, no new commercial/private hooks, and no new dependency is expected.
