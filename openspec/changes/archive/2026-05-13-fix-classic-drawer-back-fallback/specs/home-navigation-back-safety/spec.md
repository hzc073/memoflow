# home-navigation-back-safety Delta

## MODIFIED Requirements

### Requirement: Home fallback respects configured navigation entry

Standalone routes that need to reset to the app home SHALL route through `HomeEntryScreen` or an equivalent entry seam that respects workspace navigation preferences. They MUST NOT use direct `pushAndRemoveUntil` to a bare `MemosListScreen` when the user-visible intent is returning to the app home.

#### Scenario: Standalone tags fallback respects bottom navigation preference
- **WHEN** the Tags route is opened without an embedded navigation host and the workspace is configured for bottom navigation mode
- **THEN** returning home renders the bottom navigation shell instead of a standalone `MemosListScreen`

#### Scenario: Standalone about fallback respects bottom navigation preference
- **WHEN** the About route is opened without an embedded navigation host and the workspace is configured for bottom navigation mode
- **THEN** returning home renders the bottom navigation shell instead of a standalone `MemosListScreen`

#### Scenario: Standalone Draft Box fallback respects classic navigation
- **GIVEN** the workspace is using classic navigation mode
- **AND** Draft Box is opened as a standalone drawer destination without an embedded navigation host
- **WHEN** the user invokes system back while Draft Box is the current root route
- **THEN** the app returns to `HomeEntryScreen`
- **AND** the app does not exit from a single back press

#### Scenario: Standalone Collections fallback respects classic navigation
- **GIVEN** the workspace is using classic navigation mode
- **AND** Collections is opened as a standalone drawer destination without an embedded navigation host
- **WHEN** the user invokes system back while Collections is the current root route
- **THEN** the app returns to `HomeEntryScreen`
- **AND** the app does not exit from a single back press

#### Scenario: Local nested routes keep local pop before home fallback
- **GIVEN** Draft Box or Collections has opened a nested local route such as an editor or detail route
- **WHEN** the user invokes system back
- **THEN** the nested route pops locally first
- **AND** home fallback is not triggered until the standalone drawer destination itself receives back at root

#### Scenario: Desktop fallback keeps classic desktop home
- **WHEN** a standalone fallback routes through the home entry seam on a desktop platform
- **THEN** the app renders the classic desktop home behavior according to existing platform rules

### Requirement: Navigation shell regressions are guarded by tests

The implementation SHALL include regression tests that exercise shell-opened drawer routes and standalone home fallbacks. The tests MUST fail if a shell-opened route clears the `HomeBottomNavShell`, if a standalone fallback ignores bottom navigation preferences, or if a standalone classic drawer destination exits the app from a single back press instead of returning to home.

#### Scenario: Shell route back test catches stack clearing
- **WHEN** a test opens a drawer route from `HomeBottomNavShell`, invokes back, and settles animations
- **THEN** the test asserts that the bottom navigation shell remains visible and a classic or standalone home fallback is absent

#### Scenario: Drawer destination builder passes host context
- **WHEN** a test opens a drawer destination through the shell host path
- **THEN** the destination receives enough presentation and host context to delegate back/navigation actions to the shell

#### Scenario: Shell tag selection test catches standalone tag routes
- **WHEN** a test selects a tag through `HomeBottomNavShell.handleDrawerTag`
- **THEN** the test asserts that no standalone tag route is pushed above the shell
- **AND** the embedded memos destination receives the selected tag
- **AND** the bottom navigation bar remains visible

#### Scenario: Classic Draft Box back fallback test catches app exit
- **WHEN** a test renders standalone Draft Box in classic/default navigation mode and invokes system back
- **THEN** the test asserts that the home entry fallback is visible
- **AND** the Draft Box route is no longer the current root screen

#### Scenario: Classic Collections back fallback test catches app exit
- **WHEN** a test renders standalone Collections in classic/default navigation mode and invokes system back
- **THEN** the test asserts that the home entry fallback is visible
- **AND** the Collections route is no longer the current root screen
