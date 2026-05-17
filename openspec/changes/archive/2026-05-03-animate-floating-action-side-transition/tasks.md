## 1. Spring Transition Implementation

- [x] 1.1 Add a feature-local floating action side transition wrapper around the existing collapse/back-to-top action group.
- [x] 1.2 Drive side changes with `AnimationController` and `SpringSimulation`, including safe controller lifecycle handling.
- [x] 1.3 Preserve existing final left/right insets, bottom offset, cross-axis alignment, vertical action gap, and reserved back-to-top slot behavior.
- [x] 1.4 Add subtle group-level scale and optional opacity softening without overriding button-level visibility, scrolling opacity, press scale, haptics, semantics, or callbacks.
- [x] 1.5 Short-circuit the side transition when `MediaQuery.disableAnimations` or `MediaQuery.accessibleNavigation` disables app motion.

## 2. Platform and Boundary Behavior

- [x] 2.1 Keep native mobile touch-scroll side detection as the only trigger for adaptive side movement.
- [x] 2.2 Keep desktop, web, and other non-mobile platforms right aligned after scroll input.
- [x] 2.3 Ensure hidden floating actions still ignore pointer input and preserve their existing semantics exclusion behavior.
- [x] 2.4 Confirm the change remains inside `memos_flutter_app/lib/features/memos/widgets` or existing lower-level motion dependencies with no new reverse-layer imports.

## 3. Focused Widget Coverage

- [x] 3.1 Add widget coverage that a mobile right-to-left side change has an intermediate animated position before settling at the existing left inset.
- [x] 3.2 Add widget coverage that a mobile left-to-right side change has an intermediate animated position before settling at the existing right inset.
- [x] 3.3 Update existing final-position tests so they wait for transition settling while preserving exact final alignment expectations.
- [x] 3.4 Add reduced-motion coverage showing side changes skip spring travel and land directly on the target side.
- [x] 3.5 Preserve or add coverage that desktop/non-mobile scroll input remains right aligned and does not start adaptive side animation.

## 4. Verification

- [x] 4.1 Run focused memo-list body widget tests covering floating action side behavior.
- [x] 4.2 Run targeted analyzer for touched Dart files from `memos_flutter_app`.
- [x] 4.3 Review touched imports to confirm no new `state -> features`, `application -> features`, or `core -> features` dependency is introduced.
- [x] 4.4 Run broader `flutter analyze` and `flutter test` from `memos_flutter_app` before PR handoff, or document unrelated pre-existing failures.
