## 1. Confirm Baseline

- [x] 1.1 Reproduce or reason through the reported `MemoEditorScreen` path: existing memo ends with `#tag`, editor opens with collapsed caret at end, suggestions show, Android photo picker opens.
- [x] 1.2 Confirm no API-related code needs to change.

## 2. Define Shared Overlay Lifecycle

- [x] 2.1 Update `TagAutocompleteOverlay` design so the root `OverlayEntry` is removed when its owning editor focus/lifecycle becomes inactive.
- [x] 2.2 Preserve existing position calculation, suggestion rendering, mouse hover, keyboard selection, and apply behavior.
- [x] 2.3 Ensure empty suggestions and widget disposal still remove the root `OverlayEntry`.

## 3. Apply Picker Boundary Behavior

- [x] 3.1 In `MemoEditorScreen`, dismiss autocomplete / unfocus the editor before gallery picker launch.
- [x] 3.2 Apply the same boundary before file picker and camera capture launch where the shared overlay can otherwise remain visible.
- [x] 3.3 Review `NoteInputSheet` and home inline compose picker flows for the same shared-boundary behavior without changing non-picker formatting actions.
- [x] 3.4 Do not refocus the editor automatically after picker return.

## 4. Add Focused Coverage

- [x] 4.1 Add a focused widget test showing `TagAutocompleteOverlay` removes its root overlay entry on owning focus loss.
- [x] 4.2 Add or adjust compose-surface coverage for a picker-like action boundary: active tag suggestions are visible before the action and gone after focus/autocomplete dismissal.
- [x] 4.3 Keep existing tag autocomplete unit/widget tests passing.

## 5. Modularity Guardrails

- [x] 5.1 Verify the implementation does not add `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.
- [x] 5.2 If a new helper is introduced, place it in the lowest existing owner that does not create upward dependencies.
- [x] 5.3 Do not expand architecture allowlists for this change.

## 6. Validation

- [x] 6.1 Run `flutter test test/state/memos/memo_tag_autocomplete_test.dart` from `memos_flutter_app`.
- [x] 6.2 Run focused feature/widget tests added or touched for tag autocomplete/picker lifecycle.
- [x] 6.3 Run relevant architecture guardrails if dependencies or helper ownership change.
- [x] 6.4 Before PR, run `flutter analyze` and `flutter test`.
