## 1. Reproduce and lock the regression

- [x] 1.1 Add a widget regression test in `memos_list_screen_body_test.dart` that starts a rightward drag on visible memo-card content on a mobile platform and verifies the drawer opens.
- [x] 1.2 Extend the same test to confirm the drawer-opening drag does not commit memo tap or long-press callbacks.
- [x] 1.3 Add or adjust `app_motion_widgets_test.dart` coverage if the press-scale helper needs drag-intent cancellation.

## 2. Apply the smallest feature-local fix

- [x] 2.1 Diagnose whether the failure is caused by `AppPressScale`, memo-card `InkWell` gesture competition, or the current drawer gate in `MemosListScreenBody`.
- [x] 2.2 Update `core/app_motion_widgets.dart` if needed so `AppPressScale` clears press feedback once the pointer movement becomes drag-like, without changing tap semantics.
- [x] 2.3 Keep drawer open drag disabled for desktop side-pane layouts and active search states while preserving the current mobile enablement gate.

## 3. Verify behavior and boundaries

- [x] 3.1 Run the focused memo-list and core motion widget tests that exercise the drawer swipe path.
- [x] 3.2 Run `test/architecture/modularity_dependency_guardrail_test.dart` to confirm the fix stays inside the existing feature/UI seam and does not add new reverse dependencies.
- [x] 3.3 Run `flutter analyze` and the relevant Flutter test subset before handing the change off.
