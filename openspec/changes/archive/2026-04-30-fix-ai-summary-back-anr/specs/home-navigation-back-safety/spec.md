## ADDED Requirements

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
