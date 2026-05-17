## 1. Floating Action UI

- [x] 1.1 Convert `MemoFloatingCollapseButton` from a top-right text pill into a circular icon action with localized collapse semantics.
- [x] 1.2 Keep collapse action visibility, scrolling opacity behavior, and `onPressed` callback compatible with `MemosListFloatingCollapseState`.
- [x] 1.3 Preserve visual distinction between collapse and `BackToTopButton` icons while matching the theme-controlled primary background, sizing, and touch target.

## 2. Memo List Overlay Layout

- [x] 2.1 Replace the current top-right `Positioned.fill` collapse overlay in `MemosListScreenBody` with a bottom-right stable action stack.
- [x] 2.2 Anchor the stack from the existing `backToTopBaseOffset + bottomInset` behavior so compose FAB, bottom safe area, and bottom navigation avoidance remain unchanged.
- [x] 2.3 Implement方案 A behavior: the collapse action stays above the reserved back-to-top slot even when `BackToTopButton.visible` is false.
- [x] 2.4 Ensure hidden/transparent floating actions ignore pointer input and the overlay does not block memo list scrolling or card taps.

## 3. Focused Tests and Guardrails

- [x] 3.1 Update `memos_list_screen_body_test.dart` to verify collapse and back-to-top listenables still drive button visibility.
- [x] 3.2 Add widget coverage that the collapse action is stacked above the back-to-top slot and does not move downward when back-to-top is hidden.
- [x] 3.3 Update screen-level collapse wiring tests so the circular collapse action still collapses the active expanded memo.
- [x] 3.4 Confirm the diff adds no new `state -> features`, `application -> features`, or `core -> higher-layer` imports.

## 4. Verification

- [x] 4.1 Run focused memo widget tests covering floating collapse and back-to-top behavior.
- [x] 4.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.3 Run `flutter test` from `memos_flutter_app`, or document unrelated pre-existing failures.

## 5. Mobile Adaptive Side Placement

- [x] 5.1 Add a UI-only action-group side state for `MemosListScreenBody` or a private memo-list floating action stack widget; default side is right.
- [x] 5.2 On mobile native platforms only, detect the most recent touch `ScrollStartNotification` position and switch the whole collapse/back-to-top action group to the matching screen half.
- [x] 5.3 Keep desktop and non-mobile platforms right aligned regardless of pointer signal, trackpad, keyboard, or touch scrolling.
- [x] 5.4 Preserve方案 A stable vertical slot behavior while changing only the horizontal side of the grouped actions.
- [x] 5.5 Ensure taps, long presses, context-menu gestures, and non-scroll pointer events do not change the action group side.

## 6. Adaptive Side Tests and Verification

- [x] 6.1 Add body-level widget tests for mobile right-half and left-half touch scroll starts moving the grouped actions to the matching side.
- [x] 6.2 Add widget coverage that plain taps do not move the grouped actions.
- [x] 6.3 Add widget coverage that desktop/non-mobile layout remains right aligned after scroll input.
- [x] 6.4 Re-run focused memo floating action tests.
- [x] 6.5 Re-run targeted analyzer for touched Dart files.
