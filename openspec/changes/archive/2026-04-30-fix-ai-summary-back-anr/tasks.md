## 1. Reproduce and Guard the Back Loop

- [x] 1.1 Add a focused widget test that opens AI Summary through the bottom-nav overlay route path and triggers Android/system back.
- [x] 1.2 Assert the back action settles without repeated `PopScope` callbacks, route recursion, or unbounded pending frames.
- [x] 1.3 Add coverage for the AI Summary app-bar back action in the same standalone overlay host shape.

## 2. Fix Overlay Host Back Semantics

- [x] 2.1 Update `_OverlayHomeNavigationHost.handleBackToPrimaryDestination` so it does not call `Navigator.maybePop()` on the same overlay route that delegated the back action.
- [x] 2.2 Dismiss the overlay route or switch the shell to the primary destination exactly once, preserving existing embedded-tab back behavior.
- [x] 2.3 Add a defensive duplicate-request guard if implementation testing shows direct dismissal can be re-entered during route settling.

## 3. Preserve Navigation Boundaries

- [x] 3.1 Keep coordination owned by the `HomeEmbeddedNavigationHost` seam; do not add feature-to-feature shortcuts from AI Summary to bottom-nav internals.
- [x] 3.2 Inspect Explore, Resources, Daily Review, Notifications, and other pages using the same standalone overlay host pattern for equivalent back behavior.
- [x] 3.3 Add or adjust one host-level guardrail if peer pages rely on the same fixed host semantics rather than page-specific patches.

## 4. Verify

- [x] 4.1 Run the focused widget test file(s) covering home navigation and AI Summary back behavior.
- [x] 4.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.3 Run `flutter test` from `memos_flutter_app`, or document any unrelated existing failures.
- [x] 4.4 Manually smoke-test on Android/emulator: open AI Summary, enter custom template settings/editor, back out, then back from AI Summary without ANR.
