## 1. Runtime Visual Update

- [x] 1.1 Update `_HomeBottomNavigationBar` so its decorated background covers the bottom safe area while the content area's top edge remains stable.
- [x] 1.2 Update `_HomeBottomNavigationItem` to render destination `Icon` plus localized label from `homeRootDestinationDefinition(destination)`.
- [x] 1.3 Preserve selected/unselected colors, tap handling, ellipsis behavior, hidden `HomeRootDestination.none` slots, existing tab ordering, and equal-width slot spacing.
- [x] 1.4 Preserve the center circular `MemoFlowFab`, including current size, tap behavior, long-press handlers, and haptics wiring.

## 2. Guardrails and Modularity

- [x] 2.1 Add or update focused `HomeBottomNavShell` widget coverage for destination labels, destination icons, equal spacing, compact label fit, and the center `MemoFlowFab`.
- [x] 2.2 Ensure the visual update continues to source icon/label metadata from `homeRootDestinationDefinition` instead of introducing duplicate destination mappings.
- [x] 2.3 Confirm the diff introduces no new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies.

## 3. Verification

- [x] 3.1 Run focused home shell widget tests that cover bottom navigation behavior.
- [x] 3.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 3.3 Run `flutter test` from `memos_flutter_app`, or document any pre-existing unrelated failures.
- [x] 3.4 Manually verify on an Android device or emulator with gesture navigation that the bottom navigation background reaches the bottom edge and the top edge does not move upward.
