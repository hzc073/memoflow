## Context

The app is currently in architecture phase `evolve_modularity`. The affected interaction is UI-local: mobile home memo-list content renders inside `MemosListScreenBody`, which uses `Scaffold.drawer`, `drawerEnableOpenDragGesture`, and a full-width `drawerEdgeDragWidth` when drawer opening is enabled and search is inactive.

The suspected regression is gesture arbitration rather than missing drawer wiring. Memo cards are wrapped in `AppPressScale`, which reacts to raw pointer down/up/cancel events and starts press feedback immediately, while the card `InkWell` handles tap and long-press gestures. A rightward drawer drag beginning on a memo card should be owned by the drawer gesture and must not require repeated swipes or accidentally commit memo-card interactions.

This change touches modularity checklist item `6` because `features/memos` currently collaborates directly with home drawer UI. It must preserve that boundary and must not introduce new `state -> features`, `application -> features`, or `core -> features` dependencies.

## Goals / Non-Goals

**Goals:**

- Restore reliable right-swipe drawer opening on native mobile platforms when the drawer is available.
- Keep taps, long press, double tap, vertical scroll, search mode, and desktop side-pane behavior unchanged.
- Make press feedback drag-aware if it is confirmed to mask or delay drawer gestures.
- Add focused widget regression tests that start the drag over memo-card content, not only over empty screen space.
- Preserve or improve modularity by containing gesture coordination in feature UI or a reusable lower-level motion helper with tests.

**Non-Goals:**

- No navigation redesign, drawer destination changes, API changes, data model changes, sync behavior changes, or private/commercial behavior.
- No broad refactor of home navigation or memo-list architecture.
- No change to desktop side-pane drawer behavior.

## Decisions

1. Test the failing interaction before changing production behavior.

   Use `WidgetTester.startGesture`/`moveBy` on a visible memo card in `memos_list_screen_body_test.dart`, with `ThemeData.platform` set to `TargetPlatform.android` or `TargetPlatform.iOS`, a non-null `drawerPanel`, and `enableDrawerOpenDragGesture: true`. The test should assert that the drawer panel becomes visible after a rightward drag and that memo-card tap/long-press callbacks are not committed.

   Alternative considered: manually verify on device only. That would not protect against future gesture-arena regressions, so it is insufficient.

2. Keep drawer opening owned by `Scaffold`/`MemosListScreenBody` unless diagnosis proves a small feature-local gesture shim is required.

   The existing `Scaffold` drawer recognizer is the correct owner for opening the drawer. Implementation should first adjust competing child feedback/gesture behavior rather than replacing `Scaffold` navigation. If a shim is needed, keep it inside `features/memos/widgets` as a narrow UI helper that calls the existing scaffold drawer path and does not import state/application/core upward.

   Alternative considered: add a global gesture handler in `app.dart` or a state provider. That would spread UI gesture behavior outside its owner and worsen the current architecture phase.

3. Make `AppPressScale` cancel or defer press feedback once pointer movement exceeds Flutter touch slop.

   `AppPressScale` uses `Listener`, so it can track pointer movement without joining the gesture arena. If the regression is caused by immediate press feedback during a drawer drag, update it so drag-like movement resets the pressed state and prevents stale press animation while `Scaffold` continues to resolve the horizontal drag. Add/adjust `app_motion_widgets_test.dart` coverage for pointer movement cancellation.

   Alternative considered: remove `AppPressScale` from memo cards. That would fix the suspected symptom but regress expected press feedback across the list.

4. Preserve current drawer availability gates.

   The drawer swipe remains disabled when `useDesktopSidePane` is true, when `searching` is true, or when `enableDrawerOpenDragGesture` is false. The fix should not widen drawer behavior into states where users are editing/searching or where desktop layout already shows a side pane.

   Alternative considered: always enable the drawer drag on mobile. That could conflict with search/editing surfaces and violate existing behavior.

## Risks / Trade-offs

- [Risk] Flutter gesture-arena behavior differs between widget tests and physical Android/iOS devices. → Mitigation: cover the deterministic widget interaction and perform focused manual smoke testing on at least Android for the final implementation.
- [Risk] A shared `AppPressScale` change may affect buttons, drawer entries, or desktop hover/press feel. → Mitigation: keep the movement threshold conservative, preserve tap press/down/up behavior, and update existing core motion widget tests.
- [Risk] A full-width drawer edge drag can still conflict with horizontal gestures in future memo content. → Mitigation: add a regression test that begins over memo-card content and document drawer ownership in the new capability spec.
- [Risk] Adding a feature-local gesture shim could duplicate `Scaffold` drawer semantics. → Mitigation: use it only if the simpler press-feedback fix does not restore the drawer gesture, and keep it narrowly scoped.

## Migration Plan

No persisted data or user migration is required. The change can ship as a UI bug fix. Rollback is limited to reverting the gesture/press feedback patch and its focused tests.

## Open Questions

- Whether the unreliable swipe reproduces on both Android and iOS, or only on Android.
- Whether the root cause is `AppPressScale` feedback, memo-card `InkWell` gesture competition, or another overlay introduced between `v1.0.29` and `v1.0.31`.
