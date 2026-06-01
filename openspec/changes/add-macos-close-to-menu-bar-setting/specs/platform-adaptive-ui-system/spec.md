## ADDED Requirements

### Requirement: Desktop settings SHALL expose platform-scoped lifecycle controls
Desktop settings SHALL present desktop lifecycle controls only for the current desktop platform and SHALL render those controls through settings semantic components. macOS close-to-menu-bar controls SHALL appear in a macOS-specific section when running as macOS desktop experience; Windows close-to-tray controls SHALL remain Windows-specific.

#### Scenario: macOS lifecycle setting is visible on macOS
- **WHEN** 用户在 macOS desktop experience 打开 Desktop settings
- **THEN** 页面 SHALL show a macOS-specific lifecycle section or row for close-to-menu-bar
- **AND** the row SHALL reflect the current macOS close-to-menu-bar preference value

#### Scenario: macOS lifecycle setting is hidden outside macOS
- **WHEN** 用户在 Windows、Linux、mobile、tablet 或 web experience 打开 Desktop settings
- **THEN** 页面 SHALL NOT show the macOS close-to-menu-bar row
- **AND** non-macOS experiences SHALL NOT be able to change the macOS-only setting from that page

#### Scenario: Windows close-to-tray remains Windows-scoped
- **WHEN** 用户在 Windows desktop experience 打开 Desktop settings
- **THEN** 页面 SHALL keep showing the Windows close-to-tray row
- **AND** Windows row SHALL NOT be renamed or rewired to control macOS close-to-menu-bar behavior

#### Scenario: Lifecycle rows use settings semantic components
- **WHEN** Desktop settings renders macOS or Windows lifecycle toggles
- **THEN** it SHALL use `SettingsSection`、`SettingsToggleRow` 或 an approved settings semantic seam
- **AND** it SHALL NOT introduce page-local card/toggle styling that bypasses the settings UI system
