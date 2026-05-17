## Context

The memo list body already owns a UI-only adaptive side state for the floating collapse and back-to-top action group. On native mobile platforms, touch-scroll input updates the active side; desktop, web, and non-mobile platforms resolve to the right side. The current layout renders the group in a `Positioned` slot with either `left: 16` or `right: 16`, so side changes are visually instantaneous.

The individual buttons already animate their own visibility, opacity, and scale. The missing motion is specifically the group-level transition between left and right side placement. The desired feel is iPhone-like: natural, elastic, and smooth, with a small amount of spring/inertia rather than a decorative bounce.

Architecture phase is `evolve_modularity`. The expected touched area is feature UI composition under `features/memos/widgets`; this is not one of the documented coupling hotspots (`state -> features`, `application -> features`, or `core -> higher-layer`). Dependency direction should remain unchanged: feature widgets may depend on Flutter, `core` motion helpers, and sibling memo widgets, but no lower layer should depend on `features/memos`.

## Goals / Non-Goals

**Goals:**

- Animate the whole floating action group when mobile touch-scroll changes its side.
- Use a real spring/inertia-driven transition with subtle overshoot, light scale softening, and optional opacity softening.
- Preserve the final side alignment, bottom offset, stable vertical slots, button semantics, haptics, and pointer behavior.
- Respect `MediaQuery.disableAnimations` and `MediaQuery.accessibleNavigation` via the existing app motion accessibility seam.
- Keep motion implementation feature-local and avoid new cross-layer dependencies.
- Add focused widget coverage for intermediate movement, final alignment, reduced-motion behavior, and non-mobile right alignment.

**Non-Goals:**

- Do not change when the active side is selected.
- Do not change collapse visibility logic, back-to-top visibility logic, scroll-anchor restoration, or scroll-to-top behavior.
- Do not redesign button icons, colors, touch target sizes, or vertical stacking.
- Do not add API, data model, sync, route, private hook, or commercial behavior changes.
- Do not introduce a third-party animation package.

## Decisions

### Decision 1: Animate the group, not each button

Wrap the existing floating action `Column` in a small side-transition widget instead of modifying `MemoFloatingCollapseButton` or `BackToTopButton`.

Rationale:

- The product issue is the group jumping between sides; individual visibility/press animations already exist.
- Group-level motion preserves consistent spacing between collapse and back-to-top actions.
- It keeps button responsibilities narrow: buttons own visibility and interaction feedback; the memo-list body owns side placement.

Alternative considered: add more `AnimatedScale` / `AnimatedOpacity` behavior to each button. This would soften visibility changes but would not solve the side-position jump, and it could conflict with the collapse button's existing scrolling opacity state.

### Decision 2: Use a feature-local spring transition wrapper

Introduce a private widget such as `_MemoListFloatingActionSideSpringTransition` in `memos_list_screen_body.dart` or a sibling feature-local file. It should receive the resolved side and child, drive an `AnimationController` with a `SpringSimulation`, and render the child at the animated side position.

Rationale:

- A custom wrapper contains the added complexity and keeps the main body build method readable.
- `SpringSimulation` gives real inertial settling instead of approximating spring behavior with a fixed curve.
- Keeping the widget private or feature-local avoids promoting memo-list-specific motion into `core` prematurely.

Alternative considered: use `AnimatedPositioned` or `AnimatedAlign`. These are simpler and testable, but their fixed-duration curve cannot provide true spring/inertia. They are acceptable fallbacks only if spring simulation proves too brittle.

### Decision 3: Prefer alignment interpolation over manual distance math when possible

The transition should avoid manually calculating button width and viewport distance unless tests show it is necessary. A practical shape is to render inside a full-width horizontal slot (`left: 16`, `right: 16`) and animate between `Alignment.bottomRight` and `Alignment.bottomLeft`, allowing the spring value to slightly exceed the target for a controlled overshoot.

Rationale:

- It avoids fragile measurement code and keeps final alignment compatible with existing tests.
- It lets the same wrapper handle both buttons as a single group.
- The implementation remains resilient to text scaling, safe area differences, and future button-size changes.

Alternative considered: drive `Transform.translate` using measured pixel distance. This gives direct control over overshoot in pixels, but it requires measuring parent and child widths and increases layout complexity.

### Decision 4: Keep the spring subtle and accessibility-aware

The side transition should feel elastic but not playful. Suggested starting values are mass around `1.0`, stiffness around `420-520`, and damping around `30-38`, with scale no lower than about `0.975` during travel and final opacity returning to `1.0`. Reduced-motion settings should jump directly to the target side or use zero effective duration.

Rationale:

- The target feel is natural Apple-like inertia, not a visible rubber-band bounce.
- Subtle scale/opacity helps mask fast horizontal travel without fighting the buttons' existing visibility states.
- Accessibility settings must be honored consistently with the rest of the app's motion language.

Alternative considered: use `Curves.elasticOut` or a large bounce curve. This is visually obvious and likely too decorative for a utility action group.

### Decision 5: Preserve modularity by keeping motion inside the feature UI seam

No state provider, application service, core upward dependency, or shared domain logic should be added for this change. If motion constants are needed, they can be private constants beside the wrapper unless repeated use justifies a later core motion token.

Rationale:

- The active architecture phase is `evolve_modularity`.
- The change does not touch a known coupling hotspot, so the appropriate guardrail is to avoid widening dependencies.
- A private feature-local seam leaves the touched area equal or better structured by isolating the animation mechanics from side-detection logic.

Alternative considered: add a general spring transition widget to `core`. This may be useful later, but doing it now would broaden the public app motion API for a single memo-list use case.

## Risks / Trade-offs

- [Risk] Spring overshoot may cause the group to clip or briefly extend beyond the intended side margin. → Mitigation: keep overshoot subtle, render within a full-width inset slot, and add tests for final alignment and in-bounds intermediate frames if practical.
- [Risk] Widget tests can become flaky if they rely on exact spring timing. → Mitigation: assert qualitative states such as "not immediately at final side after one pump" and "settles to final side after `pumpAndSettle`", not exact mid-frame pixels.
- [Risk] Opacity softening may compound with the collapse button's scrolling opacity. → Mitigation: apply any group opacity conservatively or omit it if it makes the scrolling state too dim.
- [Risk] A custom controller adds lifecycle complexity. → Mitigation: keep the wrapper small, dispose the controller, handle side updates in `didUpdateWidget`, and short-circuit when app motion is disabled.
- [Risk] Alignment interpolation with overshoot may be less pixel-explicit than `Transform.translate`. → Mitigation: start with alignment interpolation for simplicity; switch to measured translation only if acceptance tests or visual review show insufficient control.

## Migration Plan

- Add the feature-local transition wrapper around the existing floating action group.
- Keep existing side-detection and final placement behavior intact.
- Add focused tests before broad validation.
- Rollback strategy: remove the wrapper and return the floating action group to the current `Positioned` left/right placement; existing button visibility and side-detection logic can remain unchanged.

## Open Questions

- None. The selected direction is a feature-local spring/inertia transition for side changes.
