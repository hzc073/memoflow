## 1. Detail Action Menu Model

- [x] 1.1 Define the detail action availability rules for normal, archived, and read-only memo detail states.
- [x] 1.2 Reuse `MemoCardAction` and the existing popover surface where practical, adding a focused detail menu adapter/helper only if detail-specific filtering is needed.
- [x] 1.3 Keep the menu helper presentation-only: it must return a selected action and must not execute copy, navigation, mutation, sync, reminder, collection, archive, restore, or delete behavior.

## 2. Detail Long-Press Entry Point

- [x] 2.1 Add a memo detail body-level long-press entry point that includes blank space below short or empty memo content.
- [x] 2.2 Anchor the action popover to `LongPressStartDetails.globalPosition` so the menu appears near the pressed location.
- [x] 2.3 Preserve existing double-tap edit behavior on memo detail content.
- [x] 2.4 Scale the shared more-menu popover styling up slightly and proportionally so both the home memo more menu and memo detail long-press menu use the larger visual size consistently.
- [x] 2.5 Preserve child gestures for links, image/media preview, task toggles, audio rows, attachment rows, error panel buttons, and selectable text.

## 3. Action Execution Wiring

- [x] 3.1 Route selected copy/edit/pin/reminder/collection/archive/restore/adjust-time/history/delete actions to existing detail handlers or existing mutation seams.
- [x] 3.2 Ensure archived memo detail shows only the archived-safe action subset.
- [x] 3.3 Ensure read-only detail does not expose mutating long-press menu actions.
- [x] 3.4 Avoid edits under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api`.

## 4. Tests and Guardrails

- [x] 4.1 Add widget coverage that long-pressing blank space below a short memo opens the detail action popover at a viewport-safe position.
- [x] 4.2 Add widget coverage that selecting an action closes the popover and invokes the expected detail action path exactly once.
- [x] 4.3 Add widget coverage for archived and read-only detail action availability.
- [x] 4.4 Add regression coverage that interactive descendants still handle their existing gestures and are not replaced by the detail long-press menu.
- [x] 4.5 Add or update focused architecture/structure guardrail coverage if the implementation extracts a new helper seam or touches an existing coupling hotspot.

## 5. Verification

- [x] 5.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 5.2 Run focused memo detail/menu widget tests.
- [x] 5.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.4 Run `flutter test` from `memos_flutter_app`.
