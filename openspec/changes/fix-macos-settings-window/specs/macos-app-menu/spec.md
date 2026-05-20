## ADDED Requirements

### Requirement: macOS settings menu commands SHALL open or fallback to a visible settings surface
The macOS application menu Settings command and Window menu Open Settings Window command SHALL route through the application-owned command seam and SHALL result in a visible settings surface.

#### Scenario: Application Settings command succeeds
- **WHEN** the user selects Settings from the macOS application menu or presses `Cmd+,`
- **THEN** the command seam SHALL request the macOS settings window
- **AND** the system SHALL open or focus the settings window when the window request succeeds

#### Scenario: Application Settings command falls back
- **WHEN** the user selects Settings from the macOS application menu or presses `Cmd+,`
- **AND** the macOS settings window request is unsupported or fails
- **THEN** the command seam SHALL open a visible fallback settings page in the main window

#### Scenario: Window menu command falls back
- **WHEN** the user selects Open Settings Window from the macOS Window menu
- **AND** the macOS settings window request is unsupported or fails
- **THEN** the command seam SHALL open a visible fallback settings page in the main window

### Requirement: macOS settings menu commands SHALL NOT be fire-and-forget
macOS settings menu commands SHALL await or otherwise observe the settings window open result before deciding whether fallback is required.

#### Scenario: Settings window request fails asynchronously
- **WHEN** the settings window request starts but later fails to show, focus, or respond
- **THEN** the macOS menu command handler SHALL detect the failed result
- **AND** it SHALL trigger visible fallback instead of silently completing
