## ADDED Requirements

### Requirement: Desktop settings entry SHALL use platform-neutral naming
系统 SHALL 将原 Windows 相关设置入口呈现为桌面端设置入口，并在所有桌面设置入口点使用一致的用户可见命名。

#### Scenario: Main settings shows desktop settings on supported desktop targets
- **GIVEN** the app is running on a desktop target where the desktop settings surface is available
- **WHEN** the user opens the main settings page
- **THEN** the settings list SHALL show a “桌面设置” / desktop settings entry
- **AND** the entry label SHALL NOT use “Windows related settings” or an equivalent Windows-only label

#### Scenario: Desktop settings window uses the same entry
- **GIVEN** the independent desktop settings window is rendering its pane list
- **WHEN** the desktop settings pane is available
- **THEN** the pane label SHALL match the main settings desktop settings entry
- **AND** selecting the pane SHALL render the same desktop settings surface or an equivalent shared composition

#### Scenario: Non-desktop targets do not get desktop-only settings
- **GIVEN** the app is running on a non-desktop target
- **WHEN** the user opens the settings page
- **THEN** the app SHALL NOT expose desktop-only settings rows as ordinary mobile settings

### Requirement: Desktop settings content SHALL be segmented by platform support
The desktop settings surface SHALL group shared desktop settings and platform-specific settings into explicit sections based on the current desktop platform and supported capability.

#### Scenario: Windows desktop sections are shown
- **GIVEN** the app is running on Windows desktop
- **WHEN** the user opens desktop settings
- **THEN** the page SHALL show shared desktop settings that apply to Windows
- **AND** the page SHALL show Windows-specific settings such as close-to-tray

#### Scenario: macOS desktop sections are shown
- **GIVEN** the app is running on macOS desktop
- **WHEN** the user opens desktop settings
- **THEN** the page SHALL show shared desktop settings that apply to macOS
- **AND** the page SHALL only show macOS-specific settings that are actually supported
- **AND** the page SHALL NOT show Windows-only settings such as close-to-tray

#### Scenario: Linux desktop remains explicitly unsupported or fallback-only
- **GIVEN** the app is running on Linux desktop
- **WHEN** the desktop settings entry is hidden or opened
- **THEN** the app SHALL NOT present Linux as a fully adapted desktop settings platform
- **AND** if a desktop settings surface is shown, it SHALL display a clear unsupported or fallback state for Linux-specific content

### Requirement: Shared desktop shortcut settings SHALL not be hidden behind Windows-only copy
Desktop shortcut configuration SHALL be treated as a shared desktop setting for every desktop platform where the shortcut feature is supported.

#### Scenario: Windows can open desktop shortcut settings
- **GIVEN** the app is running on Windows desktop
- **WHEN** the user opens desktop settings
- **THEN** the shared desktop section SHALL include a navigation row for desktop shortcut settings
- **AND** the row copy SHALL describe desktop shortcuts rather than Windows-only shortcuts

#### Scenario: macOS can open desktop shortcut settings
- **GIVEN** the app is running on macOS desktop
- **WHEN** the user opens desktop settings
- **THEN** the shared desktop section SHALL include a navigation row for desktop shortcut settings if the existing shortcut settings screen supports macOS bindings
- **AND** the row SHALL NOT require a Windows-only settings page gate

### Requirement: Windows-only lifecycle preferences SHALL remain Windows-scoped
Windows desktop lifecycle preferences SHALL remain visible and mutable only on Windows desktop.

#### Scenario: Windows close-to-tray remains configurable on Windows
- **GIVEN** the app is running on Windows desktop
- **WHEN** the user opens desktop settings
- **THEN** the Windows section SHALL include the close-window-minimize-to-tray preference
- **AND** toggling it SHALL continue to update the existing `windowsCloseToTray` preference owner

#### Scenario: Close-to-tray is hidden outside Windows
- **GIVEN** the app is running on macOS or Linux
- **WHEN** the user opens desktop settings
- **THEN** the page SHALL NOT show the Windows close-to-tray toggle
- **AND** the page SHALL NOT create a new non-Windows close-to-tray preference

### Requirement: Desktop settings page SHALL use shared settings UI seams
The desktop settings page SHALL use existing settings UI seams and guardrails instead of page-local visual implementations.

#### Scenario: Desktop settings page uses settings UI components
- **WHEN** the desktop settings page is implemented or changed
- **THEN** it SHALL use `SettingsPage`, `SettingsSection`, `SettingsNavigationRow`, `SettingsToggleRow`, or equivalent settings UI seams for layout and rows
- **AND** it SHALL NOT rely on a page-local `Scaffold`, private card/group row system, bare `Switch`, or direct `MemoFlowPalette` styling for standard settings rows

#### Scenario: Settings UI drift guardrail covers desktop settings
- **WHEN** settings architecture guardrails are executed
- **THEN** the migrated desktop settings page SHALL be covered as a migrated settings file
- **AND** the legacy allowlist SHALL NOT keep the migrated desktop settings page exempt from settings UI seam rules

### Requirement: Desktop settings SHALL preserve public and modular boundaries
Desktop settings work SHALL keep platform UI composition inside appropriate UI seams and SHALL NOT introduce commercial or lower-layer feature dependencies.

#### Scenario: No new lower-layer feature dependency is added
- **WHEN** desktop settings platform sections are implemented
- **THEN** `state`, `application`, and `core` layers SHALL NOT add new imports from `features/settings` or other `features/*` UI files
- **AND** platform section selection SHALL remain UI composition or platform-adapter-owned behavior

#### Scenario: Public settings shell stays commercial-free
- **WHEN** desktop settings entries, sections, localization, tests, or settings window code are added or changed
- **THEN** they MUST NOT include subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, buyout, private release automation, or `AccessDecision.source` business branching logic
