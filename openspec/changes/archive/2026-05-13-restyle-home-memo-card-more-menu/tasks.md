## 1. Menu Model and Popover Surface

- [x] 1.1 Extract shared home memo action metadata from `memos_list_memo_card.dart` into a dedicated helper/model so the button menu and Windows context menu reuse the same action ordering, labels, icons, and danger flags.
- [x] 1.2 Implement a custom anchored popover surface for memo actions that can render the primary grid, more-settings section, and destructive section inside a viewport-safe container.
- [x] 1.3 Keep the new popover helper isolated from business logic so it returns `MemoCardAction` only and leaves execution to the existing delegate/caller path.

## 2. Wire Existing Entry Points

- [x] 2.1 Replace the top-right `PopupMenuButton` in `MemoListCard` with the new anchored popover trigger while preserving the existing `msg_more` tooltip and tap target semantics.
- [x] 2.2 Replace `showMemoCardContextMenu`'s default `showMenu` implementation with the same popover surface so Windows secondary-click uses the identical action model.
- [x] 2.3 Preserve the current archived-memo action subset and ensure normal-memo and archived-memo menus select from the same shared metadata source.

## 3. Widget and Interaction Tests

- [x] 3.1 Add widget tests that verify normal memo actions render in grouped sections, including the secondary settings section and separate destructive action area.
- [x] 3.2 Add widget tests that verify archived memo menus only expose copy, history, restore, and delete.
- [x] 3.3 Add interaction tests for action selection, outside dismissal, and edge positioning/clamping so the popover stays visible near viewport boundaries.
- [x] 3.4 Add a focused test that compares the action metadata exposed by the top-right button path and the Windows secondary-click path.

## 4. Verification

- [x] 4.1 Run `dart format` on the changed Dart files in `memos_flutter_app`.
- [x] 4.2 Run the focused widget tests for the home memo more menu.
- [x] 4.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.4 Run `flutter test` from `memos_flutter_app`.
