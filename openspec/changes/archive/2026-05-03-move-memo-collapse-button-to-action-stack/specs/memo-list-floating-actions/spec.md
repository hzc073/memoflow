## ADDED Requirements

### Requirement: Expanded memo collapse action uses stable bottom placement
The memo list SHALL show the floating collapse action as a fixed bottom circular action above the back-to-top action when an expanded long memo needs an external collapse affordance.

#### Scenario: Collapse action appears above back-to-top
- **WHEN** a long memo is expanded and the memo list determines that its inline `Collapse` control is outside the viewport grace area
- **THEN** the memo list displays a circular collapse action above the back-to-top action slot
- **AND** activating the collapse action collapses the active expanded memo

#### Scenario: Collapse action does not jump when back-to-top is hidden
- **WHEN** the floating collapse action is visible and the back-to-top action is not visible
- **THEN** the collapse action remains in the same bottom side slot that it uses when the back-to-top action is visible
- **AND** the collapse action does not move downward into the hidden back-to-top slot

#### Scenario: Inline collapse remains the source of visibility semantics
- **WHEN** the expanded memo's inline `Collapse` control is visible within the viewport grace area
- **THEN** the memo list does not show the floating collapse action
- **AND** the inline `Collapse` control remains available inside the memo card

### Requirement: Mobile floating actions follow touch-scroll side
The memo list SHALL keep collapse and back-to-top controls as one vertical action group, and on mobile native platforms the group SHALL move to the side where the user most recently started a touch scroll.

#### Scenario: Mobile right-side scroll places action group on right
- **WHEN** the app is running on a mobile native platform
- **AND** the user starts a touch scroll from the right half of the memo list viewport
- **THEN** the collapse/back-to-top action group is positioned on the right side

#### Scenario: Mobile left-side scroll places action group on left
- **WHEN** the app is running on a mobile native platform
- **AND** the user starts a touch scroll from the left half of the memo list viewport
- **THEN** the collapse/back-to-top action group is positioned on the left side

#### Scenario: Plain taps do not move the action group
- **WHEN** the app is running on a mobile native platform
- **AND** the user taps memo list content without starting a scroll
- **THEN** the collapse/back-to-top action group remains on its current side

#### Scenario: Desktop action group remains right aligned
- **WHEN** the app is running on a desktop or non-mobile platform
- **AND** the user scrolls with mouse wheel, trackpad, keyboard, or touch input
- **THEN** the collapse/back-to-top action group remains positioned on the right side

### Requirement: Floating memo list actions preserve existing action behavior
The memo list SHALL preserve existing back-to-top and compose action behavior while adding the fixed bottom collapse action slot and mobile adaptive side placement.

#### Scenario: Back-to-top behavior is preserved
- **WHEN** the user activates the back-to-top action
- **THEN** the memo list scrolls to the top using the existing back-to-top callback
- **AND** the collapse action placement does not change the back-to-top action's visibility threshold or tap target

#### Scenario: Compose FAB avoidance is preserved
- **WHEN** the primary compose `MemoFlowFab` is visible
- **THEN** the back-to-top action remains offset above the compose FAB as before
- **AND** the collapse action is stacked above the back-to-top action without overlapping the compose FAB

#### Scenario: Bottom safe area avoidance is preserved
- **WHEN** the device has a non-zero bottom safe-area inset
- **THEN** the back-to-top and collapse actions remain positioned above the bottom inset using the existing memo list bottom offset behavior

### Requirement: Floating collapse action remains accessible and theme-colored
The floating collapse action SHALL expose collapse semantics, use the same theme-controlled primary background as the back-to-top action, and remain visually distinct by icon.

#### Scenario: Collapse action exposes accessible label
- **WHEN** the floating collapse action is visible
- **THEN** assistive technologies can identify it as a button for collapsing the active expanded memo
- **AND** the accessible label uses the localized collapse text

#### Scenario: Collapse and back-to-top icons are distinct
- **WHEN** the floating collapse action and back-to-top action are both visible
- **THEN** the collapse action uses an icon that communicates collapsing or compacting content
- **AND** the back-to-top action continues to use its existing upward navigation icon

#### Scenario: Appearance theme color updates both bottom actions
- **WHEN** the app appearance theme color changes
- **THEN** the floating collapse action background uses the same updated `MemoFlowPalette.primary` color as the back-to-top action
- **AND** the collapse action icon remains readable against that primary background
