# home-drawer-edge-swipe Specification

## Purpose
TBD - created by archiving change fix-drawer-swipe-gesture-regression. Update Purpose after archive.
## Requirements
### Requirement: Mobile home drawer opens from a rightward swipe over memo-list content
The system SHALL allow a rightward swipe gesture that starts on visible memo-list content to open the home drawer on native mobile platforms when drawer drag is enabled.

#### Scenario: Rightward swipe over a memo card opens the drawer
- **GIVEN** the app is running on a native mobile platform
- **AND** the home drawer is available in the current layout
- **AND** drawer drag is enabled for the memo-list screen
- **WHEN** the user starts a rightward swipe on visible memo-list content
- **THEN** the home drawer opens
- **AND** the user does not need to repeat the swipe to complete the open gesture

#### Scenario: Horizontal drawer swipe does not require empty screen space
- **GIVEN** the app is running on a native mobile platform
- **AND** the memo list contains tappable memo cards
- **WHEN** the user starts the drawer swipe on top of a memo card instead of empty background
- **THEN** the swipe still opens the drawer

### Requirement: Drawer swipe does not commit memo-card press behavior
The system SHALL prevent a drawer-opening swipe from committing memo-card press behavior such as tap, long press, or press-feedback state for the same gesture.

#### Scenario: Drawer swipe over a memo card does not tap the card
- **GIVEN** the app is running on a native mobile platform
- **AND** a memo card is visible under the pointer down position
- **WHEN** the user performs a rightward drawer-opening swipe that crosses drag threshold
- **THEN** the memo card is not activated as a tap target
- **AND** any transient press-feedback state is cleared before the gesture completes

#### Scenario: Drawer swipe over a memo card does not trigger long press
- **GIVEN** the app is running on a native mobile platform
- **AND** a memo card supports long press actions
- **WHEN** the user drags horizontally to open the drawer instead of holding the card
- **THEN** the long-press action does not fire

### Requirement: Drawer swipe remains disabled in layouts and modes that already suppress it
The system SHALL keep drawer swipe disabled when the memo-list screen is using a desktop side pane, when search is active, or when drawer open drag is otherwise disabled by existing screen state.

#### Scenario: Desktop side pane does not enable drawer drag
- **GIVEN** the memo-list screen is using the desktop side pane layout
- **WHEN** the user drags horizontally in the memo-list area
- **THEN** the drawer does not open from swipe

#### Scenario: Active search does not enable drawer drag
- **GIVEN** the memo-list screen is in active search mode
- **WHEN** the user drags horizontally in the memo-list area
- **THEN** the drawer does not open from swipe

### Requirement: Drawer swipe regression is covered by tests
The implementation SHALL include regression tests that begin the drag on memo-list content and verify the drawer opens without committing memo-card press behavior.

#### Scenario: Test opens drawer from memo-card area
- **WHEN** a widget test starts a rightward drag over memo-card content on a mobile platform
- **THEN** the test observes the drawer opening

#### Scenario: Test prevents memo-card activation during drawer swipe
- **WHEN** a widget test performs the same rightward drag over memo-card content
- **THEN** the test observes no memo tap or long-press activation for that gesture

