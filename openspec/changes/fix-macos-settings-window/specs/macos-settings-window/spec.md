## ADDED Requirements

### Requirement: macOS settings entry points SHALL open a visible settings surface
The system SHALL ensure that every public macOS settings entry point opens or focuses a visible settings surface.

#### Scenario: Main toolbar settings button is clicked on macOS
- **WHEN** the user clicks the in-app settings button while running on macOS
- **THEN** the system SHALL open or focus the macOS settings window
- **AND** if the settings window cannot be opened, the system SHALL open a visible fallback settings page in the main window

#### Scenario: macOS menu settings command is selected
- **WHEN** the user selects Settings from the application menu or uses `Cmd+,`
- **THEN** the system SHALL open or focus the macOS settings window
- **AND** if the settings window cannot be opened, the system SHALL open a visible fallback settings page in the main window

#### Scenario: Window menu settings command is selected
- **WHEN** the user selects Open Settings Window from the macOS Window menu
- **THEN** the system SHALL open or focus the macOS settings window
- **AND** if the settings window cannot be opened, the system SHALL open a visible fallback settings page in the main window

### Requirement: Settings window open result SHALL be observable
The system SHALL distinguish between unsupported, successfully opened, and failed settings window attempts so callers do not treat an asynchronous attempt as a successful window display.

#### Scenario: Settings window is unsupported
- **WHEN** a settings entry point requests an independent settings window on a platform where it is not supported
- **THEN** the open operation SHALL report an unsupported result
- **AND** the caller SHALL be able to open a visible fallback settings page

#### Scenario: Settings window fails after creation starts
- **WHEN** a settings entry point starts opening a settings window but the window cannot be shown, focused, or confirmed responsive
- **THEN** the open operation SHALL report a failed result
- **AND** the caller SHALL be able to open a visible fallback settings page

#### Scenario: Settings window is responsive
- **WHEN** a settings window is created or reused and responds to its health check
- **THEN** the open operation SHALL report success
- **AND** the caller SHALL NOT open a duplicate fallback settings page

### Requirement: macOS settings window SHALL reuse existing settings composition
The macOS settings window SHALL reuse existing public settings screens and settings state rather than duplicating the feature page tree.

#### Scenario: macOS settings window content is built
- **WHEN** the macOS settings window renders settings content
- **THEN** it SHALL reuse `DesktopSettingsWindowApp`, existing settings screens, or an equivalent shared settings composition
- **AND** it MUST NOT introduce a complete `features_macos/`, `features_ios/`, or Apple-only duplicate settings page tree

### Requirement: macOS sub-window runtime SHALL register required plugins
The macOS Runner SHALL register the plugins required by the settings sub-window Flutter engine without destabilizing the main multi-window channel.

#### Scenario: Settings sub-window Flutter engine is created
- **WHEN** `desktop_multi_window` creates a macOS settings sub-window
- **THEN** the Runner SHALL register the plugins required by the settings window for that sub-window engine
- **AND** it SHALL avoid re-registering the main-window multi-window attachment in a way that breaks communication between windows

#### Scenario: Settings sub-window health check runs
- **WHEN** the main window sends the settings sub-window health-check method
- **THEN** the settings sub-window SHALL respond successfully after its runtime initialization completes

### Requirement: macOS settings window SHALL preserve public repository boundaries
The macOS settings window implementation SHALL remain public-shell safe and SHALL NOT include commercial App Store or entitlement behavior.

#### Scenario: Public macOS settings window code is added
- **WHEN** public macOS settings window, menu, shell, or fallback code is added or changed
- **THEN** it MUST NOT include StoreKit, subscription, buyout, entitlement, receipt, product ID, price, paywall, App Store Connect, signing secret, notarization, TestFlight, or private release automation logic

### Requirement: Settings window guardrails SHALL prevent boundary regressions
The system SHALL protect settings window behavior without introducing new architecture boundary regressions.

#### Scenario: Desktop settings window seam is changed
- **WHEN** desktop settings window open behavior is added or changed
- **THEN** lower layers SHALL NOT add new imports from `features/*` beyond existing explicitly owned UI composition points
- **AND** fallback page construction SHALL remain owned by UI entry points or composition roots

#### Scenario: Guardrail tests are executed
- **WHEN** architecture or platform guardrail tests are run
- **THEN** they SHALL fail if macOS settings window support introduces commercial logic or new unapproved reverse dependencies
