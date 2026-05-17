## Why

Users can enable the home bottom navigation shell, then open drawer/overlay routes such as Tags, More Tags, About, Recycle Bin, Sync Queue, or Stats. Some of those routes still used standalone home fallbacks or direct tagged `MemosListScreen` pushes. That could replace or cover `HomeBottomNavShell`, making the app appear to leave navigation-bar mode.

The original repro was Tags -> More Tags -> back. A follow-up repro showed a second problem: selecting a specific tag from the shell opened the tag-filtered memo list without the bottom navigation bar, because `HomeBottomNavShell.handleDrawerTag` still pushed a standalone route instead of rendering the tagged memo list inside the shell body.

## What Changes

- Route shell-launched drawer pages through the existing `HomeEmbeddedNavigationHost` seam for back, destination selection, tag selection, and notifications.
- Make standalone home fallbacks return through `HomeEntryScreen` or an equivalent navigation-entry seam, so workspace navigation preferences decide whether the user sees classic home or bottom navigation.
- Propagate `presentation` and `embeddedNavigationHost` from `buildDrawerDestinationScreen` into drawer destinations that need shell-aware behavior.
- Keep tag selections inside `HomeBottomNavShell` by storing a shell-local active memos tag and passing it to the memos root destination.
- Make shell/system back clear the active tag filter before leaving the shell or switching away from the primary destination.
- Add regression tests that fail if shell-launched pages clear the shell or if tagged memo lists are rendered outside the bottom navigation shell.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `home-navigation-back-safety`: expands the shell preservation contract so shell-launched drawer routes and shell tag selections must preserve the configured home navigation shell.

## Impact

- Affected runtime code: `memos_flutter_app/lib/features/home/home_bottom_nav_shell.dart`, `memos_flutter_app/lib/features/home/home_root_destination_registry.dart`, `memos_flutter_app/lib/features/home/app_drawer_destination_builder.dart`, `memos_flutter_app/lib/features/tags/tags_screen.dart`, `memos_flutter_app/lib/features/about/about_screen.dart`, `memos_flutter_app/lib/features/memos/recycle_bin_screen.dart`, `memos_flutter_app/lib/features/sync/sync_queue_screen.dart`, and `memos_flutter_app/lib/features/stats/stats_screen.dart`.
- Affected tests: focused widget tests under `memos_flutter_app/test/features/home` and related navigation/back-safety tests.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 6 (feature collaboration through seams), item 8 (guardrail tests), and item 10 (touched coupled areas stay equal or better structured).
- Scoped modularity improvement: centralize bottom-navigation preservation through `HomeEmbeddedNavigationHost` and the home root destination registry instead of adding more screen-to-screen navigation special cases.
