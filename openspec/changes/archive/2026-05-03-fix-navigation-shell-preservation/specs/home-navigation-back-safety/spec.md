## ADDED Requirements

### Requirement: Shell-launched drawer routes preserve the home navigation shell
Drawer destinations opened from a home navigation shell SHALL preserve that shell when handling back, close, destination selection, tag selection, or notification navigation. The route MUST delegate shell-level navigation to `HomeEmbeddedNavigationHost` when one is provided and MUST NOT clear the navigator stack to a standalone `MemosListScreen`.

#### Scenario: Tags route returns to shell
- **WHEN** the user opens the Tags route from a bottom navigation shell or desktop navigation rail and invokes back
- **THEN** the app returns to the shell primary destination or dismisses the overlay route while the configured home navigation shell remains mounted

#### Scenario: About route returns to shell
- **WHEN** the user opens the About route from a bottom navigation shell or desktop navigation rail and invokes back
- **THEN** the app returns to the shell primary destination or dismisses the overlay route while the configured home navigation shell remains mounted

#### Scenario: Drawer route selects another destination through host
- **WHEN** a shell-launched drawer route receives a drawer destination selection
- **THEN** the route delegates to `HomeEmbeddedNavigationHost.handleDrawerDestination` and does not push a replacement route that bypasses the shell

#### Scenario: Drawer route selects a tag through host
- **WHEN** a shell-launched drawer route receives a tag selection
- **THEN** the route delegates to `HomeEmbeddedNavigationHost.handleDrawerTag` and does not push a standalone tag `MemosListScreen` outside the shell

#### Scenario: Shell tag selection renders inside bottom navigation
- **GIVEN** the user is in bottom navigation mode and the memos root destination is visible in the shell
- **WHEN** the user selects a tag from the drawer or a shell-launched drawer route
- **THEN** the app keeps `HomeBottomNavShell` mounted
- **AND** the memos root destination renders the selected tag filter
- **AND** the bottom navigation bar remains visible

#### Scenario: Back clears shell tag filter before leaving shell
- **GIVEN** the user is in bottom navigation mode with a selected shell tag filter
- **WHEN** the user invokes system back
- **THEN** the shell clears the active tag filter first
- **AND** the shell remains mounted on the memos root destination

#### Scenario: Drawer route opens notifications through host
- **WHEN** a shell-launched drawer route receives a notifications action
- **THEN** the route delegates to `HomeEmbeddedNavigationHost.handleOpenNotifications` and preserves the shell navigation mode

### Requirement: Home fallback respects configured navigation entry
Standalone routes that need to reset to the app home SHALL route through `HomeEntryScreen` or an equivalent entry seam that respects workspace navigation preferences. They MUST NOT use direct `pushAndRemoveUntil` to a bare `MemosListScreen` when the user-visible intent is returning to the app home.

#### Scenario: Standalone tags fallback respects bottom navigation preference
- **WHEN** the Tags route is opened without an embedded navigation host and the workspace is configured for bottom navigation mode
- **THEN** returning home renders the bottom navigation shell instead of a standalone `MemosListScreen`

#### Scenario: Standalone about fallback respects bottom navigation preference
- **WHEN** the About route is opened without an embedded navigation host and the workspace is configured for bottom navigation mode
- **THEN** returning home renders the bottom navigation shell instead of a standalone `MemosListScreen`

#### Scenario: Desktop fallback keeps classic desktop home
- **WHEN** a standalone fallback routes through the home entry seam on a desktop platform
- **THEN** the app renders the classic desktop home behavior according to existing platform rules

### Requirement: Navigation shell regressions are guarded by tests
The implementation SHALL include regression tests that exercise shell-opened drawer routes and standalone home fallbacks. The tests MUST fail if a shell-opened route clears the `HomeBottomNavShell` or if a standalone fallback ignores bottom navigation preferences.

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
