# memo-list-floating-action-side-transition Specification

## Purpose
TBD - created by archiving change animate-floating-action-side-transition. Update Purpose after archive.
## Requirements
### Requirement: Floating action side changes animate with spring motion
The memo list floating action group SHALL animate as one group when native mobile touch-scroll input changes the resolved side between left and right.

#### Scenario: Mobile touch scroll moves group with intermediate motion
- **GIVEN** the memo list is running on a native mobile platform
- **AND** the floating action group is visible on the right side
- **WHEN** a touch scroll begins from the left half of the memo list viewport and commits the side change
- **THEN** the floating action group starts moving from the right side toward the left side instead of jumping immediately to the final left position
- **AND** the floating action group settles at the existing left-side inset after the transition completes

#### Scenario: Reverse mobile side transition settles on right
- **GIVEN** the memo list is running on a native mobile platform
- **AND** the floating action group is visible on the left side
- **WHEN** a touch scroll begins from the right half of the memo list viewport and commits the side change
- **THEN** the floating action group starts moving from the left side toward the right side instead of jumping immediately to the final right position
- **AND** the floating action group settles at the existing right-side inset after the transition completes

### Requirement: Floating action side transition preserves existing layout and interaction contracts
The spring side transition SHALL preserve the floating action group's existing final layout, vertical slot behavior, visibility behavior, semantics, and pointer behavior.

#### Scenario: Vertical spacing remains stable during and after side transition
- **GIVEN** the collapse action and back-to-top action are both present in the floating action group
- **WHEN** the floating action group transitions between sides
- **THEN** the collapse action remains above the reserved back-to-top slot
- **AND** the gap between the collapse action and back-to-top action remains the existing floating action gap after the transition settles

#### Scenario: Hidden actions remain non-interactive
- **GIVEN** one of the floating actions is hidden by its existing visibility state
- **WHEN** the floating action group transitions between sides
- **THEN** the hidden action remains ignored for pointer input
- **AND** the hidden action remains excluded from active semantics according to its existing button behavior

#### Scenario: Button-level animation behavior is preserved
- **GIVEN** the floating collapse action changes visibility or scrolling opacity
- **WHEN** the floating action group side transition is active
- **THEN** the floating collapse action keeps its existing visibility, opacity, scale, tooltip, semantics, and `onPressed` behavior
- **AND** the back-to-top action keeps its existing visibility, press scale, haptics, semantics, and `onPressed` behavior

### Requirement: Floating action side transition respects platform and accessibility constraints
The memo list floating action group SHALL only use adaptive side spring transitions where adaptive side placement already applies, and it SHALL respect reduced-motion accessibility settings.

#### Scenario: Desktop and non-mobile platforms remain right aligned
- **GIVEN** the memo list is running on desktop, web, or another non-mobile platform
- **WHEN** scroll input occurs from the left half of the viewport
- **THEN** the floating action group remains aligned to the existing right-side inset
- **AND** no adaptive side transition is started

#### Scenario: Reduced motion skips side animation
- **GIVEN** the memo list is running on a native mobile platform
- **AND** platform accessibility settings disable animations or request accessible navigation
- **WHEN** touch-scroll input changes the resolved floating action side
- **THEN** the floating action group updates to the target side without a spring/inertia travel animation
- **AND** the final side alignment remains the same as the animated behavior

### Requirement: Floating action side transition stays within memo-list UI boundaries
The implementation SHALL keep side-transition motion inside the memo-list feature UI seam and SHALL NOT add new dependencies from `state`, `application`, or `core` layers to `features/memos`.

#### Scenario: Motion implementation remains feature-local
- **WHEN** the side transition implementation is added
- **THEN** the implementation is contained in `memos_flutter_app/lib/features/memos/widgets` or an existing lower-level motion helper dependency used by that feature
- **AND** no new `state -> features`, `application -> features`, or `core -> features` dependency is introduced

