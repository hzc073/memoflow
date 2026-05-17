# Design

## Current Behavior

Classic drawer navigation uses `closeDrawerThenPushReplacement`, which intentionally replaces the current route with the selected drawer destination. For destinations that do not intercept system back, the destination can become the root route. On Android/native mobile, system back from a root route exits the app.

Several drawer destinations already guard this pattern with local back fallback behavior:

- `SettingsScreen` routes back through `HomeEntryScreen` or delegates to `HomeEmbeddedNavigationHost`.
- `TagsScreen`, `AboutScreen`, `SyncQueueScreen`, `RecycleBinScreen`, and `StatsScreen` already avoid bare app exit.
- `ExploreScreen`, `ResourcesScreen`, `AiSummaryScreen`, and `DailyReviewScreen` also have back-to-primary handling.

`CollectionsScreen` and `DraftBoxNavigationScreen` are the observed gaps.

## Desired Behavior

When a standalone/classic drawer destination is at navigator root and the user invokes system back:

```text
Draft Box / Collections
  system back
    if embedded host exists -> delegate to host primary destination
    else if local navigator can pop -> pop local route
    else -> reset through HomeEntryScreen
```

The fallback MUST route through `HomeEntryScreen` instead of constructing a bare `MemosListScreen`, so it continues to respect workspace navigation preferences and desktop platform rules.

## Option A: Add local `PopScope` to the two missing screens

Add a local back handler around `DraftBoxNavigationScreen` and `CollectionsScreen`.

Pros:

- Smallest blast radius.
- Matches the existing per-screen pattern in neighboring drawer destinations.
- Avoids changing drawer replacement semantics globally.
- Can preserve nested route pop by checking `Navigator.canPop()`.

Cons:

- Continues the scattered per-destination back fallback pattern.
- Future drawer destinations could forget the same guard.

## Option B: Change `closeDrawerThenPushReplacement` to push routes instead of replacement

Pros:

- Keeps previous home route underneath drawer destinations.
- Could reduce need for some local fallback logic.

Cons:

- Large behavior change for every drawer destination.
- Can create stack buildup across repeated drawer navigation.
- May conflict with existing screens that assume drawer destination replacement semantics.
- Higher regression risk.

## Decision

Prefer Option A for this bug fix. The issue is limited to two missing destinations, and the existing codebase already uses local `PopScope` fallback in comparable screens. A broader navigation abstraction can be considered separately if this pattern keeps recurring.

## Test Strategy

Focused widget tests should verify:

- Standalone `DraftBoxNavigationScreen` in classic/default mode handles system back by showing `HomeEntryScreen` classic home test override instead of letting the app exit.
- Standalone `CollectionsScreen` in classic/default mode handles system back by showing `HomeEntryScreen` classic home test override.
- Embedded bottom navigation variants continue delegating to `HomeEmbeddedNavigationHost` rather than pushing `HomeEntryScreen`.
- Draft selection/editor and collection detail/editor local route pops remain local and do not trigger home fallback.

## Risks

- If `PopScope` is placed too low in `DraftBoxScreen`, it may intercept picker-style `DraftBoxScreen.show()` use. Mitigation: apply fallback only to navigation-launched `DraftBoxNavigationScreen`, or gate behavior by presentation/showDrawer context.
- If `CollectionsScreen` fallback ignores `Navigator.canPop()`, nested detail/editor routes could be replaced by home. Mitigation: preserve local pop before home fallback.
- If fallback routes to `MemosListScreen` directly, bottom navigation preferences may be ignored. Mitigation: use `HomeEntryScreen`.
