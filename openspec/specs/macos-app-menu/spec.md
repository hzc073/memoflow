# macos-app-menu Specification

## Purpose
TBD - created by archiving change customize-macos-app-menu. Update Purpose after archive.
## Requirements
### Requirement: macOS top-level menu SHALL use the approved MemoFlow structure
The macOS application SHALL expose the approved top-level menus `MemoFlow`, `Memo`, `Sync`, `AI`, `Tools`, `Window`, and `Help`.

#### Scenario: Menu bar is rendered
- **WHEN** the macOS app opens
- **THEN** the menu bar SHALL present the approved top-level menu structure

### Requirement: macOS menu labels SHALL support Simplified Chinese with English fallback
The macOS menu SHALL use localized labels from native macOS resources. Simplified Chinese SHALL be available, and English SHALL remain the fallback from `Base.lproj`.

#### Scenario: Chinese system locale is active
- **WHEN** the user runs the app with a Simplified Chinese macOS locale
- **THEN** the macOS menu labels SHALL appear in Chinese

#### Scenario: unsupported locale is active
- **WHEN** the user runs the app with a locale that has no menu translation
- **THEN** the macOS menu labels SHALL fall back to English

### Requirement: macOS menu SHALL preserve standard system actions
The macOS menu SHALL preserve standard application and window actions required by macOS, including About, Settings, Services, Hide, Quit, Minimize, Zoom, and Bring All to Front.

#### Scenario: User opens the application menu
- **WHEN** the application menu is displayed
- **THEN** the standard macOS actions SHALL remain available

### Requirement: macOS menu SHALL expose MemoFlow-specific workflows
The macOS menu SHALL expose MemoFlow-specific workflows for memo, sync, AI, tools, window, and help operations using the approved menu structure.

#### Scenario: User opens the Memo menu
- **WHEN** the user opens the `Memo` menu
- **THEN** the menu SHALL expose the approved memo workflows such as New Memo, Quick Input, Search Memos, Draft Box, Tags, and Recycle Bin

### Requirement: External help links SHALL open the approved public URLs
The Help menu SHALL provide external links to the approved help center and backend documentation URLs.

#### Scenario: User opens help documentation
- **WHEN** the user selects Help Center
- **THEN** the app SHALL open `https://memoflow.hzc073.com/help/`

#### Scenario: User opens backend documentation
- **WHEN** the user selects Memos Backend Docs
- **THEN** the app SHALL open `https://usememos.com/docs`

### Requirement: MemoFlow-specific macOS menu actions SHALL use a dedicated command seam
MemoFlow-specific menu actions SHALL be routed through a dedicated macOS command seam instead of importing feature screens directly from the native shell.

#### Scenario: User selects a MemoFlow-specific action
- **WHEN** the user selects a menu item such as New Memo, Sync Now, AI Settings, or Export
- **THEN** the action SHALL be dispatched through an application-owned command seam before reaching UI or navigation code

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

