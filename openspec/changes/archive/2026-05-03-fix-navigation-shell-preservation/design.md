## Context

The app has multiple home entry modes:

- Classic home stack.
- Mobile bottom navigation shell.
- Desktop navigation rail / expanded sidebar shell.
- Standalone routes opened from drawer, reminders, memo detail flows, or direct links.

The failing behavior came from routes that were launched from a shell but then navigated as if they were standalone. Two related patterns caused shell loss:

```text
Pattern A: fallback-to-home clears the shell

HomeBottomNavShell
  -> push overlay: TagsScreen / AboutScreen / other drawer page
     -> back or "all memos"
        -> pushAndRemoveUntil(MemosListScreen)
           -> HomeBottomNavShell is removed from the route stack
```

```text
Pattern B: tag selection covers the shell

HomeBottomNavShell
  -> shell-launched TagsScreen / AppDrawer
     -> select tag "work"
        -> push standalone MemosListScreen(tag: "work")
           -> tagged memo list has no bottom navigation bar
```

The existing `HomeEmbeddedNavigationHost` boundary already expresses the right shell-level actions:

- `handleBackToPrimaryDestination`
- `handleDrawerDestination`
- `handleDrawerTag`
- `handleOpenNotifications`
- swipe exclusion updates

This change extends existing screens to use that boundary consistently instead of introducing a new navigation abstraction.

## Goals / Non-Goals

**Goals:**

- Preserve `HomeBottomNavShell` after back from shell-launched drawer/overlay pages.
- Preserve the shell when shell-launched pages select another drawer destination, open notifications, or select a tag.
- Render shell tag filters inside the memos root destination when the memos destination is available in the shell.
- Make system back clear an active shell tag filter before leaving the bottom navigation shell.
- Keep standalone fallback behavior preference-aware through `HomeEntryScreen`.
- Add focused tests that catch shell-clearing and standalone tagged-route regressions.

**Non-Goals:**

- Redesign the app-wide navigation model.
- Add nested navigators per bottom-navigation tab.
- Change API routes, data models, sync behavior, private extension seams, or commercial hooks.
- Fix unrelated direct-launch paths unless they are proven to be part of the reported shell-preservation bug.

## Design

### 1. Shell-aware drawer screens

Drawer pages that can be opened from the home shell receive:

- `HomeScreenPresentation presentation`
- `HomeEmbeddedNavigationHost? embeddedNavigationHost`

When the host is present, these screens delegate shell-level actions to it. When the host is absent, they preserve their existing standalone behavior, except home reset fallbacks use `HomeEntryScreen` where the user intent is returning home.

This keeps the ownership clear:

```text
Feature screen
  owns: local UI and local page state
  delegates: shell-level navigation intent

HomeBottomNavShell
  owns: active root destination, bottom bar, shell back behavior
```

### 2. Destination builder propagation

`buildDrawerDestinationScreen` passes `presentation` and `navigationHost` into drawer destinations so shell-launched pages can keep delegating after they are built by the central drawer route factory.

This avoids a hidden split where some entry points are shell-aware and others silently build standalone screens.

### 3. Shell-local tag filter state

`HomeBottomNavShell` owns a nullable active memos tag:

```text
HomeBottomNavShell
  _activeDestination: HomeRootDestination
  _activeMemosTag: String?
```

Tag selection flow:

```text
select tag "work"
  -> HomeEmbeddedNavigationHost.handleDrawerTag
  -> HomeBottomNavShell._switchToMemosTag("work")
  -> close drawer / dismiss overlay if needed
  -> switch to memos destination without clearing tag
  -> buildHomeRootScreen(..., destination: memos, memosTag: "work")
  -> MemosListScreen(tag: "work", presentation: embeddedBottomNav)
```

Desired visual structure:

```text
HomeBottomNavShell
  body
    MemosListScreen
      title: #work
      filter chip: #work
  bottomNavigationBar
    Memos | Collections | Review | Settings
```

`home_root_destination_registry.dart` accepts `memosTag` and applies it only to the memos root destination. The memos screen remains the existing screen; the shell just supplies the external filter.

### 4. Back behavior with active tag

When `_activeMemosTag` is set:

- Selecting the memos tab clears the tag and returns to all memos.
- `handleBackToPrimaryDestination` clears the tag before switching destinations.
- System back clears the tag before allowing the shell to pop or switch back to the primary destination.

This makes tag filtering feel like a shell sub-state rather than a separate full-screen route.

### 5. Overlay host forwarding

Routes opened above the shell use an overlay host wrapper. The wrapper dismisses the overlay route first, then forwards the shell-level action to the underlying `HomeBottomNavShell`.

This preserves expected route-stack behavior:

```text
overlay action
  -> pop overlay
  -> call shell action on next frame
```

### 6. Deferred risks

Some direct launch paths still intentionally create standalone `MemosListScreen` routes, such as reminder taps, startup links, import flows, and memo detail restore flows. They are not automatically shell-launched drawer routes. They should be handled separately only if a reproducible shell-preservation bug exists for those entry points.

If the user configures bottom navigation without the memos root destination visible, rendering a tagged memo list inside the tab body may require a separate design decision, because there is no visible memos tab body to host that state. The current focused fix targets the configured shell path where memos is part of the bottom navigation roots.

## Test Strategy

- Widget-test Tags opened from `HomeBottomNavShell`, then back: shell remains mounted.
- Widget-test About opened from `HomeBottomNavShell`, then back: shell remains mounted.
- Widget-test standalone Tags/About fallback through `HomeEntryScreen` and bottom-navigation preferences.
- Widget-test drawer destination builder host propagation.
- Widget-test shell tag selection: no route is pushed over the shell, tagged memos render in the embedded memos destination, and the bottom bar remains visible.
- Widget-test system back with an active shell tag: clears only the tag first and keeps the shell mounted.
- Re-run related notification and AI summary back-safety tests to ensure overlay forwarding remains stable.
