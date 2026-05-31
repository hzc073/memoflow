## ADDED Requirements

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
