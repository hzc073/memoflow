## Context

`MemosListMemoCard` currently wraps the whole memo card in `AppPressScale`, whose default `scaleDown` is `0.97`. Because transform scaling does not change the parent layout slot, taller memo cards visibly shrink inside the same reserved height and expose a larger temporary gap between adjacent cards.

This change is in architecture phase `evolve_modularity`. The touched area is a feature UI widget under `features/memos/widgets`, not a known dependency-direction hotspot. Before and after the change, dependency direction remains `features/memos/widgets -> core` for shared motion constants and Flutter UI primitives; no `state -> features`, `application -> features`, or `core -> higher-layer` dependency is introduced.

## Goals / Non-Goals

**Goals:**
- Make memo-card press feedback fixed-size and nearly imperceptible.
- Remove proportional full-card scaling from memo list card press feedback.
- Preserve all existing memo-card gestures and selected/hover/focus visuals.
- Keep shared `AppPressScale` behavior unchanged for other controls.

**Non-Goals:**
- Redesign memo card spacing, selected-card styling, hover styling, or preview-pane animation.
- Change memo data, API routes, persistence, sync, or desktop preview behavior.
- Add commercial/private-extension behavior.

## Decisions

1. Use fixed logical-pixel motion for memo cards instead of proportional scale.

   The memo card should translate downward by a tiny fixed amount, such as `Offset(0, 1)`, during press. This keeps the perceived movement independent of memo height. A full-card scale like `0.998` would be much softer than today but would still make taller cards move more than shorter cards.

   Alternative considered: lower `AppPressScale.scaleDown` to `0.998`. Rejected because it remains proportional and does not fully address the height-dependent visual gap.

2. Keep the fixed-offset press feedback scoped to the memo card.

   The implementation should replace the memo-card `AppPressScale` wrapper with a memo-card-specific fixed-offset press wrapper or equivalent local widget. This avoids changing the global `AppPressScale` default used by buttons, drawer rows, preview-pane actions, and search chips.

   Alternative considered: extend `AppPressScale` globally with a fixed-offset mode. Acceptable only if the implementation remains backward compatible and memo-card usage opts into it explicitly, but local scoping is lower risk for this UI-only adjustment.

3. Preserve gesture ownership.

   The press wrapper should only provide visual feedback. Existing `InkWell` callbacks for tap, tap down, tap up, tap cancel, long press, and the surrounding double-tap/right-click handling should remain the source of interaction behavior.

4. Preserve modularity boundaries.

   No seam extraction is needed because this change does not touch a coupling hotspot or shared domain logic. The scoped modularity safeguard is to keep the behavior inside `features/memos/widgets` and avoid moving feature-specific UI behavior into `core` unless it remains generic and dependency-neutral.

## Risks / Trade-offs

- [Risk] A fixed downward transform can still reveal a tiny top gap while pressed. -> Mitigation: cap the movement at roughly one logical pixel and avoid any scale transform.
- [Risk] A local wrapper may duplicate a small amount of press-state logic. -> Mitigation: keep it private to the memo card and limited to pointer press state, or use a backward-compatible core helper only if that reduces duplication without changing existing callers.
- [Risk] Widget tests may not directly perceive visual subtlety. -> Mitigation: add focused assertions where practical, and rely on manual desktop verification for the final motion feel.
- [Risk] Reduced-motion users should not receive new animation. -> Mitigation: keep using `AppMotion.effectiveDuration` or an equivalent reduced-motion check so the transition duration becomes zero when animations are disabled.

## Migration Plan

No data migration is required. The change can be rolled back by restoring the previous memo-card press wrapper.

## Open Questions

- None. The intended motion is fixed-size and intentionally minimal.
