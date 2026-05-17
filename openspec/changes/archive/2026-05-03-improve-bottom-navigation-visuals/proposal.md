## Why

Bottom navigation mode currently renders a short text-only bar that can look visually detached from the bottom edge on gesture-navigation devices. Users expect the runtime bottom navigation to match the Laboratory preview: destination icon plus label, while keeping the center create FAB prominent.

## What Changes

- Extend the `HomeBottomNavShell` bottom navigation background through the bottom safe area without moving the bar's top edge upward.
- Render each configured destination as an icon plus label, matching the visual language used by the Laboratory bottom navigation preview.
- Preserve the center circular `MemoFlowFab` as the primary create action, including existing tap and long-press behavior, while placing it in the exact center of a five-slot equal-width layout.
- Increase destination label readability and tune label vertical placement without changing destination icon size.
- Keep destination labels, icon definitions, tab ordering, hidden-slot behavior, and account-based availability resolved through existing home navigation registry/resolver seams.
- Add or update focused widget coverage so the bottom navigation shell preserves destination labels for interaction while exposing icons and maintaining the create FAB.

## Capabilities

### New Capabilities
- `home-bottom-navigation-visuals`: Defines visual behavior for the runtime bottom navigation bar, including safe-area background coverage, icon-plus-label destination items, equal-width slot spacing, tuned label placement, and the preserved centered create FAB.

### Modified Capabilities
- None.

## Impact

- Affected runtime code: `memos_flutter_app/lib/features/home/home_bottom_nav_shell.dart`.
- Affected tests: focused widget tests under `memos_flutter_app/test/features/home`, especially `home_bottom_nav_shell_test.dart`.
- APIs, persistence, sync, server compatibility, private extension seams, and navigation preference models remain unchanged.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 6 (feature collaboration should continue to use registry/resolver seams), item 8 (guardrail/widget tests), and item 10 (touched home navigation shell remains equal or better structured).
- Scoped modularity improvement: keep runtime visual rendering sourced from `homeRootDestinationDefinition` and resolved preferences rather than duplicating destination icon/label mappings in the bottom navigation widget.
