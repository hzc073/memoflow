## 1. Anchor Restoration Implementation

- [x] 1.1 Add a feature-local way to capture the active memo card's current scroll anchor before floating collapse.
- [x] 1.2 Update the floating collapse callback to capture the anchor, collapse the active memo, and restore the viewport after the post-collapse layout frame.
- [x] 1.3 Clamp the restored target to the post-collapse scroll extent and skip restoration safely when card state, render objects, or scroll clients are unavailable.
- [x] 1.4 Keep inline `Expand` / `Collapse` toggle behavior outside the floating-collapse anchor restoration path.

## 2. Regression Coverage

- [x] 2.1 Add a screen-level A/B/C regression test where floating collapse of expanded memo A restores the viewport to A instead of landing on C.
- [x] 2.2 Add coverage for safe fallback behavior when the active floating-collapse memo cannot provide a usable anchor.
- [x] 2.3 Preserve existing floating collapse wiring assertions that the active memo collapses and the floating button hides after collapse.

## 3. Verification

- [x] 3.1 Review touched imports to confirm the change stays within the `features/memos` UI seam and adds no new cross-layer dependency.
- [x] 3.2 Run focused memo tests covering floating collapse and memo list screen behavior.
- [x] 3.3 Run `flutter analyze` and `flutter test` from `memos_flutter_app` before PR handoff.
