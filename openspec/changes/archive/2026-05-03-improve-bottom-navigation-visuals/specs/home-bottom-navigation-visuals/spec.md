## ADDED Requirements

### Requirement: Bottom navigation surface covers the bottom safe area
When bottom navigation mode is active, the runtime bottom navigation surface SHALL keep its top edge stable while extending its decorated background through the device bottom safe area.

#### Scenario: Gesture navigation inset is covered
- **WHEN** the home screen renders `HomeBottomNavShell` on a device with a non-zero bottom safe-area inset
- **THEN** the bottom navigation background extends through the bottom inset
- **AND** the bar does not appear as a detached horizontal strip above the bottom edge

#### Scenario: Top edge remains stable
- **WHEN** the bottom navigation background is extended through the bottom safe area
- **THEN** the visible navigation surface top edge remains aligned with the previous bottom bar top edge
- **AND** page content is not pushed upward by an extra fixed-height navigation row

### Requirement: Destination items show icon and label
The runtime bottom navigation bar SHALL render each visible destination item with its configured icon and localized label.

#### Scenario: Visible destinations match registry metadata
- **WHEN** `HomeBottomNavShell` renders a configured destination from `HomeNavigationPreferences`
- **THEN** the destination item displays the `icon` from `homeRootDestinationDefinition(destination)`
- **AND** the destination item displays the localized label from `homeRootDestinationDefinition(destination).labelBuilder(context)`

#### Scenario: Hidden destination slots remain hidden
- **WHEN** a configured bottom navigation slot resolves to `HomeRootDestination.none`
- **THEN** that slot does not display a destination icon
- **AND** that slot does not display a destination label

#### Scenario: Destination labels remain readable and compact
- **WHEN** a destination item renders its label
- **THEN** the label uses the runtime bottom navigation label size
- **AND** the label remains within the compact bar without vertical overflow

### Requirement: Center create FAB remains primary action
The runtime bottom navigation bar SHALL preserve the center circular `MemoFlowFab` as the create action while destination items adopt icon-plus-label rendering.

#### Scenario: Create action remains a circular FAB
- **WHEN** bottom navigation mode renders
- **THEN** the center action is still rendered as `MemoFlowFab`
- **AND** the center action is not converted into a destination-style text tab

#### Scenario: Create action behavior is preserved
- **WHEN** the user taps the center create action from any bottom navigation destination
- **THEN** the existing note input flow opens
- **AND** existing long-press voice behavior remains available on supported mobile native platforms

### Requirement: Navigation controls use equal-width slot spacing
The runtime bottom navigation bar SHALL divide its available width into five equal slots for the four configured destination positions and the center create action. The center create action SHALL remain visually centered in the bar.

#### Scenario: Adjacent controls have even center spacing
- **WHEN** all four destination positions are visible around the center create action
- **THEN** the center-to-center spacing between adjacent navigation controls is equal within layout tolerance

#### Scenario: Create action is centered
- **WHEN** bottom navigation mode renders
- **THEN** the center of `MemoFlowFab` aligns with the horizontal center of `HomeBottomNavShell` within layout tolerance

#### Scenario: Hidden slots preserve spacing
- **WHEN** a configured bottom navigation slot resolves to `HomeRootDestination.none`
- **THEN** that slot still reserves its equal-width space
- **AND** the center create action remains horizontally centered
