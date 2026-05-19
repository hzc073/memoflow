## ADDED Requirements

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
