# macos-settings-window Specification

## Purpose
TBD - created by archiving change fix-macos-settings-window. Update Purpose after archive.
## Requirements
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

#### Scenario: Settings sub-window visibility is queried on macOS
- **WHEN** the main window queries a macOS settings sub-window for visibility or asks it to focus
- **THEN** the settings sub-window SHALL NOT call `window_manager` APIs that require the plugin's `mainWindow`
- **AND** the macOS Runner SHALL NOT register `WindowManagerPlugin` into the settings sub-window Flutter engine

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

### Requirement: Desktop settings window targets SHALL support pane-local nested destinations
桌面设置窗口 target routing SHALL support both top-level settings panes and pane-local nested settings pages, so macOS settings-like menu commands can land in the same settings shell used by in-window navigation.

#### Scenario: Nested settings target is requested
- **WHEN** the app requests a nested settings target such as templates, location, image bed, image compression, memo toolbar, or desktop shortcuts
- **THEN** the settings window SHALL open or focus
- **AND** it SHALL select the owning pane
- **AND** it SHALL navigate inside that pane to the requested settings page

#### Scenario: Existing nested navigation is reset for a new target
- **GIVEN** the settings window is already open on one pane or nested settings page
- **WHEN** a different settings target is requested
- **THEN** the settings window SHALL switch to the requested owning pane
- **AND** the pane navigator SHALL show the requested target rather than preserving an unrelated previous nested route

#### Scenario: Targeted settings window preserves fallback semantics
- **WHEN** a pane or nested target cannot be routed after the settings window request
- **THEN** the open operation SHALL report a non-opened result or otherwise allow the caller to show fallback
- **AND** the app SHALL NOT silently focus a wrong settings pane

### Requirement: Settings window target routing SHALL be documented and guarded
Settings window target routing SHALL be documented through implementation notes, tests, or guardrails so future settings-like menu commands use the same seam.

#### Scenario: New settings-like command is added
- **WHEN** a new macOS menu command opens a settings page
- **THEN** it SHALL either use a desktop settings window target
- **OR** document why it remains a workflow route or task surface candidate

#### Scenario: Target routing seam remains boundary-safe
- **WHEN** additional settings window targets are added
- **THEN** lower layers SHALL pass stable target values only
- **AND** feature widget construction SHALL remain in settings UI composition
- **AND** the seam MUST NOT add commercial, subscription, entitlement, StoreKit, private overlay, or paid-feature branching logic

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

### Requirement: Desktop settings window SHALL support targeted pane routing
桌面设置窗口 SHALL support opening or focusing a specific settings destination through a stable target seam, without requiring menu handlers to construct feature pages directly.

#### Scenario: AI settings target is requested
- **WHEN** the app requests the desktop settings window with the AI settings target
- **THEN** the settings window SHALL open or focus
- **AND** the AI settings pane SHALL be selected
- **AND** the content SHALL render the same AI settings composition used by the desktop settings window pane list

#### Scenario: Existing settings window receives a target request
- **GIVEN** the desktop settings window is already open
- **WHEN** the app requests the AI settings target
- **THEN** the existing settings window SHALL be focused
- **AND** it SHALL switch to the AI settings pane without creating a duplicate settings window

#### Scenario: Target request fails
- **WHEN** the app requests a target settings window destination
- **AND** the settings window cannot be shown, focused, routed, or confirmed responsive
- **THEN** the open operation SHALL report a non-opened result
- **AND** the caller SHALL be able to show a visible fallback page

### Requirement: Settings window target seam SHALL remain layer-safe
Settings window target routing SHALL be expressed through stable target values or method payloads and SHALL NOT move feature widget construction into lower layers.

#### Scenario: Target seam is changed
- **WHEN** desktop settings window target routing is added or changed
- **THEN** `application` and `core` layers SHALL NOT import `features/settings` UI files for target resolution
- **AND** target-to-widget mapping SHALL remain owned by the settings window UI composition
- **AND** the seam MUST NOT include commercial, subscription, entitlement, StoreKit, private overlay, or paid-feature branching logic

### Requirement: Toolbar location settings entry SHALL reuse desktop settings target routing

当 desktop runtime 中的 memo compose 工具栏定位入口需要打开定位设置时，系统 SHALL 复用 `DesktopSettingsWindowTarget.location` target routing，使入口落到独立 settings window 的 `Components` owner surface 和定位页。

#### Scenario: Desktop toolbar prompt opens location target

- **WHEN** 用户在支持 desktop settings window 的 runtime 中从 compose toolbar 点击定位
- **AND** location provider requirements 校验失败
- **AND** 用户在提示弹窗中选择打开设置
- **THEN** 系统 SHALL open or focus the desktop settings window with `DesktopSettingsWindowTarget.location`
- **AND** the settings window SHALL switch to the `Components` pane
- **AND** the pane navigator SHALL show `LocationSettingsScreen`
- **AND** the route SHALL match the settings window target behavior used by other location settings entry points

#### Scenario: Desktop toolbar prompt keeps visible fallback

- **WHEN** toolbar location settings opener requests `DesktopSettingsWindowTarget.location`
- **AND** the desktop settings window is unsupported, cannot be opened, cannot be focused, cannot be routed, or reports failure
- **THEN** the caller SHALL open a visible fallback `LocationSettingsScreen` in the current main navigation context when that context remains mounted
- **AND** the failed settings window request SHALL NOT silently leave the user on the provider-not-ready prompt without a settings path

#### Scenario: Target routing boundary remains safe

- **WHEN** toolbar location settings routing is added or changed
- **THEN** target-to-widget mapping SHALL remain in `features/settings/desktop_settings_window_app.dart` or an equivalent settings UI composition point
- **AND** lower layers SHALL pass stable target values only
- **AND** implementation MUST NOT add new `application -> features/settings` or `core -> features/settings` imports to resolve `LocationSettingsScreen`
- **AND** no commercial/private behavior SHALL be introduced into public desktop settings routing

