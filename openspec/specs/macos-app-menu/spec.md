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

### Requirement: macOS settings-like menu commands SHALL route to targeted settings destinations
macOS 菜单中明确属于设置的 MemoFlow-specific commands SHALL use targeted desktop settings window routing as their primary path, instead of directly pushing standalone settings pages in the main window.

#### Scenario: Settings-like menu command is selected
- **GIVEN** a macOS menu command has been classified as a settings target
- **WHEN** the user selects that command from the macOS menu
- **THEN** the command seam SHALL request the desktop settings window with the matching target destination
- **AND** when the request succeeds, the settings window SHALL show the matching pane or pane-local nested settings page
- **AND** the command SHALL NOT directly push the standalone settings page as its primary path

#### Scenario: Settings-like command falls back
- **GIVEN** a macOS menu command has been classified as a settings target
- **WHEN** the target settings window request is unsupported or fails
- **THEN** the command seam SHALL open the original visible fallback page in the main window

#### Scenario: Non-settings menu command remains a normal workflow
- **GIVEN** a macOS menu command is classified as a business page, tool page, import/export workflow, diagnostic workflow, or task surface candidate
- **WHEN** the user selects that command
- **THEN** the command MAY continue to use the existing workflow-specific route or task presentation
- **AND** the command SHALL NOT be forced into the settings window solely because its label contains a settings-adjacent word

### Requirement: macOS settings-like command migration SHALL be allowlist based
迁移到 settings window 的 macOS menu commands SHALL be selected through an explicit reviewed allowlist and documented scan result, not through automatic string matching.

#### Scenario: Command migration list is reviewed
- **WHEN** settings-like macOS menu command routing is implemented
- **THEN** the change SHALL include a reviewed list of migrated, deferred, and unchanged commands
- **AND** each deferred or unchanged settings-adjacent command SHALL include a reason

#### Scenario: Guardrail checks migrated commands
- **WHEN** architecture or menu guardrail tests are run
- **THEN** they SHALL fail if an allowlisted migrated settings-like command uses direct standalone page push as its primary path
- **AND** they MAY allow direct page construction only in explicit fallback code

### Requirement: macOS owner-surface menu commands SHALL route through settings window targets

macOS 菜单中已有 settings window owner surface 的 MemoFlow-specific commands SHALL use targeted desktop settings window routing as their primary path, instead of directly pushing standalone pages in the main window. Owner surface 指目标页面已经在 settings window 的某个 top-level pane 或 pane-local nested route 中有明确归属。

#### Scenario: Components-owned command opens WebDAV target
- **GIVEN** `macosMenuCommandWebDavBackup` has been classified as a settings-window owner-surface command
- **WHEN** the user selects WebDAV Backup from the macOS Sync menu
- **THEN** the command seam SHALL request the desktop settings window with the WebDAV backup target
- **AND** when the request succeeds, the settings window SHALL show the Components owner surface and navigate to `WebDavSyncScreen`
- **AND** the command SHALL NOT directly push `WebDavSyncScreen` in the main window as its primary path

#### Scenario: AI quick prompts command opens a persistent custom template editor
- **GIVEN** `macosMenuCommandQuickPrompts` has been classified as a settings-window owner-surface command
- **WHEN** the user selects Quick Prompts from the macOS AI menu
- **THEN** the command seam SHALL request the desktop settings window with the quick prompts target
- **AND** when the request succeeds, the settings window SHALL show the AI owner surface and navigate to `AiInsightPromptEditorScreen.custom()`
- **AND** the command SHALL NOT directly push legacy `QuickPromptEditorScreen` in the main window as its primary path
- **AND** the visible editor SHALL be able to persist a new custom AI insight template

#### Scenario: Import/export commands open import-export owner surface
- **GIVEN** import, export, and migration commands have been classified as settings-window owner-surface commands
- **WHEN** the user selects Import File, Import from Markdown, Import from Flomo, Import from Swashbuckler Diary, Export Memos, or MemoFlow Migration from the macOS Sync menu
- **THEN** the command seam SHALL request the desktop settings window with the matching import/export owner target
- **AND** when the request succeeds, the settings window SHALL show the Import/Export owner surface and navigate to the matching page when applicable
- **AND** the command SHALL NOT directly push `ImportSourceScreen`, `ExportMemosScreen`, or `LocalNetworkMigrationScreen` in the main window as its primary path

#### Scenario: Tools diagnostics commands open feedback owner surface
- **GIVEN** `macosMenuCommandSelfRepair` and `macosMenuCommandExportDiagnostics` have been classified as settings-window owner-surface commands
- **WHEN** the user selects Self Repair or Export Diagnostics from the macOS Tools menu
- **THEN** the command seam SHALL request the desktop settings window with the matching feedback owner target
- **AND** when the request succeeds, the settings window SHALL show the Feedback owner surface and navigate to `SelfRepairScreen` or `ExportLogsScreen`
- **AND** the command SHALL NOT directly push those pages in the main window as its primary path

#### Scenario: Feedback and release notes open their owner surfaces
- **GIVEN** `macosMenuCommandFeedback` and `macosMenuCommandReleaseNotes` have been classified as settings-window owner-surface commands
- **WHEN** the user selects Feedback or Release Notes from the macOS Help menu
- **THEN** Feedback SHALL request the desktop settings window Feedback pane
- **AND** Release Notes SHALL request the desktop settings window About owner surface and navigate to `ReleaseNotesScreen`
- **AND** neither command SHALL directly push its standalone page in the main window as its primary path

#### Scenario: Desktop shortcuts overview opens inside settings window
- **GIVEN** `macosMenuCommandDesktopShortcutsOverview` has been classified as a settings-window owner-surface command
- **WHEN** the user selects Desktop Shortcuts Overview from the macOS Tools menu
- **THEN** the command seam SHALL request the desktop settings window with the desktop shortcuts overview target
- **AND** when the request succeeds, the settings window SHALL show `DesktopShortcutsOverviewScreen` with current normalized shortcut bindings
- **AND** the command SHALL NOT directly push `DesktopShortcutsOverviewScreen` in the main window as its primary path

#### Scenario: Owner-surface command falls back visibly
- **GIVEN** a macOS owner-surface command requests a desktop settings window target
- **WHEN** the settings window request is unsupported or fails
- **THEN** the command seam SHALL open the original visible fallback page in the main window
- **AND** fallback SHALL preserve the previous page-level behavior for unsupported platforms or failed window creation

### Requirement: macOS non-owner commands SHALL remain outside this owner-surface migration

macOS menu commands that require home navigation state, desktop utility embedding, AI history result handling, or task-surface semantics SHALL NOT be forced into settings window owner-surface routing by this change.

#### Scenario: Home and AI report commands remain deferred
- **WHEN** the implementation scans `New Memo`, `Search Memos`, `Sync Queue`, or `AI Reports`
- **THEN** the change SHALL document them as deferred or out of scope
- **AND** the implementation SHALL NOT route them to settings window solely because they are visible from the macOS menu

