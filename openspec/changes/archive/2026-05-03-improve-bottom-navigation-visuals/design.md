## Context

`HomeBottomNavShell` previously rendered its bottom bar with `SafeArea(top: false)` outside the decorated background. The visible bar content had a fixed `52` height, so on devices with a bottom gesture inset the navigation surface could appear as a short strip rather than a panel attached to the bottom edge.

Runtime destination items also rendered only the localized label. The Laboratory bottom navigation settings preview already showed the intended destination affordance as `Icon + label`, using `homeRootDestinationDefinition(destination)` for both icon and label metadata.

The final implementation also addresses spacing feedback: the bottom bar uses five equal-width slots across the available navigation width. The four destination slots and the center create slot therefore have equal center-to-center spacing, and the circular `MemoFlowFab` remains exactly centered.

Dependency direction before the change:

```text
features/home/HomeBottomNavShell
  -> state/settings + state/system for preferences/session
  -> features/home/home_navigation_resolver
  -> features/home/home_root_destination_registry
```

Dependency direction after the change stays the same. The visual update remains local to the home shell and continues to use the existing resolver/registry seam; it does not add lower-layer imports into `features`, new `state -> features` dependencies, or direct cross-feature screen imports.

## Goals / Non-Goals

**Goals:**

- Keep the bottom navigation bar's top edge in the same visual position while extending its background through the bottom safe area.
- Render each visible destination with the configured icon and localized label.
- Use a five-slot equal-width layout so destination items and the center create action have consistent spacing.
- Keep the center circular `MemoFlowFab` visually centered and preserve its current tap, long-press, sizing, and haptic behavior.
- Increase destination label readability by using a larger label size while keeping compact vertical metrics to prevent overflow.
- Preserve existing destination order, hidden-slot handling, account-based availability, swipe navigation behavior, and shell preservation behavior.
- Add focused widget guardrails that check destination icons/labels remain present, the create FAB remains centered, compact text does not overflow, and slot spacing stays even.

**Non-Goals:**

- Do not redesign the center create action into a text-labeled tab item.
- Do not change `HomeNavigationPreferences`, workspace persistence, resolver semantics, or destination availability.
- Do not change drawer routes, shell back behavior, swipe navigation, or note input behavior.
- Do not touch API, sync, SQLite, WebDAV, private extension seams, billing, subscription, entitlement, or commercial logic.
- Do not introduce a new reusable design-system component unless implementation reveals clear duplication that cannot stay local.

## Decisions

### Decision 1: Move safe-area coverage into the decorated navigation surface

Choice: let the bottom navigation background cover the bottom `SafeArea` inset while keeping the content area height and top edge stable.

Rationale:

- The visual goal is to keep the top position unchanged and extend the lower edge downward.
- Decorating only the fixed-height content creates the detached-strip look on gesture-navigation devices.
- Keeping the top edge stable avoids stealing vertical space from the body beyond the current bottom bar reservation.

Alternative considered:

- Increase the fixed bar height. Rejected because it can move the bar's top edge upward and make content feel more compressed.

### Decision 2: Render destination items as icon plus label using the registry seam

Choice: render each `_HomeBottomNavigationItem` with `homeRootDestinationDefinition(destination).icon` and `labelBuilder(context)`.

Rationale:

- The icon source already exists in `HomeRootDestinationDefinition`, so no duplicate destination-to-icon map is needed.
- Existing tests and interactions can continue locating labels because labels remain visible text.
- This preserves modularity checklist item 6 by keeping feature collaboration through the registry seam rather than ad hoc mappings.

Alternative considered:

- Copy the preview card's local `buildItem` code into runtime. Rejected because runtime needs selected/unselected colors, taps, overflow handling, and accessibility behavior, while the shared metadata should be reused through the registry.

### Decision 3: Keep the center `MemoFlowFab` as a FAB, not a fifth destination tab

Choice: keep the existing circular create FAB and place it inside the center equal-width slot.

Rationale:

- The selected low-risk scope keeps the primary create affordance visually prominent.
- `MemoFlowFab` carries existing primary-action affordance and long-press voice behavior.
- Placing it in the center slot makes the add UI exactly centered without changing its gesture model.

Alternative considered:

- Make the center action match the Laboratory preview exactly as `Icons.add_circle + Create memo` text. Rejected for this change because it reduces primary-action emphasis and changes the touch target/gesture model.

### Decision 4: Use five equal-width slots instead of side groups plus fixed FAB width

Choice: replace the previous left group, fixed-width FAB area, and right group with five `Expanded` slots: left primary, left secondary, create FAB, right primary, right secondary.

Rationale:

- The previous layout was symmetric but not evenly spaced because the center FAB area had a fixed width.
- Equal-width slots make the center-to-center distance between adjacent controls consistent across the bar.
- Hidden `HomeRootDestination.none` slots continue to reserve space, preventing layout jumps when preferences or account availability change.

Alternative considered:

- Keep the fixed-width FAB area and only adjust padding. Rejected because it cannot guarantee equal spacing across different screen widths.

### Decision 5: Tune label metrics without changing icon size

Choice: keep destination icon size at `20`, increase label font size to `13`, keep text height compact, and translate the label down by `5` pixels.

Rationale:

- The user wanted larger text while keeping the UI/icon appearance stable.
- Compact line height prevents the previously observed 1px vertical overflow.
- Translating only the label gives the requested lower text placement without changing the bar height or icon placement.

Alternative considered:

- Increase the entire bar height or icon size. Rejected because it would alter the visual rhythm and could move the top edge, which the original requirement explicitly wanted to keep stable.

### Decision 6: Add focused widget guardrails instead of broad golden testing

Choice: update focused widget tests to assert visible destination icons/labels, center `MemoFlowFab`, even spacing, compact label fit, and the SafeArea decoration wrapper, without adding pixel goldens.

Rationale:

- The project already has strong home shell widget tests and no broad golden workflow for this area.
- Icon/label/FAB structure, center alignment, and spacing can be tested deterministically.
- Safe-area background attachment is primarily visual; manual Android gesture-navigation verification remains useful.

Alternative considered:

- Add a golden screenshot. Rejected because it would introduce test asset maintenance and platform rendering sensitivity for a small visual adjustment.

## Risks / Trade-offs

- [Risk] Larger labels could make long localized strings more crowded on narrow screens. -> Mitigation: keep `maxLines: 1`, ellipsis overflow, compact text height, and preserve hidden-slot behavior.
- [Risk] Translating labels down could clip if future text metrics change. -> Mitigation: keep a compact overflow regression test and preserve the fixed icon size.
- [Risk] Extending the decorated surface through the safe area could make the bottom bar feel taller. -> Mitigation: keep the top edge/content reservation stable and only fill the area below.
- [Risk] Widget tests may not fully capture the safe-area visual seam. -> Mitigation: add structural tests and include manual Android gesture-navigation verification.
- [Risk] Moving layout wrappers could accidentally affect tap targets. -> Mitigation: keep the `InkWell` destination labels and `MemoFlowFab` interaction tests intact.

## Migration Plan

- No data migration is required.
- Rollout is a runtime UI-only change inside `HomeBottomNavShell`.
- Rollback strategy: restore the previous bottom bar wrapper and destination item layout if visual or hit-test regressions appear.

## Open Questions

- None for the archived scope. A future change can separately explore whether the center create action should become a labeled tab-like item.
