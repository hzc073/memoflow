## ADDED Requirements

### Requirement: Desktop settings window targets SHALL support owner-surface menu destinations

Desktop settings window target routing SHALL support macOS menu destinations whose pages already belong to an existing settings window owner surface. The target seam SHALL pass stable target values only; feature widget construction SHALL remain inside settings UI composition, and lower layers SHALL NOT import feature widgets to resolve targets.

#### Scenario: Components nested target is requested
- **WHEN** the app requests the WebDAV backup target from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the Components owner pane
- **AND** it SHALL navigate inside that pane to `WebDavSyncScreen`

#### Scenario: AI quick prompts target is requested
- **WHEN** the app requests the quick prompts target from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the AI owner pane
- **AND** it SHALL navigate inside that pane to `AiInsightPromptEditorScreen.custom()`
- **AND** the editor SHALL persist through the existing AI settings provider flow

#### Scenario: Import/export nested target is requested
- **WHEN** the app requests import data, export memos, or local network migration from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the Import/Export owner pane
- **AND** it SHALL navigate inside that pane to `ImportSourceScreen`, `ExportMemosScreen`, or `LocalNetworkMigrationScreen` as requested

#### Scenario: Feedback nested target is requested
- **WHEN** the app requests self repair or export diagnostics from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the Feedback owner pane
- **AND** it SHALL navigate inside that pane to `SelfRepairScreen` or `ExportLogsScreen` as requested

#### Scenario: Feedback pane target is requested
- **WHEN** the app requests the Feedback target from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the Feedback pane root
- **AND** it SHALL NOT push an unnecessary duplicate `FeedbackScreen` route above the Feedback pane root

#### Scenario: About nested target is requested
- **WHEN** the app requests Release Notes from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the About owner pane
- **AND** it SHALL navigate inside that pane to `ReleaseNotesScreen`

#### Scenario: Desktop shortcuts overview target is requested
- **WHEN** the app requests Desktop Shortcuts Overview from a macOS menu command
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL navigate to `DesktopShortcutsOverviewScreen`
- **AND** the screen SHALL receive current normalized desktop shortcut bindings from the settings window composition context

### Requirement: Settings window owner-surface routing SHALL preserve fallback and boundary safety

Settings window owner-surface routing SHALL keep unsupported or failed window requests observable by callers, SHALL preserve visible fallback behavior, and SHALL NOT introduce commercial/private behavior or new reverse dependencies.

#### Scenario: Owner-surface target request fails
- **WHEN** an owner-surface target cannot be opened, focused, or confirmed responsive
- **THEN** the open operation SHALL allow the caller to show its explicit fallback page
- **AND** the settings window SHALL NOT silently focus a wrong pane or claim success for an unrouted target

#### Scenario: Target routing remains boundary-safe
- **WHEN** owner-surface targets are added to the desktop settings window seam
- **THEN** `application/desktop` and `core` layers SHALL pass stable target values only
- **AND** target-to-widget mapping SHALL remain in `features/settings/desktop_settings_window_app.dart` or an equivalent settings UI composition point
- **AND** the implementation MUST NOT add subscription, billing, entitlement, receipt, paywall, StoreKit, private overlay, or paid-feature branching logic
