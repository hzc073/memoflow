## Context

AI Summary can be opened from the bottom navigation shell as a standalone overlay route when it is not one of the visible tabs. In that mode the route receives:

- `presentation: HomeScreenPresentation.standalone`
- an `_OverlayHomeNavigationHost` as `embeddedNavigationHost`

The live Dart stack from the ANR investigation showed the main isolate repeatedly cycling through `Navigator.maybePop()` → `_OverlayHomeNavigationHost.handleBackToPrimaryDestination()` → `AiSummaryScreen._backToAllMemos()` → `PopScope.onPopInvokedWithResult()`. The Android ANR dump showed input dispatch timing out while the app consumed CPU on Dart code, which matches a navigation recursion rather than storage, WebDAV, or network blocking.

The current architecture phase is `evolve_modularity`. This change touches the `features/home` navigation seam and feature screens that consume it, so checklist item `6.` is relevant. The design should preserve the host seam instead of adding direct feature-to-feature shortcuts, and add focused guardrail tests per checklist item `8.`.

## Goals / Non-Goals

**Goals:**

- Stop AI Summary back navigation from entering a recursive `maybePop()` loop.
- Define one safe semantic for overlay-host `handleBackToPrimaryDestination`: dismiss the overlay route or switch the shell to the primary destination exactly once.
- Keep the `HomeEmbeddedNavigationHost` seam as the boundary between feature pages and the bottom navigation shell.
- Add widget-level guardrails that reproduce the risky standalone-overlay host combination.
- Check peer pages that share the same pattern so the fix is not AI Summary-only by accident.

**Non-Goals:**

- Do not change AI settings persistence, prompt template editing, analysis execution, WebDAV sync scheduling, or server API behavior.
- Do not redesign the bottom navigation shell, drawer destination registry, or tab preference model.
- Do not add commercial/private extension behavior or paid-feature state.
- Do not broaden architecture cleanup beyond the navigation back-loop hotspot.

## Decisions

### Decision 1: Fix the overlay host seam, not only AI Summary

The primary fix should live at `_OverlayHomeNavigationHost.handleBackToPrimaryDestination` or an adjacent host-owned seam because the recursive edge is caused by the overlay host asking the same route's `PopScope` whether it may pop.

Before:

```text
features/review/AiSummaryScreen
  -> HomeEmbeddedNavigationHost.handleBackToPrimaryDestination(context)
  -> features/home/_OverlayHomeNavigationHost
  -> Navigator.maybePop(context)
  -> same route PopScope
```

After:

```text
features/review/AiSummaryScreen
  -> HomeEmbeddedNavigationHost.handleBackToPrimaryDestination(context)
  -> features/home/_OverlayHomeNavigationHost
  -> direct overlay dismissal OR shell primary switch
```

Rationale: the host owns whether a feature page is a tab child or an overlay route. Feature pages should not need to know which navigator route shape created them.

Alternative considered: update `AiSummaryScreen._backToAllMemos` to directly call `Navigator.pop` when it has an overlay host. This would fix the observed page but duplicate shell knowledge inside one feature and leave Explore, Resources, Daily Review, and Notifications exposed to the same pattern.

### Decision 2: Avoid `maybePop()` for overlay-host back-to-primary

The overlay host should not use `Navigator.maybePop()` to dismiss the same overlay route that contains a page-level `PopScope(canPop: false)`. It should use a deterministic dismissal path that does not re-enter `PopScope.onPopInvokedWithResult` for the same back action.

Preferred implementation direction:

- If the overlay navigator can dismiss the overlay route, dismiss it directly.
- After dismissal, schedule the shell primary-destination switch if needed.
- If no overlay route is available or the shell is already the active context, switch the shell to the primary destination without attempting another route pop.
- Add a small reentrancy guard if direct dismissal can still re-trigger `handleBackToPrimaryDestination` on some platform route path.

Alternative considered: pass `HomeScreenPresentation.embeddedBottomNav` to overlay routes. This would make their `PopScope` stop intercepting, but it changes app-bar affordances and conflates "tab child" with "standalone overlay route."

### Decision 3: Preserve the existing feature/home boundary

The fix should not introduce dependencies from `state`, `application`, or `core` into `features`, and should not move screen-specific back behavior into lower layers. The navigation contract remains:

```text
feature screen -> HomeEmbeddedNavigationHost interface -> home shell
```

The scoped modularity improvement is a guardrail test around this seam, plus any small host API clarification needed to make overlay route dismissal explicit.

Alternative considered: a global core navigation utility that knows about home destinations. This would worsen the existing `core -> features` upward-dependency hotspot and is out of scope.

## Risks / Trade-offs

- [Risk] Programmatic route dismissal could bypass unsaved-state prompts on future overlay pages. → Mitigation: only use the direct dismissal path for host-level "back to primary" overlays that already delegate to the host; keep editor/detail routes on their local navigator behavior.
- [Risk] Fixing the host may change back behavior for other overlay screens. → Mitigation: cover AI Summary and at least one host-level overlay route in tests, then manually inspect peer screens for matching assumptions.
- [Risk] A reentrancy guard could hide a deeper route-shape bug. → Mitigation: treat the guard as defensive only; tests should assert the route stack settles and the host action is not repeatedly invoked.
- [Risk] Widget tests may need shell setup that is heavier than current review tests. → Mitigation: prefer a focused fake `HomeEmbeddedNavigationHost` or a minimal `HomeBottomNavShell` scenario over full app startup.

## Migration Plan

1. Add focused tests that reproduce the standalone overlay host + `PopScope` back path before changing behavior.
2. Update the overlay host dismissal semantics.
3. Verify AI Summary back returns to the primary destination without hanging.
4. Check peer overlay routes for equivalent behavior and add coverage if the host-level test does not cover them.
5. Rollback strategy: revert the host change and related tests; no data migration or settings cleanup is required.

## Open Questions

- Should the final guardrail be a `HomeBottomNavShell` integration-style widget test, or a smaller test around `_OverlayHomeNavigationHost` behavior through a public route path? Implementation can choose the smallest test that catches the recursion.
- If direct dismissal invokes `PopScope` callbacks with `didPop: true` on all supported Flutter platforms, no reentrancy guard may be needed; this should be verified while implementing.
