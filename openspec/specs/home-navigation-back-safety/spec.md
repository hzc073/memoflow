# home-navigation-back-safety Specification

## Purpose
TBD - created by archiving change fix-ai-summary-back-anr. Update Purpose after archive.
## Requirements
### Requirement: Overlay back-to-primary exits without recursion
Standalone overlay routes that receive a `HomeEmbeddedNavigationHost` SHALL handle back-to-primary requests as a single terminating navigation operation. The operation MUST NOT re-enter the same route's `PopScope.onPopInvokedWithResult` through `Navigator.maybePop()` for the same back action.

#### Scenario: AI Summary overlay handles Android back
- **WHEN** AI Summary is opened as a standalone overlay route with an embedded navigation host and the user invokes Android back
- **THEN** the app dismisses the overlay route or returns the shell to its primary destination without repeatedly invoking the same route's pop callback

#### Scenario: AI Summary app bar back handles overlay route
- **WHEN** AI Summary is opened as a standalone overlay route with an embedded navigation host and the user taps the page back button
- **THEN** the app performs one back-to-primary navigation action and remains responsive to subsequent input

#### Scenario: Overlay host receives repeated back requests
- **WHEN** a second back-to-primary request arrives while the first overlay dismissal is still settling
- **THEN** the host MUST coalesce or ignore the duplicate request rather than starting a recursive navigation loop

### Requirement: Embedded tab back switches to primary destination
Bottom navigation pages rendered with `HomeScreenPresentation.embeddedBottomNav` SHALL use system back to switch from a non-primary visible tab to the primary destination once. This behavior MUST NOT create a new overlay route and MUST NOT clear unrelated navigator history.

#### Scenario: Non-primary tab receives system back
- **WHEN** a visible bottom navigation tab other than the primary destination is active and the user invokes system back
- **THEN** the shell switches to the primary destination exactly once

#### Scenario: Primary tab receives system back
- **WHEN** the primary bottom navigation destination is active and the user invokes system back
- **THEN** the shell allows the platform or parent navigator to handle the back action according to existing app behavior

### Requirement: Nested editor routes keep local pop behavior
Nested routes opened from AI Summary, such as custom template settings and prompt editor routes, SHALL keep their local navigator behavior. Saving, cancelling, or backing out of nested editors MUST NOT trigger host-level back-to-primary unless the nested route explicitly delegates to the host.

#### Scenario: Prompt editor cancel returns to settings sheet
- **WHEN** the user opens the AI Summary custom prompt editor and backs out without saving
- **THEN** the editor route closes and returns to the AI Summary settings sheet without switching the bottom navigation shell

#### Scenario: Prompt editor save returns to settings sheet
- **WHEN** the user saves the AI Summary prompt editor
- **THEN** the editor route closes, the settings sheet refreshes its displayed prompt state, and no host-level back-to-primary action is invoked

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

### Requirement: Shell-launched About routes SHALL contain long content without overflow

Shell-launched drawer routes that render `AboutScreen` SHALL preserve the home navigation shell and SHALL keep About content accessible under compact height constraints. Long content SHALL be scrollable or otherwise bounded rather than causing a Flutter vertical overflow.

#### Scenario: Bottom navigation shell opens About route
- **WHEN** the user opens the About drawer destination from `HomeBottomNavShell`
- **THEN** `AboutScreen` SHALL render without a vertical overflow under the route's available body height
- **AND** invoking system back SHALL dismiss the About route or return to the shell primary destination while `HomeBottomNavShell` remains mounted

#### Scenario: Standalone About fallback uses configured home entry
- **WHEN** standalone `AboutScreen` is displayed with bottom navigation preferences and system back is invoked
- **THEN** the route SHALL return through `HomeEntryScreen` or an equivalent configured home entry seam
- **AND** the About content layout SHALL NOT produce a Flutter bottom overflow before the fallback completes

#### Scenario: Settings About page keeps existing scroll seam
- **WHEN** `AboutUsScreen` is opened from settings
- **THEN** it SHALL continue to use `SettingsPage` or an equivalent settings semantic page seam for scrolling and page chrome
- **AND** the shell-launched About overflow fix SHALL NOT introduce nested scrolling into `AboutUsScreen`

