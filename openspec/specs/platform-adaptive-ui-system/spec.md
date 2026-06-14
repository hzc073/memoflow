# platform-adaptive-ui-system Specification

## Purpose
TBD - created by archiving change platform-adaptive-ui-system. Update Purpose after archive.
## Requirements
### Requirement: Platform adaptive UI system SHALL centralize platform presentation strategy
The system SHALL provide a platform adaptive UI strategy that maps shared feature intent to platform-appropriate presentation without duplicating business state, full feature page trees, or migrated top-level desktop shell branches.

#### Scenario: Feature page uses adaptive presentation
- **WHEN** a migrated feature page needs scaffold, navigation, primary action, command bar, list section, dialog, picker, sheet, popover, master-detail, or form control behavior
- **THEN** the page SHALL use `platform/` adapters, desktop shell host boundaries, adaptive UI components, or feature-owned composition seams instead of scattering direct platform branches through the page

#### Scenario: Desktop destination page uses shell seam
- **WHEN** a migrated top-level desktop drawer destination needs sidebar, rail, overlay navigation, titlebar, command bar, actions, secondary pane, modal surface, or window chrome integration
- **THEN** the page SHALL use a unified desktop destination shell seam instead of locally branching between Windows `DesktopShellHost` and macOS `Scaffold` / `AppBar`

#### Scenario: Platform-specific page trees are not copied
- **WHEN** the app adapts UI for iPhone, iPadOS, macOS, Windows, Linux, Android, or web
- **THEN** the system MUST NOT create complete duplicate `features_ios/`, `features_ipad/`, `features_macos/`, `features_windows/`, or equivalent parallel feature trees

#### Scenario: Business state remains shared
- **WHEN** a platform-specific UI renders existing features
- **THEN** it SHALL reuse existing providers, repositories, models, destination registries, and feature-owned business state unless a separate OpenSpec change explicitly approves a new owner

### Requirement: Adaptive components SHALL express semantic UI intent
The system SHALL define platform UI differences through semantic adaptive components or equivalent seams rather than raw widget substitution alone.

#### Scenario: Primary actions are rendered
- **WHEN** a migrated flow presents a primary action such as create, save, continue, confirm, import, export, sign in, or get started
- **THEN** the action SHALL use an adaptive primary-action seam that can render full-width mobile actions, bounded desktop buttons, toolbar actions, or dialog actions according to platform context

#### Scenario: Transient UI is rendered
- **WHEN** a migrated flow presents confirmation, destructive choice, option picker, date/time picker, contextual actions, or secondary choices
- **THEN** the flow SHALL use adaptive dialog, picker, popover, menu, or sheet seams appropriate to iPhone, iPadOS, macOS, Windows, and existing mobile behavior

#### Scenario: List and form surfaces are rendered
- **WHEN** a migrated page displays settings rows, preference groups, configuration forms, item lists, or selectable rows
- **THEN** the page SHALL use adaptive list/form seams that can choose mobile touch rows, Apple grouped lists, desktop dense rows, side-by-side forms, or table-like surfaces where appropriate

### Requirement: Desktop UI SHALL avoid mobile-expanded control geometry
The system SHALL avoid rendering mobile-only full-width geometry as the default desktop presentation for high-perception flows.

#### Scenario: Desktop primary button
- **WHEN** a migrated page runs on macOS, Windows, or Linux in a regular desktop window
- **THEN** primary buttons SHALL be bounded, aligned, or placed in toolbar/dialog action areas rather than automatically stretching across the full content width

#### Scenario: Desktop content width
- **WHEN** a migrated page is single-column by nature and runs in a wide desktop window
- **THEN** the page SHALL use an appropriate max content width, split view, inspector, preview pane, or table layout instead of simply expanding mobile cards to the full window width

#### Scenario: Desktop transient choice
- **WHEN** a migrated desktop flow asks the user to choose or confirm an option
- **THEN** it SHALL prefer dialog, popover, menu, inspector, or command-bar patterns over mobile bottom sheets unless the design documents why a sheet is still appropriate

### Requirement: Platform shell strategies SHALL remain composable and platform-specific
The system SHALL preserve independent shell strategies for mobile, tablet, macOS, Windows, and Linux while sharing feature intent and navigation state through centralized shell or adaptive seams.

#### Scenario: Desktop shell host is used
- **WHEN** a migrated desktop feature needs sidebar, rail, toolbar, command bar, preview pane, modal surface, or window chrome integration
- **THEN** it SHALL compose through `DesktopShellHost` or an equivalent desktop shell boundary rather than importing a specific Windows or macOS shell implementation directly

#### Scenario: Top-level desktop destination remains platform-specific below the seam
- **WHEN** a top-level desktop destination is rendered through the unified shell seam
- **THEN** Windows SHALL remain free to render Windows-appropriate command bar and window controls
- **AND** macOS SHALL remain free to render macOS-appropriate toolbar, traffic-light safe area, and expanded-sidebar title suppression

#### Scenario: Apple platforms differ by form factor
- **WHEN** UI is adapted for Apple platforms
- **THEN** iPhone, iPadOS, and macOS SHALL be allowed to use different shell and interaction models while sharing Apple-appropriate visual semantics and existing business state

#### Scenario: Windows desktop remains distinct
- **WHEN** UI is adapted for Windows desktop
- **THEN** the system SHALL preserve Windows-appropriate command bar, sidebar/rail, preview pane, window controls, context menu, and keyboard interaction patterns instead of forcing macOS or mobile behavior

### Requirement: Migration progress SHALL be tracked by platform UI inventory
The system SHALL maintain a reviewable inventory of platform UI migration coverage for high-perception areas until the adaptive UI system is complete.

#### Scenario: Inventory is created
- **WHEN** implementation of this change begins
- **THEN** the change SHALL create or update a platform UI migration inventory covering app shell/navigation, onboarding/login, settings, memo list/detail/editor, collections, resources, review, AI, stats, dialogs, pickers, sheets/popovers, primary actions, list/form controls, route transitions, keyboard shortcuts, right-click/context menus, safe area/window chrome, dark mode, accessibility, and smoke checks

#### Scenario: Batch completion is recorded
- **WHEN** a migration batch is completed
- **THEN** `tasks.md`, a linked inventory, or a follow-up OpenSpec artifact SHALL record which platform UI areas are complete, in progress, blocked, and still pending

#### Scenario: Completion standard is evaluated
- **WHEN** this change is considered complete
- **THEN** all high-perception areas SHALL either use the adaptive UI system or have a documented reason why the existing platform behavior is acceptable

### Requirement: Adaptive UI work SHALL preserve modularity and public/private boundaries
The system SHALL preserve repository modularity, public shell constraints, and commercial boundaries while platform UI is adapted.

#### Scenario: Platform adapter dependency direction
- **WHEN** files under `platform/` adapters or shared adaptive UI seams are added or changed
- **THEN** they MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*` unless an explicit OpenSpec-approved adapter exception and guardrail are added

#### Scenario: Coupling hotspot is touched
- **WHEN** a migration batch touches known coupled areas such as `home`, `settings`, `memos`, `core`, `application/desktop`, or desktop shell code during `evolve_modularity`
- **THEN** the batch MUST include at least one touched-area improvement such as extracting platform behavior into a seam, reducing scattered platform branching, moving UI-specific logic out of lower layers, or tightening a guardrail

#### Scenario: Public shell stays commercial-free
- **WHEN** platform adaptive UI code is added to public shell, platform, home, settings, memo, onboarding, desktop, Runner, or shared UI files
- **THEN** it MUST NOT include subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, buyout, private release automation, or `AccessDecision.source` business branching logic

### Requirement: Settings UI SHALL use semantic settings components

The platform adaptive UI system SHALL provide a settings-owned semantic UI seam so settings screens express settings intent instead of directly owning colors, button styles, platform controls, and repeated card geometry.

#### Scenario: Settings page chrome is rendered

- **WHEN** a migrated settings page renders a title, leading action, body, background, safe area, or desktop width constraint
- **THEN** it SHALL use `SettingsPage`, `PlatformPage`, or an approved settings page seam
- **AND** page-local `Scaffold` and app bar construction SHALL NOT be introduced unless the page is explicitly allowlisted during migration

#### Scenario: Settings rows are rendered

- **WHEN** a migrated settings page renders a navigation row, value row, selectable row, toggle row, or destructive row
- **THEN** it SHALL use a settings semantic row such as `SettingsNavigationRow`, `SettingsValueRow`, `SettingsToggleRow`, or an equivalent seam
- **AND** platform-specific row, grouped-list, and switch behavior SHALL be delegated to shared settings/platform components

#### Scenario: Settings choice controls are rendered

- **WHEN** a migrated settings page renders chip-like choices, single-choice lists, multi-choice lists, segmented choices, dropdown-like choices, or picker-backed choices
- **THEN** it SHALL use a settings/platform semantic choice seam
- **AND** the page SHALL NOT directly embed Material-only choice widgets inside Apple mobile grouped-list content

#### Scenario: Settings actions are rendered

- **WHEN** a migrated settings page renders save, confirm, continue, cancel, reset, destructive, or secondary actions
- **THEN** it SHALL express the semantic action variant instead of hardcoding button foreground/background colors in the screen
- **AND** the action SHALL render through a platform-safe action seam that can choose Cupertino-safe, Material, or desktop-appropriate presentation

#### Scenario: Settings transient feedback is rendered

- **WHEN** a migrated settings page shows confirmation, destructive choice, option selection, validation feedback, success feedback, failure feedback, loading, or progress
- **THEN** it SHALL use platform/settings dialog, picker, feedback, loading, or progress seams
- **AND** Apple mobile settings pages SHALL NOT rely on accidental `Scaffold`, `Material`, or `ScaffoldMessenger` ancestors unless the seam explicitly owns that dependency

#### Scenario: Settings visual tokens are resolved

- **WHEN** a migrated settings screen needs background, section, card, row, divider, text, icon, active, disabled, primary, secondary, or danger styling
- **THEN** those values SHALL be resolved through the settings UI seam, `ThemeData`, `ColorScheme`, platform widgets, or approved design tokens
- **AND** the feature screen SHOULD NOT directly select raw palette colors except for genuinely page-specific preview/editing UI such as a color picker.

### Requirement: Settings pilot SHALL unify Preferences and Components
The first settings UI unification batch SHALL use `PreferencesSettingsScreen` and `ComponentsSettingsScreen` as sibling pilot pages for the settings UI seam.

#### Scenario: Preferences is migrated
- **WHEN** `PreferencesSettingsScreen` is migrated in this batch
- **THEN** it SHALL keep existing preference behavior while moving generic group, row, toggle, page background, and action presentation to the shared settings seam where applicable

#### Scenario: Components is migrated
- **WHEN** `ComponentsSettingsScreen` is migrated in this batch
- **THEN** it SHALL keep existing component toggle behavior while replacing page-local card/toggle styling with the shared settings seam

#### Scenario: Pilot pages are compared
- **WHEN** a user opens Settings -> Preferences and Settings -> Components on phone, tablet, macOS desktop, or Windows/Linux desktop contexts
- **THEN** both pages SHALL feel like siblings in the same settings system
- **AND** platform-appropriate differences SHALL come from the settings/platform seams rather than page-local style forks

### Requirement: Platform experience classification SHALL separate platform axes
The platform adaptive UI system SHALL define or expose a normalized platform experience classification that separates runtime platform from form factor, input model, window model, visual family, and navigation model.

#### Scenario: Apple platforms are classified
- **WHEN** the app runs on iPhone, iPad-width iOS, or macOS
- **THEN** the classification SHALL distinguish those experiences rather than treating all Apple platforms as one interaction model

#### Scenario: Desktop platforms are classified
- **WHEN** the app runs on macOS, Windows, or Linux
- **THEN** the classification SHALL allow shared desktop behavior while preserving platform-specific visual family and window chrome semantics

#### Scenario: Migrated UI asks semantic platform questions
- **WHEN** migrated settings or platform UI code chooses layout, row density, navigation model, or transient surface behavior
- **THEN** it SHOULD ask semantic experience questions such as form factor, input model, window model, or visual family instead of scattering direct `TargetPlatform` checks

#### Scenario: Platform classification remains layer-safe
- **WHEN** platform experience classification code is added or changed
- **THEN** it MUST remain in an approved platform/core seam and MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`

### Requirement: Settings UI migration SHALL be guardrailed
The settings UI unification SHALL include automated guardrails or reviewable allowlists so future settings changes do not reintroduce divergent local styling.

#### Scenario: Legacy settings files remain
- **WHEN** not all settings pages have been migrated
- **THEN** the guardrail MAY use an explicit allowlist for existing legacy files
- **AND** each future migration SHOULD remove migrated files from that allowlist

#### Scenario: New settings style drift is introduced
- **WHEN** a non-allowlisted migrated settings file introduces direct `MemoFlowPalette` styling, page-local `styleFrom`, bare `Switch`/`Switch.adaptive`, private `_ToggleCard`, or direct `Scaffold` where `SettingsPage` is expected
- **THEN** architecture verification SHALL fail or require an explicit documented exception

### Requirement: Platform adaptive UI SHALL choose task surfaces by platform and flow type

平台适配 UI SHALL choose presentation based on both platform and flow type. Task-like flows may use desktop dialogs or panels on macOS, Windows, and Linux, while phone and tablet layouts may keep full-page routes, bottom sheets, or platform-appropriate navigation.

#### Scenario: Task-like flow runs on desktop
- **WHEN** a migrated create, edit, configure, import, reorder, or manage-items flow runs on macOS, Windows, or Linux
- **THEN** the adaptive UI layer SHALL be able to present it as a bounded desktop task surface
- **AND** the feature SHALL NOT need separate Windows-only and macOS-only page trees for the same task content

#### Scenario: Same task-like flow runs on mobile
- **WHEN** the same migrated task-like flow runs on iOS, Android, or narrow mobile layouts
- **THEN** it SHALL keep platform-appropriate mobile presentation such as a page route or sheet
- **AND** desktop task-surface constraints SHALL NOT introduce extra desktop titlebar spacing into mobile layouts

#### Scenario: Feature content stays shared
- **WHEN** a task-like flow receives platform-specific presentation
- **THEN** validation, providers, repositories, models, and task business state SHALL remain shared
- **AND** platform differences SHALL be expressed through adaptive UI seams or feature-owned composition boundaries

### Requirement: Desktop transient, search, and compose surfaces SHALL use semantic adaptive intent

Desktop transient UI, search, and compose presentation SHALL be selected from semantic intent through adaptive or desktop kernel seams. Feature pages SHALL not create independent Windows/macOS presentation branches for the same desktop task.

#### Scenario: Desktop modal or transient task is presented
- **WHEN** a desktop feature presents an editor, confirmation, utility view, inspector, picker, popover, dialog, sheet, or modal task surface
- **THEN** it SHALL express the semantic task and required behavior through a desktop surface policy, adaptive UI seam, or approved shell slot
- **AND** Windows/macOS renderers SHALL choose platform-appropriate visuals below that seam

#### Scenario: Desktop search is presented
- **WHEN** a desktop feature exposes search from keyboard shortcut, command bar, toolbar, titlebar, or page action
- **THEN** it SHALL express search intent through a shared search presentation seam or feature-specific semantic model
- **AND** it SHALL NOT encode the shared search state machine as a Windows-only header special case unless an explicit platform exception is documented

#### Scenario: Desktop compose is presented
- **WHEN** a desktop feature opens text compose, voice compose result, edit compose, or inline compose
- **THEN** it SHALL resolve the presentation through desktop compose policy, adaptive UI seam, or approved feature-owned semantic presenter
- **AND** Windows/macOS differences SHALL be limited to renderer/chrome choices rather than separate business or route-delegate state machines

#### Scenario: Adaptive UI migration preserves public boundary
- **WHEN** desktop adaptive surface, search, or compose code is added to public shell files
- **THEN** it SHALL NOT introduce subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, buyout, private release automation, or `AccessDecision.source` business branching logic

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

### Requirement: Shortcuts and toolbar settings surfaces SHALL use semantic settings UI seams

`ShortcutsSettingsScreen`, `ShortcutEditorScreen`, and `MemoToolbarSettingsScreen` SHALL render page chrome, grouped list/form/editor surfaces, status rows, action rows, manual inputs, high-level editor sections, toolbar toolbox/preview groups, explanatory notes, and empty/error states through `SettingsPage`, `SettingsSection`, settings row/action/input components, `settingsPageTokens`, platform controls, theme colors, or equivalent settings/platform seams instead of local scaffold/card/palette/button implementations.

#### Scenario: App shortcuts list is migrated

- **WHEN** `ShortcutsSettingsScreen` renders page chrome, add action, shortcuts list, shortcut rows, empty state, loading state, error state, retry action, edit action, delete action, or delete confirmation entry point
- **THEN** those visible settings surfaces SHALL use settings semantic seams or equivalent settings/platform seams
- **AND** haptics, local/server shortcut selection, provider invalidation, save/delete calls, toast/snackbar behavior, delete confirmation labels, unsupported-server error formatting, shortcut labels, and route to `ShortcutEditorScreen` SHALL be preserved
- **AND** the change SHALL NOT modify API route adapters, request/response models, shortcut data models, local shortcut repository semantics, or server compatibility logic

#### Scenario: Shortcut editor is migrated

- **WHEN** `ShortcutEditorScreen` renders title/name input, match mode, unsupported-filter warning, tag condition, created date condition, visibility condition, tag picker entry, date range picker entry, clear actions, cancel/done actions, embedded desktop task surface content, or validation messages
- **THEN** page chrome and grouped visible editor surfaces SHALL use settings semantic seams or equivalent settings/platform seams
- **AND** desktop secondary task surface selection, filter parsing/building, tag selection, date range selection, visibility selection, validation, `ShortcutEditorResult`, and existing labels SHALL be preserved
- **AND** the change SHALL NOT modify shortcut filter grammar, memo search semantics, tag providers, or desktop secondary task surface policy

#### Scenario: Memo toolbar settings editor is migrated

- **WHEN** `MemoToolbarSettingsScreen` renders page chrome, restore defaults, toolbox section, create custom button action, toolbox items, toolbar preview section, clear action, drag/drop targets, add/remove actions, empty toolbox state, custom button dialog entry, or explanatory copy
- **THEN** page chrome and high-level grouped surfaces SHALL use settings semantic seams or equivalent settings/platform seams
- **AND** drag/drop behavior, toolbar preference mutations, reset/clear behavior, custom button dialog, icon catalog behavior, desktop preference notification, existing `ValueKey`s, and labels SHALL be preserved
- **AND** the change SHALL NOT modify `MemoToolbarPreferences`, compose toolbar runtime behavior, desktop quick-input channel semantics, or custom icon catalog data

#### Scenario: Drift guardrail reflects completed shortcuts and toolbar migration

- **WHEN** this batch is implemented
- **THEN** `shortcuts_settings_screen.dart`, `shortcut_editor_screen.dart`, and `memo_toolbar_settings_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`
- **AND** `desktop_shortcuts_overview_screen.dart` and `desktop_settings_window_app.dart` SHALL remain deferred unless a separate OpenSpec change approves their migration

### Requirement: Local network migration settings surfaces SHALL use semantic settings UI seams

`LocalNetworkMigrationScreen`, `MemoFlowBridgeScreen`, and MemoFlow migration sender/receiver/result settings surfaces SHALL render page chrome, grouped status blocks, navigation entries, toggles, action rows, manual inputs, receiver QR/proposal sections, progress/status sections, result summaries, and explanatory notes through `SettingsPage`, `SettingsSection`, settings row/action/input components, `settingsPageTokens`, platform controls, theme colors, or equivalent settings/platform seams instead of local scaffold/card/palette/switch implementations.

#### Scenario: Local network migration hub and role screens are migrated

- **WHEN** `LocalNetworkMigrationScreen` renders MemoFlow Migration and Connect Obsidian entries
- **THEN** page chrome and target rows SHALL use settings semantic seams
- **AND** haptic behavior, localized labels, asset icons, route targets, and navigation to `MemoFlowMigrationRoleScreen` and `MemoFlowBridgeScreen` SHALL be preserved
- **WHEN** `MemoFlowMigrationRoleScreen` renders sender and receiver role choices
- **THEN** role choices SHALL use settings semantic rows or equivalent settings seams
- **AND** local library gating, haptics, localized labels, foreground notice, and navigation to sender/receiver screens SHALL be preserved

#### Scenario: MemoFlow bridge settings surface is migrated

- **WHEN** `MemoFlowBridgeScreen` renders pairing status, local mode notice, scan pair action, mDNS discovery action, manual host/port/pair-code inputs, confirm pair action, health check action, enable bridge toggle, clear pairing action, status message, or discovery results
- **THEN** those visible settings surfaces SHALL use settings semantic sections, rows, inputs, toggles, actions, theme/platform controls, or equivalent settings seams
- **AND** pairing, mDNS discovery, health check, QR scanner route, provider writes, toasts, validation labels, status messages, and enabled state SHALL be preserved
- **AND** the change SHALL NOT modify bridge network endpoints, payload parsing, Dio behavior, mDNS behavior, QR scanner behavior, device-name resolution, or bridge settings model/provider semantics

#### Scenario: MemoFlow migration sender, send-method, receiver, and result screens are migrated

- **WHEN** sender, send-method, receiver, or result screens render content selection, settings selection, package ready summary, scan/manual connect actions, auto-connect status, receiver QR/session details, proposal review, receive mode, sensitive config confirmation, progress, error/completion/result sections, bottom cancel action, or result summary rows
- **THEN** page chrome and grouped visible surfaces SHALL use settings semantic seams or equivalent settings/platform seams
- **AND** package build, sender/receiver controller calls, auto-connect, manual connect dialog validation, QR payload handling, proposal accept/reject, receive mode selection, sensitive config selection, progress calculation, result navigation, localized labels, and foreground notices SHALL be preserved
- **AND** the change SHALL NOT modify migration protocol, package format, config transfer, sender/receiver controllers, state models, local library persistence, database behavior, network payloads, API files, WebDAV behavior, AI settings, desktop routing, private hooks, or commercial logic

#### Scenario: Drift guardrail reflects completed local migration UI migration

- **WHEN** this batch is implemented
- **THEN** `local_network_migration_screen.dart`, `memoflow_bridge_screen.dart`, and in-scope `migration/memoflow_migration_*.dart` files SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Export memos page SHALL use semantic settings UI seams

`ExportMemosScreen` SHALL render page chrome, export option rows, include archived toggle, export format row, export action, last export path display, and explanatory note through `SettingsPage`, `SettingsSection`, settings row/action components, `settingsPageTokens`, theme colors, or equivalent settings/platform seams instead of local scaffold/card/button/switch implementations.

#### Scenario: Export memos settings page is migrated

- **WHEN** `ExportMemosScreen` renders title, date range row, include archived toggle, export format row, export action, last export path, copy path action, or explanatory note
- **THEN** page chrome and grouped settings surfaces SHALL use settings semantic seams
- **AND** `_export`, date range picker behavior, include archived state, haptics, toast/snackbar/dialog behavior, clipboard copy path behavior, zip/markdown/sidecar/attachment export behavior, existing labels, and route entry behavior SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, export data format, database queries, attachment fetching, SAF/path provider behavior, WebDAV behavior, local network migration behavior, private hooks, commercial logic, AI settings, desktop routing/window, shortcut editor, memo toolbar, or migration flows

#### Scenario: Import/export shared UI wrappers are removed or migrated

- **WHEN** `ExportMemosScreen` no longer uses `ImportExportCardGroup`, `ImportExportSelectRow`, or `ImportExportToggleRow`
- **THEN** `import_export_shared_widgets.dart` SHALL either be deleted after repository-wide reference verification
- **OR** it SHALL be migrated to settings/platform seams and tracked by the drift guardrail
- **AND** no unused legacy direct `MemoFlowPalette` or bare `Switch` wrapper SHALL remain in the settings UI legacy allowlist

#### Scenario: Drift guardrail reflects completed export memos migration

- **WHEN** this batch is implemented
- **THEN** `export_memos_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** `export_memos_screen.dart` SHALL be added to `migratedFiles`
- **AND** `import_export_shared_widgets.dart` SHALL be removed from `legacyAllowlist` if deleted, or added to `migratedFiles` if retained
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Legacy donation dialog SHALL stay removed from settings UI drift tracking

旧 `DonationDialog` SHALL be removed after the Support MemoFlow page replaces the legacy donation QR flow. `quick_qr_action.dart` SHALL not remain in the settings UI drift legacy allowlist when it does not render a settings page or local visual surface, and SHALL be tracked by the migrated scan so future drift is blocked.

#### Scenario: Legacy donation dialog is removed

- **WHEN** settings support surfaces are reviewed
- **THEN** `memos_flutter_app/lib/features/settings/donation_dialog.dart` SHALL NOT exist as an active runtime surface
- **AND** `assets/images/donation_qr.png` SHALL NOT be declared as an active app asset
- **AND** public support pages MAY render a generated QR code from an approved support URL
- **AND** public support pages SHALL NOT render long-press QR save flows or the legacy bundled donation QR asset
- **AND** the change SHALL NOT introduce subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, private overlay, or `AccessDecision.source` business branching

#### Scenario: Drift guardrail reflects donation dialog removal and quick QR cleanup

- **WHEN** this batch is implemented
- **THEN** `donation_dialog.dart` SHALL be removed from `legacyAllowlist`
- **AND** `donation_dialog.dart` SHALL NOT be required in `migratedFiles` after the file is deleted
- **AND** `quick_qr_action.dart` SHALL be removed from `legacyAllowlist`
- **AND** `quick_qr_action.dart` SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

#### Scenario: Quick QR behavior is preserved

- **WHEN** `classifyQuickQrPayload` receives a MemoFlow migration QR payload, a bridge pairing QR payload, an empty payload, or unsupported QR data
- **THEN** it SHALL preserve the existing target classification and rejection behavior
- **AND** the batch SHALL NOT modify bridge pairing, migration sender routing, QR scanner support detection, local network migration behavior, API files, request/response models, route adapters, or version compatibility logic

### Requirement: Local mode setup page SHALL use semantic settings UI seams

`LocalModeSetupScreen` SHALL render page chrome, bounded task content, subtitle text, storage info, repository name input, validation messaging, confirm action, and cancel action through `SettingsPage`, `SettingsSection`, settings row/action components, `settingsPageTokens`, theme colors, or equivalent settings/platform seams instead of local scaffold/card implementations.

#### Scenario: Local mode setup page is migrated

- **WHEN** `LocalModeSetupScreen` renders title, subtitle, storage info, repository name field, confirm action, cancel action, or validation message
- **THEN** page chrome and grouped settings surfaces SHALL use settings semantic seams
- **AND** `LocalModeSetupScreen.show`, `LocalModeSetupResult`, title/confirm/cancel/subtitle parameters, storage info visibility, trimmed-name submit behavior, empty-name snackbar, cancel pop behavior, and debug logging SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, local library persistence, database, file paths, sync, WebDAV behavior, local network migration behavior, private hooks, commercial logic, AI settings, desktop routing/window, shortcut editor, memo toolbar, quick QR, donation dialog, or import/export flows

#### Scenario: Drift guardrail reflects completed local mode setup migration

- **WHEN** this batch is implemented
- **THEN** `local_mode_setup_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** `local_mode_setup_screen.dart` SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Import/export settings hub SHALL use semantic settings UI seams

`ImportExportScreen` SHALL render page chrome, grouped hub categories, route rows, labels, values, and navigation affordances through `SettingsPage`, `SettingsSection`, settings row components, `settingsPageTokens`, theme colors, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Import/export hub is migrated

- **WHEN** `ImportExportScreen` renders Export, Import file, or Local Network Migration entries
- **THEN** page chrome and grouped settings surfaces SHALL use settings semantic seams
- **AND** haptic behavior, `showBackButton`, `buildPlatformPageRoute` navigation, target screens, labels, and route values SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, `ExportMemosScreen`, `ImportSourceScreen`, `LocalNetworkMigrationScreen`, shared import/export widgets, import/export file logic, local migration behavior, WebDAV behavior, private hooks, commercial logic, AI settings, desktop routing/window, shortcut editor, memo toolbar, quick QR, or donation dialog

#### Scenario: Drift guardrail reflects completed import/export hub migration

- **WHEN** this batch is implemented
- **THEN** `import_export_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** `import_export_screen.dart` SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Simple utility settings surfaces SHALL use semantic settings UI seams

`TemplateSettingsScreen` and `WidgetsScreen` SHALL render page chrome, grouped controls, template rows, widget preview actions, helper notes, and settings navigation affordances through `SettingsPage`, `SettingsSection`, settings row/action components, `settingsPageTokens`, theme colors, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Template settings page is migrated

- **WHEN** `TemplateSettingsScreen` renders template enablement, template list rows, empty template state, variable settings entry, variable docs entry, edit/delete actions, or helper text
- **THEN** page chrome and grouped settings surfaces SHALL use settings semantic seams
- **AND** template add/edit/delete behavior, delete confirmation, variable settings dialog, variable docs dialog, provider calls, sync requests triggered by the provider, UID handling, and localized text SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, template repository/model/provider behavior, WebDAV sync behavior, home widget service behavior, private hooks, commercial logic, AI settings, desktop routing/window, import/export, migration, shortcut editor, memo toolbar, quick QR, or donation dialog

#### Scenario: Widgets settings page is migrated

- **WHEN** `WidgetsScreen` renders home widget preview groups, add actions, unsupported-target toast behavior, supported Android pin request behavior, or version footer
- **THEN** page chrome, grouped surfaces, action controls, and footer styling SHALL use settings semantic seams, theme colors, or platform components
- **AND** preview contents, `HomeWidgetService.requestPinWidget` invocation, Android support gate, toast messages, package version lookup, and `showBackButton` behavior SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, `HomeWidgetService`, platform channel implementation, package info plugin seam, private hooks, commercial logic, AI settings, desktop routing/window, import/export, migration, shortcut editor, memo toolbar, quick QR, or donation dialog

#### Scenario: Drift guardrail reflects completed simple utility migration

- **WHEN** this batch is implemented
- **THEN** `template_settings_screen.dart` and `widgets_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** both files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Utility settings pages SHALL use semantic settings UI seams

`ExportLogsScreen` and `SelfRepairScreen` SHALL render page chrome, grouped controls, utility rows, toggles, action rows, notes, and state surfaces through `SettingsPage`, `SettingsSection`, settings row components, `settingsPageTokens`, theme colors, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Export logs page is migrated

- **WHEN** `ExportLogsScreen` renders include toggles, network logging toggle, note input, generate/clear actions, last exported path, copy path action, or helper notes
- **THEN** page chrome and grouped surfaces SHALL use settings semantic seams
- **AND** report generation, export path resolution, log bundle export, log clearing, device preference writes, haptic behavior, clipboard copy, toast/snackbar behavior, busy/clearing state, and local include/note state SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, log providers/stores, database repair logic, WebDAV behavior, path provider behavior, private hooks, commercial logic, AI settings, desktop routing/window, import/export, migration, shortcut editor, memo toolbar, quick QR, or donation dialog

#### Scenario: Self repair page is migrated

- **WHEN** `SelfRepairScreen` renders repair actions, subtitles, running/disabled state, confirmation dialog trigger, success/error messaging, or local-only note
- **THEN** page chrome and grouped surfaces SHALL use settings semantic seams
- **AND** confirmation dialogs, `selfRepairMutationServiceProvider` calls, running state, haptic behavior, snackbar behavior, and repair success/error messages SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, self repair mutation service, database repair logic, log providers/stores, WebDAV behavior, private hooks, commercial logic, AI settings, desktop routing/window, import/export, migration, shortcut editor, memo toolbar, quick QR, or donation dialog

#### Scenario: Drift guardrail reflects completed utility migration

- **WHEN** this batch is implemented
- **THEN** `export_logs_screen.dart` and `self_repair_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** both files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Integrations settings pages SHALL use semantic settings UI seams

`ApiPluginsScreen` and `WebhooksSettingsScreen` SHALL render page chrome, grouped controls, integration rows, token/webhook state surfaces, and helper text through `SettingsPage`, `SettingsSection`, settings row components, `settingsPageTokens`, theme colors, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: API plugins page is migrated

- **WHEN** `ApiPluginsScreen` renders token creation controls, expiration selection, loading state, error state, empty state, existing token rows, copy action, or helper text
- **THEN** page chrome and grouped surfaces SHALL use settings semantic seams
- **AND** token creation, one-time token display, clipboard copy, repository save/read, refresh behavior, form validation, current-account guard, toast/snackbar behavior, and token masking SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, token data models, repositories, provider behavior, private hooks, commercial logic, AI settings, desktop routing/window, import/export, migration, shortcut editor, or memo toolbar

#### Scenario: Webhooks page is migrated

- **WHEN** `WebhooksSettingsScreen` renders webhook rows, empty state, loading state, error state, add action, edit action, delete action, or retry action
- **THEN** page chrome and grouped surfaces SHALL use settings semantic seams
- **AND** webhook add/edit/delete API calls, `userWebhooksProvider` invalidation, dialog behavior, haptic behavior, toast/snackbar behavior, and unsupported-server load error messaging SHALL be preserved
- **AND** the change SHALL NOT edit API files, request/response models, route adapters, version compatibility logic, webhook data models, repositories, provider behavior, private hooks, commercial logic, AI settings, desktop routing/window, import/export, migration, shortcut editor, or memo toolbar

#### Scenario: Drift guardrail reflects completed integrations migration

- **WHEN** this batch is implemented
- **THEN** `api_plugins_screen.dart` and `webhooks_settings_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** both files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Location settings page SHALL use semantic settings UI seams

`LocationSettingsScreen` SHALL render page chrome, grouped controls, location enabled toggle, provider selection, API key inputs, helper text, and precision controls through `SettingsPage`, `SettingsSection`, `SettingsToggleRow`, `SettingsMenuRow`, `SettingsInputRow`, `settingsPageTokens`, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Location page is migrated

- **WHEN** `LocationSettingsScreen` renders the location enabled control, provider picker, provider-specific API key fields, or precision selector
- **THEN** page chrome and grouped controls SHALL use settings semantic seams
- **AND** enabled toggle, provider selection, API key writes, precision writes, controller lifecycle, provider subscription, and `_dirty` behavior SHALL be preserved
- **AND** the change SHALL NOT edit API files, location data models, repositories, adapters, provider behavior, permission logic, geocoder behavior, private hooks, commercial logic, AI settings, desktop routing, import/export, or WebDAV config transfer

#### Scenario: Drift guardrail reflects completed location migration

- **WHEN** this batch is implemented
- **THEN** `location_settings_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** it SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Navigation customization settings pages SHALL use semantic settings UI seams

Navigation and home customization settings pages in this batch SHALL render page chrome, grouped rows, toggle rows, selectable rows, helper text, and preview surfaces through `SettingsPage`, `SettingsSection`, `SettingsToggleRow`, `SettingsNavigationRow`, `SettingsSelectableItemRow`, `settingsPageTokens`, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Navigation mode page is migrated

- **WHEN** `NavigationModeScreen` renders classic and bottom bar navigation mode choices
- **THEN** it SHALL use settings semantic page and row seams
- **AND** classic/bottom selection behavior, `bottomSelectKey`, `bottomSettingsKey`, and bottom settings detail navigation SHALL be preserved
- **AND** bottom settings SHALL remain unavailable until bottom bar mode is selected

#### Scenario: Bottom navigation detail page is migrated

- **WHEN** `BottomNavigationModeSettingsScreen` renders preview, slot rows, fixed center action, or destination picker dialog
- **THEN** page chrome and slot grouping SHALL use settings semantic seams
- **AND** preview MAY remain a page-local presentation helper if it uses settings/theme tokens
- **AND** destination availability filtering, duplicate destination disabling, center fixed action behavior, and provider writes SHALL be preserved

#### Scenario: Drawer customization page is migrated

- **WHEN** `CustomizeDrawerScreen` renders drawer visibility toggles
- **THEN** it SHALL use `SettingsToggleRow` or equivalent settings toggle seam
- **AND** each toggle SHALL preserve its existing `currentWorkspacePreferencesProvider` setter

#### Scenario: Home shortcuts customization page is migrated

- **WHEN** `CustomizeHomeShortcutsScreen` renders quick entry slots or picker dialog
- **THEN** page chrome and slot rows SHALL use settings semantic seams
- **AND** local-only / signed-in candidate filtering, used action disabled state, dialog selection, and provider writes SHALL be preserved

#### Scenario: Drift guardrail reflects completed navigation migration

- **WHEN** this batch is implemented
- **THEN** `navigation_mode_screen.dart`, `bottom_navigation_mode_settings_screen.dart`, `customize_drawer_screen.dart`, and `customize_home_shortcuts_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Reference settings pages SHALL use semantic settings UI seams

Reference and entry settings pages in this batch SHALL render page chrome, grouped rows, helper text, and placeholder messaging through `SettingsPage`, `SettingsSection`, `SettingsNavigationRow`, `SettingsInfoRow`, `settingsPageTokens`, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Laboratory page is migrated

- **WHEN** `LaboratoryScreen` renders experimental settings entry rows
- **THEN** it SHALL use settings semantic page and row seams
- **AND** it SHALL preserve existing route targets, `showBackButton` behavior, package version display, and app identity display
- **AND** it SHALL NOT introduce API file edits, commercial branching, WebDAV, AI, desktop routing, import/export, or shortcut editor scope

#### Scenario: User guide page is migrated

- **WHEN** `UserGuideScreen` renders guide rows, external docs entry, helper footer text, or info surfaces
- **THEN** page chrome and guide rows SHALL use settings semantic seams
- **AND** existing haptics, external URL launch, snackbar fallback, Windows adaptive surface, and bottom sheet behavior SHALL be preserved

#### Scenario: Placeholder page is migrated

- **WHEN** `SettingsPlaceholderScreen` renders a title and message from legacy string keys
- **THEN** it SHALL use settings semantic page/section seams
- **AND** dynamic i18n key lookup and route dismissal behavior SHALL be preserved

#### Scenario: Drift guardrail reflects completed reference migration

- **WHEN** this batch is implemented
- **THEN** `laboratory_screen.dart`, `user_guide_screen.dart`, and `placeholder_settings_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: WebDAV settings pages SHALL use semantic settings UI seams

WebDAV settings surfaces in `webdav_sync_screen.dart` SHALL render page chrome, grouped rows, toggles, navigation entries, input rows, action buttons, status/progress rows, warning/copy rows, and log entries through `SettingsPage`, `SettingsSection`, semantic settings rows/actions, or equivalent settings/platform seams instead of direct palette/local card/button/toggle implementations. `_WebDavConnectionScreen` SHALL also present connection settings with clear grouped hierarchy, user-facing copy, and theme-derived colors without changing WebDAV persistence or network behavior.

#### Scenario: WebDAV root page is migrated

- **WHEN** `WebDavSyncScreen` renders enable sync, connection entry, backup strategy entry, Vault security status entry, logs entry, backup/restore actions, progress state, or sync error copy
- **THEN** it SHALL use settings semantic page/section/row/action seams
- **AND** it SHALL preserve enable/disable writes, navigation targets, manual sync, backup now, restore backup, progress pause/resume, sync error presentation, and existing provider/service call paths

#### Scenario: WebDAV connection page is migrated

- **WHEN** `_WebDavConnectionScreen` renders server URL, username, password, auth mode, ignore TLS, root path, warning copy, or connection test action
- **THEN** it SHALL use settings semantic page/section/input/toggle/value/action seams
- **AND** it SHALL preserve controller binding, draft settings construction, validation hints, connection test behavior, toast/snackbar feedback, auth mode picker, TLS toggle, and root path normalization

#### Scenario: WebDAV connection page uses clear grouped hierarchy

- **WHEN** `_WebDavConnectionScreen` renders the WebDAV server connection form
- **THEN** it SHALL group visible controls under “基础设置”, “认证设置”, “高级设置”, and “安全” or their localized equivalents
- **AND** the page title SHALL remain “服务器连接” or its localized equivalent with the existing back navigation behavior
- **AND** section labels, helper copy, row values, dividers, backgrounds, and action colors SHALL come from existing theme/settings/platform seams rather than a new color system or new hard-coded hex values

#### Scenario: WebDAV basic fields remain editable and understandable

- **WHEN** `_WebDavConnectionScreen` renders server URL, username, and password fields
- **THEN** server URL SHALL show example guidance equivalent to `https://example.com/dav`
- **AND** server URL SHALL expose a visible text action equivalent to “测试” that reuses the existing connection test logic
- **AND** username SHALL show placeholder guidance equivalent to “请输入用户名”
- **AND** password SHALL show placeholder guidance equivalent to “请输入密码”
- **AND** password visibility toggle SHALL keep the existing show/hide state behavior and use theme or icon-theme colors

#### Scenario: WebDAV auth mode copy is user-facing

- **WHEN** `_WebDavConnectionScreen` displays `WebDavAuthMode.basic`
- **THEN** the visible row value SHALL be “基础认证” or its localized equivalent
- **AND** the stored enum value, picker selection, provider write path, and WebDAV auth behavior SHALL remain unchanged

#### Scenario: WebDAV advanced and security settings explain risk and purpose

- **WHEN** `_WebDavConnectionScreen` renders root path and TLS certificate handling settings
- **THEN** root path SHALL be grouped under advanced settings and SHALL include helper copy equivalent to “用于指定 WebDAV 同步目录”
- **AND** root path SHALL preserve the existing default value, controller binding, provider write path, and normalization behavior
- **AND** `ignoreTlsErrors` SHALL be displayed as “允许不安全证书” or its localized equivalent
- **AND** the security row SHALL include helper copy equivalent to “仅建议在可信内网或测试环境中开启”
- **AND** the toggle SHALL preserve the existing `ignoreTlsErrors` default, state binding, and save behavior

#### Scenario: WebDAV connection save action has no network side effects

- **WHEN** the user taps the bottom primary action labeled “保存设置” or its localized equivalent
- **THEN** the page SHALL complete saving/form-finalization behavior by reusing existing setting write and normalization paths
- **AND** it SHALL NOT call the connection test logic
- **AND** it SHALL NOT start WebDAV sync, WebDAV backup, restore, Vault setup, or any new network operation
- **AND** it SHALL NOT automatically change WebDAV enabled, backup enabled, or auto-sync allowed state

#### Scenario: WebDAV backup settings page is migrated

- **WHEN** `_WebDavBackupSettingsScreen` renders backup content, config scope, backup mode, backup password/Vault entry, schedule, retention, unavailable hints, backup error copy, or exit guard
- **THEN** it SHALL use settings semantic page/section/row/action seams
- **AND** it SHALL preserve backup config/content writes, full config encryption guard, encryption mode picker, password setup flow, schedule picker, retention writes, backup password missing exit guard, and backup error presentation

#### Scenario: WebDAV logs page is migrated

- **WHEN** `WebDavLogsScreen` renders loading, empty state, log entries, refresh action, or log detail dialog
- **THEN** it SHALL avoid direct palette/local card styling and use settings/theme/platform seams
- **AND** it SHALL preserve log store reads, refresh behavior, entry ordering, and detail dialog content

#### Scenario: Drift guardrail reflects completed WebDAV migration

- **WHEN** this batch is implemented
- **THEN** `webdav_sync_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** it SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Settings security pages SHALL use semantic settings UI seams

Security settings pages in this batch SHALL render page chrome, grouped rows, toggle rows, value/navigation rows, status rows, action controls, loading states, and explanatory copy through `SettingsPage`, `SettingsSection`, semantic settings rows/actions, or equivalent settings/platform seams instead of page-local scaffold/card/palette/switch implementations.

#### Scenario: Password lock page is migrated

- **WHEN** `PasswordLockScreen` renders app lock enablement, change password entry, auto-lock time entry, or explanatory copy
- **THEN** it SHALL use settings semantic page/section/row seams
- **AND** it SHALL preserve enable app lock, disable app lock, set password dialog, change password dialog, auto-lock picker, provider writes, and toast behavior
- **AND** it SHALL NOT edit WebDAV sync behavior, API files, private hooks, account/server pages, AI settings, desktop routing, or commercial logic

#### Scenario: Vault security status page is migrated

- **WHEN** `VaultSecurityStatusScreen` renders Vault enabled status, recovery code status, remote/local/export plaintext status, local plaintext cache toggle, cleanup actions, recovery code action, backup test action, or loading state
- **THEN** it SHALL use settings semantic page/section/row/action seams
- **AND** it SHALL preserve status loading, cleanup reminders, recovery code password verification, backup restore test mode selection, local plain cache toggle, clear plaintext actions, snackbars, toasts, dialogs, and existing provider/service call paths
- **AND** it SHALL NOT change WebDAV sync/backup/import/export behavior or provider ownership

#### Scenario: Drift guardrail reflects completed security migration

- **WHEN** this batch is implemented
- **THEN** `password_lock_screen.dart` and `vault_security_status_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Settings account/server pages SHALL use semantic settings UI seams

Account/server settings pages in this batch SHALL render page chrome, grouped rows, selectable account/local-library rows, server setting form sections, loading states, retry actions, and footer text through `SettingsPage`, `SettingsSection`, semantic settings rows/actions, or equivalent settings/platform seams instead of page-local scaffold/card/palette implementations.

#### Scenario: Account security page is migrated

- **WHEN** `AccountSecurityScreen` renders account summary, account actions, remote accounts, local libraries, or removal warning text
- **THEN** it SHALL use settings semantic page/section/row seams
- **AND** it SHALL preserve add account, add local library, user general settings navigation, server settings navigation, sign out/remove account, local library switch, local library scan, local library rename, local library remove, dialog, haptics, and snackbar behavior
- **AND** it SHALL NOT edit API files, private hooks, WebDAV sync behavior, AI settings, desktop routing, security pages, or commercial logic

#### Scenario: Server settings page is migrated

- **WHEN** `ServerSettingsScreen` renders memo content limit or attachment upload limit controls
- **THEN** it SHALL use settings semantic page/form/action seams
- **AND** it SHALL preserve refresh, loading, unavailable/read-only, empty-field hint, focus blur restore, local positive integer validation, save status message, and retry behavior
- **AND** it SHALL keep provider/API ownership in `serverSettingsProvider` and existing data layers without editing API contract files

#### Scenario: Drift guardrail reflects completed account/server migration

- **WHEN** this batch is implemented
- **THEN** `account_security_screen.dart` and `server_settings_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Settings support/general pages SHALL use semantic settings UI seams

Support/general settings pages in this batch SHALL render page chrome, grouped rows, row actions, footer text, loading states, and retry actions through `SettingsPage`, `SettingsSection`, `SettingsNavigationRow`, `SettingsValueRow`, `SettingsInfoRow`, `SettingsAction`, or equivalent settings/platform seams instead of local scaffold/card/palette implementations.

#### Scenario: Feedback page is migrated

- **WHEN** `FeedbackScreen` renders submit logs, self repair, or external issue-reporting entries
- **THEN** it SHALL use settings semantic page and row seams
- **AND** it SHALL preserve the existing nested route targets, external URL, haptics behavior, and error snackbar behavior
- **AND** it SHALL NOT introduce API file edits, commercial branching, WebDAV, AI, desktop routing, account security, or server settings scope

#### Scenario: About page is migrated

- **WHEN** `AboutUsScreen` renders app identity, version information, legal/help/release/contributor entries, or debug logo tap behavior
- **THEN** page chrome and row groups SHALL use settings semantic seams
- **AND** page-specific app logo/version presentation MAY remain in the page if it uses settings/theme tokens rather than direct `MemoFlowPalette` styling
- **AND** existing external links, release notes route, donor wall route, and debug tools route behavior SHALL be preserved

#### Scenario: User general settings page is migrated

- **WHEN** `UserGeneralSettingsScreen` renders locale and default memo visibility controls
- **THEN** it SHALL use settings semantic page, section, and value row seams
- **AND** locale/visibility picker, saving guard, provider invalidation, retry action, and existing provider/API call behavior SHALL be preserved
- **AND** server-wide controls SHALL remain absent from this page

#### Scenario: Drift guardrail reflects completed support/general migration

- **WHEN** this batch is implemented
- **THEN** `feedback_screen.dart`, `about_us_screen.dart`, and `user_general_settings_screen.dart` SHALL be removed from `legacyAllowlist`
- **AND** those files SHALL be added to `migratedFiles`
- **AND** non-allowlisted migrated files SHALL continue to fail architecture verification if they reintroduce direct `Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`

### Requirement: Settings migration batches SHALL be coordinated by a control change
Settings UI 后续迁移 SHALL 先通过总控 change 记录批次矩阵、子 change 边界、顺序、验证门禁和暂停条件，再开始对应页面的 runtime implementation。

#### Scenario: Batch matrix is prepared before child implementation
- **WHEN** settings UI 后续迁移进入新的页面批次
- **THEN** 总控 change SHALL 先记录该批次的目标页面、风险级别、预期子 change 名称、验证命令和是否允许自动继续
- **AND** 子 change SHALL NOT 开始 runtime implementation，直到其边界和门禁在 OpenSpec artifacts 中清楚记录

#### Scenario: Control change does not implement settings UI runtime code
- **WHEN** 总控 change 被 apply
- **THEN** implementation SHALL 只更新 OpenSpec 编排、规则、验证记录或验收清单
- **AND** it MUST NOT 修改 `memos_flutter_app/lib/features/settings` runtime page code

#### Scenario: Child scopes are explicit
- **WHEN** 创建 settings UI migration child change
- **THEN** child proposal/design/tasks SHALL 明确列出允许触碰的 settings pages、guardrails、focused tests 和 out-of-scope pages
- **AND** WebDAV、AI、desktop settings routing SHALL NOT 被隐式纳入普通视觉批次

### Requirement: Settings migration child changes SHALL apply sequentially with validation gates
Settings UI migration child changes SHALL 按总控规则中的顺序执行；只有当前批次完成并通过验证后，才允许自动进入下一批。

#### Scenario: Automatic continuation is gated
- **WHEN** 一个 child change 完成 implementation tasks
- **THEN** 自动继续下一批 SHALL require successful OpenSpec validation, relevant focused tests, `settings_ui_drift_guardrail_test.dart`, relevant architecture guardrails, and `flutter analyze` or a documented blocker
- **AND** 验证结果 SHALL 记录在当前 child change 或总控验收记录中

#### Scenario: Apply pauses on blockers
- **WHEN** implementation reveals unclear requirements, design conflict, API file edits, public/private boundary risk, commercial leakage risk, test failure, analyze failure, guardrail failure, or unapproved scope growth
- **THEN** the apply workflow MUST pause before starting another child change
- **AND** it SHALL report the blocker, affected scope, completed tasks, and options for resolving the issue

#### Scenario: Child changes do not overlap silently
- **WHEN** two child changes might touch the same settings page, shared settings seam, provider, route, or guardrail allowlist entry
- **THEN** the total-control rules SHALL define a deterministic order or require artifact updates before either child change is applied
- **AND** overlapping runtime edits MUST NOT proceed as independent parallel implementation

### Requirement: Settings migration acceptance SHALL support final unified review
Settings UI migration SHALL collect per-batch visible changes and verification results so the user can perform a final consolidated acceptance pass after ordered child changes complete.

#### Scenario: Visible changes are recorded per child change
- **WHEN** a settings UI migration child change completes
- **THEN** it SHALL record the pages changed, user-visible UI differences, preserved behaviors, verification commands, and any pages intentionally left on the legacy allowlist

#### Scenario: Final review checklist is produced
- **WHEN** all planned child changes in the current migration wave are complete or intentionally deferred
- **THEN** the total-control workflow SHALL produce a final checklist grouped by settings area, platform/form factor risk, verification result, and remaining follow-up work
- **AND** the checklist SHALL distinguish completed pages from deferred WebDAV, AI, desktop routing, or other active-change-dependent pages

#### Scenario: Guardrail state is reviewable
- **WHEN** a migrated page is moved from legacy settings styling to the settings semantic UI seam
- **THEN** `settings_ui_drift_guardrail_test.dart` SHALL reflect the page as migrated or document an explicit temporary exception
- **AND** remaining allowlist entries SHALL stay reviewable for the next migration batch

### Requirement: Settings follow-up migration SHALL unify high-perception settings surfaces
The platform adaptive UI system SHALL continue settings UI migration by moving the settings home surface and direct Components detail surfaces onto the settings semantic UI seam.

#### Scenario: Settings home is migrated
- **WHEN** `SettingsScreen` renders profile entry, shortcut entries, grouped settings entries, extension entries, version footer, page background, desktop width, or navigation rows
- **THEN** it SHALL use `SettingsPage`, `SettingsSection`, settings semantic entry widgets, `PlatformPage`, or an approved settings/home composition seam
- **AND** it SHALL NOT reintroduce independent page-local card, row, shadow, radius, palette, or app bar visual systems for reusable settings navigation UI

#### Scenario: Component detail pages are migrated
- **WHEN** `ImageBedSettingsScreen` or `ImageCompressionSettingsScreen` renders page chrome, settings sections, toggles, selectable rows, text input rows, numeric stepper rows, warning/info rows, or actions
- **THEN** those controls SHALL be expressed through settings semantic components or narrow settings-owned form seams
- **AND** platform-specific row density, grouped-list behavior, desktop width, switches, and action geometry SHALL be delegated to settings/platform seams

#### Scenario: Page roles remain distinct
- **WHEN** a migrated settings page is a settings home, feature management list, or feature detail configuration page
- **THEN** it SHALL keep its page role distinct while sharing settings semantic UI seams
- **AND** detail configuration pages SHALL NOT be forced into `SettingsFeatureModule` unless they are actually managing a list of feature modules

### Requirement: Settings follow-up migration SHALL preserve behavior and ownership
The settings UI follow-up migration SHALL change presentation ownership without changing setting semantics, provider ownership, persistence behavior, API behavior, or public/private boundaries.

#### Scenario: Settings home behavior is preserved
- **WHEN** `SettingsScreen` is migrated
- **THEN** existing navigation entries, desktop settings platform gate, private extension bundle entries, donation entry, drawer/close behavior, embedded presentation behavior, and version footer SHALL remain functional
- **AND** the page SHALL NOT add capability, subscription, entitlement, paywall, StoreKit, product ID, receipt, private overlay, or `AccessDecision.source` business branching

#### Scenario: Image bed behavior is preserved
- **WHEN** `ImageBedSettingsScreen` is migrated
- **THEN** existing image bed enabled state, provider selection, base URL normalization, credential inputs, retry settings, and save/update callbacks SHALL continue to use the existing `imageBedSettingsProvider` owner
- **AND** reusable visual behavior SHALL move to settings UI seams rather than into state, application, core, or data layers

#### Scenario: Image compression behavior is preserved
- **WHEN** `ImageCompressionSettingsScreen` is migrated
- **THEN** existing compression mode, output format, lossless, metadata, resize, quality, size-limit, skip, warning, and numeric adjustment behavior SHALL continue to use the existing `imageCompressionSettingsProvider` owner
- **AND** reusable visual behavior SHALL move to settings UI seams rather than into state, application, core, or data layers

### Requirement: Settings follow-up migration SHALL shrink legacy drift guardrails
The settings UI follow-up migration SHALL tighten automated drift protection for every settings file migrated in this batch.

#### Scenario: Migrated files leave the legacy allowlist
- **WHEN** `SettingsScreen`, `ImageBedSettingsScreen`, or `ImageCompressionSettingsScreen` has been migrated to settings semantic UI seams
- **THEN** `settings_ui_drift_guardrail_test.dart` SHALL remove that file from the legacy allowlist and include it in migrated coverage
- **AND** architecture verification SHALL fail if the migrated file reintroduces direct reusable `Scaffold`, bare `Switch` or `Switch.adaptive`, page-local `styleFrom`, private `_ToggleCard`, or direct `MemoFlowPalette` visual decisions beyond an explicit narrow exception

#### Scenario: Remaining settings pages are not silently claimed as migrated
- **WHEN** this batch completes
- **THEN** remaining legacy settings pages such as `WebDavSyncScreen`, `AiSettingsScreen`, `PasswordLockScreen`, and other allowlisted pages MAY remain in the legacy allowlist
- **AND** their remaining status SHALL be documented by tasks, guardrail comments, or follow-up OpenSpec planning rather than being treated as complete

### Requirement: Platform adaptive settings pages SHALL separate shared desktop intent from platform-specific rows
The platform adaptive UI system SHALL require migrated settings pages to express shared desktop intent and platform-specific rows through adaptive settings seams rather than Windows-only page trees or scattered platform branches.

#### Scenario: Migrated settings page contains shared and platform-specific desktop rows
- **WHEN** a migrated settings page contains settings that apply to multiple desktop platforms and settings that apply to only one desktop platform
- **THEN** the page SHALL present the shared settings through a shared desktop section
- **AND** the page SHALL present platform-specific settings through platform-specific sections or an equivalent capability-gated composition
- **AND** the page SHALL NOT name the entire settings surface after a single platform unless all rows are exclusive to that platform

#### Scenario: Desktop settings platform support is capability-gated
- **WHEN** a desktop settings row is rendered for Windows, macOS, or Linux
- **THEN** row visibility SHALL be based on the platform target and the row's supported capability
- **AND** unsupported platforms SHALL receive an explicit fallback or no entry rather than a misleading platform-specific control

#### Scenario: Linux desktop settings can remain hidden until supported
- **GIVEN** a migrated desktop settings entry is only validated for Windows and macOS
- **WHEN** the app runs on Linux desktop
- **THEN** the adaptive settings composition MAY hide that entry and related pane entirely
- **AND** it SHALL NOT show Linux-specific desktop controls unless their behavior is specified and tested

#### Scenario: Settings migration keeps adaptive UI seam ownership
- **WHEN** a settings page is migrated as part of platform adaptive UI work
- **THEN** scaffold, list/form row presentation, switch styling, desktop width, and platform visual behavior SHALL be provided by `settings_ui.dart`, `platform/` widgets, `DesktopShellHost`, or equivalent adaptive seams
- **AND** the migrated page SHALL NOT duplicate a complete platform-specific settings page tree

#### Scenario: Settings hotspot improvement is guarded during evolve_modularity
- **GIVEN** the architecture phase is `evolve_modularity`
- **WHEN** settings platform adaptive work touches a migrated settings page
- **THEN** the change SHALL include a touched-area improvement such as reducing page-local platform branching, moving standard row visuals into settings seams, or tightening a settings UI guardrail

### Requirement: Settings row surfaces SHALL use theme-mode tokens
设置页面中的 section、row、cell、value area、divider、border、hover、pressed、selected 和 disabled surface SHALL 根据当前 `Brightness.light` / `Brightness.dark` 从 settings-owned UI tokens、`ThemeData` 或 approved settings/platform seam 解析。设置页面 SHALL 使用这些 tokens 表达 `语言`、`字号`、`行高`、`字体`、`启动动作`、`主题色` 等设置项所在的背景和交互状态。

#### Scenario: Settings row background is centralized
- **WHEN** 设置页面渲染 navigation row、value row、toggle row、action row 或 equivalent settings cell
- **THEN** row/cell background、border、divider 和 interaction state SHALL 使用 settings-owned theme-mode tokens 或 approved settings/platform seam
- **AND** 页面 SHALL NOT 为普通设置行直接硬编码 page-local card/row background、border 或 divider 颜色

#### Scenario: Light and dark setting surfaces are consistent
- **WHEN** 同一个设置 section 和 row 分别在 `Brightness.light` 和 `Brightness.dark` 下渲染
- **THEN** section background、row background、divider、border、hover、pressed、selected 和 disabled 状态 SHALL 来自同一套按模式分支的 settings surface tokens
- **AND** 视觉差异 SHALL 来自 theme-mode token、semantic state 或 platform layout seam，而不是页面局部颜色分叉

#### Scenario: Material button colors remain customizable
- **WHEN** app 渲染 `FilledButton`、`ElevatedButton`、`OutlinedButton`、`TextButton` 或 `PlatformPrimaryAction`
- **THEN** 本 requirement SHALL NOT force those true button colors to a fixed settings row background
- **AND** 普通按钮 SHALL continue to resolve color from the existing app theme, selected theme color, custom theme color, semantic variant, or explicitly approved button seam

#### Scenario: Settings semantic exceptions keep their own visuals
- **WHEN** 设置 UI 渲染 destructive/error action、theme color swatch、custom color preview、status preview、editing preview 或 semantic warning state
- **THEN** 该 UI MAY 使用对应语义颜色或预览颜色
- **AND** settings row surface tokens SHALL NOT 覆盖这些语义/预览色

#### Scenario: System and media surfaces are excluded
- **WHEN** UI 属于媒体预览/播放 overlay、图片查看器控制、系统文件/图片选择器、平台原生 picker、系统窗口控制按钮或 OS-controlled surface
- **THEN** 该 surface MAY 使用上下文专属或系统原生视觉
- **AND** 它 MUST NOT 被 settings row surface 统一要求强制改写

#### Scenario: Settings surface drift is guardrailed
- **WHEN** 新增或修改的非 allowlisted migrated settings file 为普通设置 row/section/cell 引入 page-local background、border、divider、raw palette surface 或绕过 settings tokens 的局部 surface styling
- **THEN** architecture/style verification SHALL fail or require an explicit documented exception
- **AND** allowlist 条目 MUST 说明该 surface 属于 semantic danger/error、theme swatch、color preview、media overlay、system/native surface、window controls 或其他已批准例外

### Requirement: Mobile settings home SHALL present layered function hierarchy
手机端设置首页 SHALL 使用 settings-owned UI tokens 或 approved settings/platform seam 表达 profile card、quick shortcut tiles、grouped function sections 和 single-row section 的层级。该层级 SHALL 通过背景、圆角、轻阴影或暗色等价边界、分割线和间距区分功能入口，而不是通过 `settings_screen.dart` 中的 page-local color/shadow/radius 硬编码实现。

#### Scenario: Profile and shortcuts use home card hierarchy
- **WHEN** 手机端设置首页渲染用户 profile 入口和顶部 quick shortcut tiles
- **THEN** profile 入口 SHALL 使用比普通 row 更突出的 home card surface、圆角、间距和 light/dark mode 层级 token
- **AND** quick shortcut tiles SHALL 作为独立功能卡片渲染，彼此通过卡片背景、间距和边界直接区分
- **AND** 这些视觉值 SHALL 来自 settings-owned home hierarchy tokens 或 approved settings/platform seam

#### Scenario: Function rows remain grouped by section
- **WHEN** 手机端设置首页渲染使用指南、账号与安全、偏好设置、AI 设置、应用锁、实验室、功能组件、反馈、充电站、导入/导出、关于或 equivalent function entries
- **THEN** 普通功能入口 SHALL 默认使用 grouped card + row divider 模型表达分组关系
- **AND** 单行分组 MAY 使用 single-row card treatment 保持与其他功能分组一致的层级
- **AND** 每个普通 function row SHALL NOT 被强制拆成独立卡片，除非该入口属于明确的 shortcut tile 或 approved special entry

#### Scenario: Secondary settings pages are not forced into home card treatment
- **WHEN** 用户从设置首页进入二级或三级设置页面
- **THEN** 这些页面 SHALL 继续使用标准 `SettingsPage`、`SettingsSection`、settings row surface tokens 或 approved settings/platform seam
- **AND** 手机端设置首页的重层级卡片、快捷入口布局或 home-only shadow treatment SHALL NOT 自动套用到二级/三级表单页

#### Scenario: Desktop settings keeps dense presentation
- **WHEN** 设置首页运行在 macOS、Windows 或 Linux desktop experience
- **THEN** desktop presentation SHALL preserve bounded, dense, work-focused settings layout
- **AND** it SHALL NOT be forced to use mobile-only large-radius, heavy-shadow, or oversized shortcut-card geometry

#### Scenario: Home hierarchy preserves existing behavior and exceptions
- **WHEN** 设置首页渲染导航入口、private extension entries、头像、真正按钮、danger/error action、theme swatch、custom color preview、media overlay、native picker 或 window controls
- **THEN** 本 requirement SHALL preserve existing navigation, haptics, route targets, private extension ordering, avatar rendering, semantic exception visuals, and true button color customization
- **AND** home hierarchy tokens SHALL NOT override semantic danger/error colors, preview colors, media/native/system surfaces, or app-wide button theme behavior

#### Scenario: Mobile settings home hierarchy is guarded
- **WHEN** 新增或修改设置首页、settings UI seam 或 migrated settings files
- **THEN** verification SHALL cover mobile settings home hierarchy for profile card, shortcut tiles, grouped function sections, row dividers, and light/dark mode token use
- **AND** architecture/style guardrails SHALL fail or require a documented exception if ordinary settings home hierarchy introduces page-local background, border, divider, shadow, radius, or raw palette styling outside the approved settings seam

### Requirement: Adaptive form controls SHALL render safely inside platform page chrome
The platform adaptive UI system SHALL provide form-control seams that can render text input and related form controls inside platform page chrome without requiring feature pages to add local Material or Cupertino workarounds.

#### Scenario: Text input renders inside Apple mobile PlatformPage
- **WHEN** a migrated flow renders a text input through `PlatformTextField` inside an iPhone or iPadOS `PlatformPage`
- **THEN** the input SHALL render without requiring an implicit `Material` ancestor from the feature page
- **AND** the Apple mobile behavior SHALL be provided by `platform/` or an approved settings/platform seam

#### Scenario: Text input preserves non-Apple behavior
- **WHEN** the same `PlatformTextField` is rendered on Android, Windows, macOS, Linux, or web
- **THEN** the existing Material-compatible `TextField` behavior SHALL remain available
- **AND** the change MUST NOT force Apple mobile control geometry onto non-Apple targets

#### Scenario: Material-only fallback stays inside platform seam
- **WHEN** a compatibility fallback is needed for a Material-only form control during migration
- **THEN** that fallback MUST be implemented inside `platform/` or an approved adaptive seam
- **AND** feature pages MUST NOT wrap individual controls in page-local `Material` solely to satisfy Apple mobile rendering

### Requirement: Settings input rows SHALL express input intent through semantic seams
Settings pages SHALL render text input rows through settings-owned semantic components and shared platform form-control seams rather than directly branching between Material and Cupertino widgets in each screen.

#### Scenario: Grouped settings input renders on iPhone
- **WHEN** a settings or onboarding setup page renders `SettingsInputRow` inside an Apple mobile grouped list
- **THEN** the row SHALL delegate platform-specific text input behavior to `PlatformTextField` or an equivalent shared seam
- **AND** the row MUST render without Flutter framework errors caused by missing Material ancestors

#### Scenario: Settings input remains shared across feature screens
- **WHEN** settings pages such as local library setup, server settings, location settings, shortcut editor, or profile settings need editable text
- **THEN** they SHALL use `SettingsInputRow`, `PlatformTextField`, or an approved settings/platform seam
- **AND** they MUST NOT create separate iOS-only page trees for the same settings behavior

### Requirement: Validation feedback SHALL avoid page-local Material-only dependencies
Adaptive flows that can run inside Apple mobile `PlatformPage` content SHALL present lightweight validation feedback through platform-safe feedback surfaces instead of relying on page-local `ScaffoldMessenger` availability.

#### Scenario: Validation feedback runs without Scaffold
- **WHEN** an Apple mobile setup or settings flow validates user input inside a `CupertinoPageScaffold`
- **THEN** validation feedback SHALL be shown through `showTopToast`, a platform feedback seam, a platform dialog, or an equivalent overlay-safe surface
- **AND** the flow MUST NOT require the current page body to be wrapped in a `Scaffold`

#### Scenario: Lightweight validation stays lightweight
- **WHEN** the validation issue is a simple missing or invalid text value
- **THEN** the feedback SHOULD use a lightweight toast or equivalent non-blocking surface where project conventions allow
- **AND** it MUST NOT introduce new business state or persistence behavior

### Requirement: Setup subflows SHALL use platform route seams
Reusable setup subflows that render through `PlatformPage` SHALL use a platform route abstraction when pushed from migrated mobile, desktop, or Apple flows.

#### Scenario: Local setup route runs on Apple mobile
- **WHEN** a migrated flow opens local library setup on iPhone or iPadOS
- **THEN** it SHALL push the setup screen through `buildPlatformPageRoute` or an equivalent platform route seam
- **AND** the implementation MUST NOT require the caller to choose `CupertinoPageRoute` directly

#### Scenario: Existing route behavior remains available elsewhere
- **WHEN** the same setup subflow runs on Android, Windows, macOS, Linux, or web
- **THEN** the platform route seam SHALL preserve existing route behavior appropriate to that target
- **AND** the setup result and validation behavior SHALL remain shared

### Requirement: Adaptive input surface changes SHALL include focused guardrails
Changes to platform input controls, settings input rows, Apple mobile validation feedback, or setup route presentation SHALL include focused automated verification and boundary checks.

#### Scenario: Apple mobile input path is verified
- **WHEN** focused widget tests run for Apple mobile setup or settings input
- **THEN** they SHALL verify render without Flutter framework exceptions
- **AND** they SHALL verify editing, validation feedback, and successful submission where the flow supports those behaviors

#### Scenario: Platform adapter dependency direction is verified
- **WHEN** platform input or feedback adapters are added or changed
- **THEN** architecture tests or repo scans SHALL prevent new `platform -> features`, `platform -> state`, `platform -> application`, and `platform -> data` dependencies unless an explicit OpenSpec-approved exception exists

#### Scenario: Public shell boundary is verified
- **WHEN** platform/settings/onboarding input surface code is added or changed in the public repository
- **THEN** verification or review SHALL confirm it does not add subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, private overlay, or `AccessDecision.source` business branching logic

### Requirement: Adaptive UI system SHALL centralize effective typography decisions
The platform adaptive UI system SHALL provide a centralized policy or equivalent stable seam for resolving effective app typography across platforms. Feature screens SHALL NOT duplicate platform-specific typography decisions for font family, font availability, text scaling, or UI chrome line-height behavior.

#### Scenario: App theme resolves effective typography
- **WHEN** `MaterialApp` theme, `CupertinoTheme`, or app-level `MediaQuery` needs effective font family, font fallback, text scaler, or UI line-height behavior
- **THEN** the app SHALL resolve those values through the centralized typography policy or equivalent stable seam
- **AND** feature pages MUST NOT add local `TargetPlatform.iOS` or `Platform.isIOS` branches to repair the same app-wide typography behavior

#### Scenario: Typography policy remains stable-layer safe
- **WHEN** a centralized typography policy or helper is introduced or changed
- **THEN** it MUST NOT depend on `features/*`, `application/*`, or UI page implementation details
- **AND** it SHALL accept only stable inputs such as platform classification, app preference values, existing text scaler, and theme-relevant primitive values

#### Scenario: Composition root delegates decisions
- **WHEN** `app.dart` composes `ThemeData`, `CupertinoTheme`, or `MediaQuery`
- **THEN** it SHALL delegate platform-specific typography decisions to the centralized policy or equivalent seam
- **AND** `app.dart` SHALL remain primarily a composition root rather than accumulating page-specific typography rules

### Requirement: Adaptive UI system SHALL expose font-selection capability by platform
The platform adaptive UI system SHALL expose whether a platform can select system fonts and what effective font label should be shown, so settings surfaces do not infer capability from an empty font list alone.

#### Scenario: iOS reports no selectable system-font capability
- **WHEN** Preferences evaluates the font setting on iPhone or iPadOS
- **THEN** the adaptive UI system SHALL report that system-font selection is unavailable or system-default-only for that platform
- **AND** the settings surface SHALL render a non-misleading state without opening an empty font picker

#### Scenario: Desktop reports selectable system-font capability
- **WHEN** Preferences evaluates the font setting on Windows, macOS, Linux, or another platform with supported system font discovery
- **THEN** the adaptive UI system SHALL allow the existing system-font picker path to remain available
- **AND** the displayed label SHALL continue to reflect the selected font or system default

#### Scenario: Settings remains semantic
- **WHEN** Preferences renders the font setting row, disabled state, hidden state, or read-only label
- **THEN** it SHALL use settings semantic components or an approved settings/platform seam
- **AND** it MUST NOT create a separate iOS-only Preferences page tree

### Requirement: Adaptive settings rows SHALL map value metadata to platform-native slots
The platform adaptive UI system SHALL render settings row value text through platform-native metadata slots rather than treating all right-side content as an unconstrained trailing control. Value text such as selected enum labels, font labels, and mode labels SHALL remain bounded under Apple mobile Dynamic Type while Android and desktop Material rows keep their existing trailing presentation.

#### Scenario: iOS value text uses Cupertino additional info
- **WHEN** a settings value row renders on iPhone or iPadOS with a value label and a disclosure indicator
- **THEN** the value label SHALL be mapped to the Cupertino row additional-info slot or an equivalent platform metadata seam
- **AND** the disclosure indicator SHALL remain the trailing control
- **AND** the value label MUST NOT be rendered as an unconstrained trailing control that can inherit inconsistent typography

#### Scenario: iOS large text remains bounded
- **WHEN** Preferences renders on iPhone or iPadOS with a large system `MediaQuery.textScaler`
- **THEN** settings value labels SHALL remain constrained, ellipsized, or otherwise reflowed without overflowing row chrome
- **AND** the row SHALL preserve system text scaling rather than disabling Dynamic Type globally

#### Scenario: Material rows keep existing behavior
- **WHEN** a settings value row renders on Android, Windows, macOS, Linux, or web Material surfaces
- **THEN** the row SHALL keep the existing Material trailing presentation for value labels, chevrons, switches, and icons
- **AND** this Apple mobile typography fix MUST NOT introduce Android-specific visual or interaction regressions

### Requirement: Adaptive UI typography changes SHALL include focused verification
Changes to adaptive typography, text scaling, font-selection capability, or Apple mobile surface rules SHALL include focused automated verification.

#### Scenario: Effective iOS font behavior is verified
- **WHEN** typography policy tests run
- **THEN** they SHALL verify that iPhone and iPadOS ignore persisted unsupported `fontFamily` / `fontFile` for effective app chrome
- **AND** they SHALL verify that non-iOS font behavior covered by existing support is not regressed

#### Scenario: Text scaling behavior is verified
- **WHEN** widget or unit tests run for iOS typography behavior
- **THEN** they SHALL verify that system text scaling contributes to the effective iOS text scaler
- **AND** `AppFontSize.standard` MUST NOT replace the system scaler with a fixed linear value

#### Scenario: Settings font entry behavior is verified
- **WHEN** iPhone Preferences widget tests run
- **THEN** they SHALL verify that the font entry does not open an empty iOS system-font picker
- **AND** the rendered state SHALL communicate system default or an equivalent non-misleading state

#### Scenario: Platform adapter dependency guardrail is verified
- **WHEN** architecture tests or repo scans run
- **THEN** they SHALL prevent new `platform -> features`, `platform -> state`, `platform -> application`, and `platform -> data` dependencies introduced by this typography adaptation unless an explicit OpenSpec-approved exception exists

### Requirement: Adaptive UI surface rules SHALL distinguish brand surfaces from platform chrome
The platform adaptive UI system SHALL document and enforce the distinction between MemoFlow brand surfaces and platform-native chrome so future iOS changes do not mix raw Material/Cupertino decisions arbitrarily.

#### Scenario: High-perception Apple chrome is adapted
- **WHEN** migrated iPhone or iPadOS UI renders page chrome, navigation, picker, dialog, grouped list, bottom navigation, settings rows, or primary actions
- **THEN** it SHALL use `platform/`, settings, or approved adaptive seams for platform semantics
- **AND** page-local raw Material/Cupertino substitutions MUST NOT be introduced as the default migration path

#### Scenario: Shared brand surface is retained
- **WHEN** a surface intentionally keeps MemoFlow brand styling such as card color, primary accent, or content card shape on Apple mobile
- **THEN** that behavior SHALL be implemented through shared theme/settings/platform tokens or documented design rationale
- **AND** it MUST NOT rely on accidental global typography side effects such as unsupported fonts, overridden system scaling, or reader line height on UI chrome

#### Scenario: Future migration stays scoped
- **WHEN** future iOS UI work touches home, settings, memos, onboarding, collections, review, or stats
- **THEN** it SHALL reuse the typography and platform surface policy from this change where applicable
- **AND** it SHALL keep the touched area equal or better structured during `evolve_modularity`

### Requirement: Settings form field blocks SHALL align with settings section geometry

The platform adaptive UI system SHALL provide settings-owned full-width form field blocks whose label、input surface、helper text、error text 和 suffix action 在同一视觉网格内对齐。完整文本、密码、密钥、URL、路径和多行输入 SHALL NOT depend on a grouped-list row subtitle as the primary layout surface when that causes filled input backgrounds to drift from the section geometry.

#### Scenario: Full-width field renders as aligned block

- **WHEN** a migrated settings page renders a URL、路径、password、API Key、Security Key、access token 或其他长/敏感文本字段
- **THEN** the field SHALL render through `SettingsFormFieldRow`, `SettingsFieldBlock`, `SettingsMultilineFieldRow`, or an equivalent settings-owned field block seam
- **AND** label、filled input surface、helper text 和 error text SHALL share consistent horizontal padding inside the settings section
- **AND** the filled input background SHALL NOT visually touch or overflow the section border because of nested list row subtitle padding

#### Scenario: Multiline field uses same field block grid

- **WHEN** a migrated settings page renders AI 个人资料、反馈备注、通知正文或其他多行文本
- **THEN** the multiline input SHALL use the same settings-owned field block geometry
- **AND** minLines、maxLines、hint、helper text、error text、enabled state 和 callbacks SHALL remain expressible through the seam

#### Scenario: Inline fallback uses aligned full-width field

- **WHEN** an inline text or numeric settings field switches to a stacked fallback because of narrow width、large text scale 或 long label
- **THEN** the fallback SHALL use the aligned full-width field block seam
- **AND** it SHALL preserve the original controller、keyboardType、inputFormatters、onChanged、onSubmitted 和 onEditingComplete behavior

### Requirement: Settings field blocks SHALL use existing theme and settings tokens

Settings field block visuals SHALL use existing settings tokens, `ThemeData`, `ColorScheme`, platform widgets, or approved design tokens for fill、border、focused border、label、hint、helper、error、icon 和 disabled state. They SHALL NOT introduce a new color system or require global theme changes.

#### Scenario: Field block colors are theme-derived

- **WHEN** a field block renders in light mode or dark mode
- **THEN** field fill、border、focused border、hint text、label text、helper text、error text 和 icon colors SHALL come from existing theme/settings/platform seams
- **AND** the field block SHALL NOT hard-code new hex colors for ordinary settings field surfaces

#### Scenario: Focus and disabled states remain platform-safe

- **WHEN** a field block is focused, disabled, or has a suffix action
- **THEN** focus border、opacity、icon color 和 input behavior SHALL be expressed through the field seam and platform text field
- **AND** feature pages SHALL NOT need local Material/Cupertino wrappers to make the field render safely

### Requirement: Settings field block migration SHALL be guarded

The settings UI migration SHALL include guardrails that prevent migrated settings files from reintroducing page-local field surfaces or subtitle-based full-width form inputs for ordinary settings fields.

#### Scenario: Drift guardrail catches local field wrappers

- **WHEN** `settings_ui_drift_guardrail_test.dart` or equivalent architecture/style guardrail runs
- **THEN** migrated target files SHALL fail or require an explicit documented exception if they add page-local `PlatformTextField` + `InputBorder.none`, raw `TextField`, page-local field card wrappers, or direct raw palette field surface styling for ordinary settings forms
- **AND** shared reusable field presentation SHALL stay in `settings_ui.dart` or an approved platform/settings seam

#### Scenario: Boundary direction is preserved

- **WHEN** settings field block seam code is added or changed
- **THEN** `platform/widgets/*`, `state`, `application`, `core`, and `data` layers SHALL NOT import `features/settings` or other feature UI files
- **AND** feature pages SHALL continue to pass only presentation inputs such as label、controller、hint、suffix action 和 callbacks into the settings seam

### Requirement: Toolbar location settings prompt SHALL route through migrated settings surface

当用户从 memo compose 工具栏触发定位且定位 provider 未 ready 时，系统 SHALL 通过 settings/navigation seam 打开已迁移的定位设置 surface，而不是从 location picker 直接构造旧承载路由。

#### Scenario: Mobile toolbar prompt opens migrated location settings page

- **WHEN** 用户从 note input、memo editor 或 inline compose 工具栏点击定位
- **AND** location provider requirements 校验失败
- **AND** 用户在提示弹窗中选择打开设置
- **THEN** 系统 SHALL 使用 platform route 或 equivalent settings navigation seam 打开 `LocationSettingsScreen`
- **AND** `LocationSettingsScreen` SHALL 继续通过 `SettingsPage`、`SettingsSection`、`SettingsToggleRow`、`SettingsMenuRow`、`SettingsInputRow` 或 equivalent settings seams 渲染
- **AND** 系统 MUST NOT 使用 location picker 内部硬编码的裸 `MaterialPageRoute` 作为该入口的主路径

#### Scenario: Location picker delegates settings navigation

- **WHEN** `showLocationPickerSheetOrDialog()` 发现 location provider requirements 不 ready
- **THEN** 它 SHALL 显示现有 provider readiness prompt
- **AND** prompt 的打开设置动作 SHALL 调用传入的 opener callback、typedef 或 equivalent navigation seam
- **AND** `features/location_picker/show_location_picker.dart` MUST NOT import `features/settings/location_settings_screen.dart`
- **AND** location provider validation、settings reload、picker sheet/dialog presentation、map controller lifecycle 和 selected `MemoLocation` return behavior SHALL remain unchanged

#### Scenario: Toolbar location entry remains shared across compose surfaces

- **WHEN** note input、memo editor、inline compose 或 desktop quick input 复用 `showLocationPickerSheetOrDialog()`
- **THEN** 每个 runtime call site SHALL provide the same location settings opener behavior or an equivalent shared seam
- **AND** no compose surface SHALL reintroduce its own direct duplicate `LocationSettingsScreen` route construction for the provider-not-ready prompt

### Requirement: Toolbar location settings routing SHALL preserve architecture boundaries

工具栏定位设置路由 SHALL 在 `evolve_modularity` phase 下减少 picker 与 settings UI 的直接耦合，并 MUST NOT 引入新的 `state -> features`、`application -> features` 或 `core -> state|application|features` 依赖。

#### Scenario: Picker no longer owns settings widget construction

- **WHEN** toolbar location settings routing is implemented
- **THEN** location picker code SHALL depend on a stable opener contract rather than constructing settings widgets directly
- **AND** settings target/fallback widget construction SHALL remain in settings UI composition, caller composition, or an approved navigation seam
- **AND** implementation SHALL include focused tests or guardrails that fail if the picker reintroduces direct settings screen imports

#### Scenario: Public/private boundary remains unchanged

- **WHEN** toolbar location settings routing is implemented
- **THEN** public runtime code SHALL NOT add subscription、billing、entitlement、paywall、StoreKit 或 other commercial behavior
- **AND** `LocationSettings`, location repositories/providers/adapters, API files, WebDAV config transfer, private hooks, and public shell paid-feature state SHALL remain unchanged

### Requirement: Mobile settings home density SHALL stay compact within the home hierarchy
手机端设置首页 SHALL 支持 home-only compact density treatment，用于降低普通功能入口行高、顶部快捷入口高度、分组间距和 profile 内边距，同时保持 `enhance-mobile-settings-home-hierarchy` 建立的 profile card、quick shortcut tiles、grouped function sections 和 row divider 层级模型。

#### Scenario: Phone home ordinary function rows use compact density
- **WHEN** 手机端设置首页渲染 `SettingsHomeSection` 中的普通单行 function entries，例如使用指南、账号与安全、偏好设置、AI 设置、应用锁、实验室、功能组件、反馈、充电站、导入 / 导出、关于或 equivalent entries
- **THEN** Material phone single-line rows SHALL use 48 logical pixels as the compact target height through settings-owned home density tokens 或 approved settings/platform seam
- **AND** rows with descriptions, multiline content, larger text scale, or platform accessibility constraints MAY grow beyond 48 logical pixels to preserve readable content
- **AND** the compact row treatment SHALL NOT be hardcoded in `settings_screen.dart`

#### Scenario: Phone home hierarchy tokens use the first compact values
- **WHEN** `settingsPageTokens(context).homeHierarchy` resolves for phone form factor
- **THEN** quick shortcut tile height SHALL be 80 logical pixels
- **AND** section spacing SHALL be 12 logical pixels
- **AND** profile padding SHALL be 16 logical pixels
- **AND** these values SHALL be resolved through `settings_ui.dart` or an approved settings-owned seam

#### Scenario: Compact density preserves grouped section hierarchy
- **WHEN** 手机端设置首页渲染普通功能入口
- **THEN** ordinary entries SHALL remain inside grouped sections with row dividers where applicable
- **AND** ordinary entries SHALL NOT be forced into separate cards unless they are explicit quick shortcut tiles or approved special entries
- **AND** profile and quick shortcut entries SHALL preserve existing navigation, haptic, avatar rendering, icon/label semantics, and tap behavior

#### Scenario: Compact density does not affect secondary settings pages
- **WHEN** 用户从设置首页进入二级或三级 settings pages
- **THEN** those pages SHALL continue to use standard `SettingsPage`、`SettingsSection`、settings semantic rows, and platform row density
- **AND** mobile settings home compact row height, shortcut tile height, profile padding, and section spacing SHALL NOT automatically apply to those pages

#### Scenario: Desktop settings remains dense and work-focused
- **WHEN** 设置首页运行在 macOS、Windows 或 Linux desktop experience
- **THEN** desktop presentation SHALL preserve existing bounded, dense, work-focused settings layout
- **AND** it SHALL NOT be forced to use phone-only 48dp home rows, 80dp shortcut tiles, phone profile padding, or phone section spacing

#### Scenario: Home density is guarded and boundary-safe
- **WHEN** settings home density, settings UI seam, or platform list row seam code is modified
- **THEN** verification SHALL cover phone home compact row density, shortcut tile height, section spacing, profile padding, grouped sections, and secondary-page isolation
- **AND** implementation SHALL NOT introduce new `state -> features`、`application -> features`、`core -> state|application|features` dependencies or `platform/` imports from higher layers
- **AND** public code MUST NOT include subscription、billing、entitlement、receipt、paywall、StoreKit、private overlay 或 paid-feature branching logic

### Requirement: AI settings pages SHALL use semantic settings UI seams

AI settings pages in this batch SHALL render page chrome, grouped sections, navigation rows, value rows, toggle rows, form rows, warning/info rows, service/model action rows, empty states, and save/test actions through `SettingsPage`, `SettingsSection`, `SettingsNavigationRow`, `SettingsValueRow`, `SettingsToggleRow`, `SettingsInputRow`, `SettingsMenuRow`, `SettingsInfoRow`, `SettingsWarningRow`, `SettingsAction`, `settingsPageTokens`, or equivalent settings/platform seams instead of direct page-local `Scaffold` / `MemoFlowPalette` / card styling implementations.

#### Scenario: AI settings home is migrated

- **GIVEN** the user opens `AiSettingsScreen`
- **WHEN** AI settings are rendered
- **THEN** the page SHALL use settings semantic page and section seams
- **AND** profile, proxy, add service, service detail, add model, manage service, and service enabled toggle behavior SHALL be preserved.

#### Scenario: AI proxy and route settings are migrated

- **GIVEN** the user opens `AiProxySettingsScreen` or `AiRouteSettingsScreen`
- **WHEN** the page renders forms, route rows, picker surfaces, toggles, save/test actions, or result states
- **THEN** those visible surfaces SHALL use settings semantic seams or equivalent settings/theme tokens
- **AND** proxy save/test validation and default route binding replacement behavior SHALL be preserved.

#### Scenario: AI provider and profile settings are migrated

- **GIVEN** the user opens legacy `AiProviderSettingsScreen` or `AiUserProfileScreen`
- **WHEN** form fields, model pickers, helper copy, or save actions render
- **THEN** those surfaces SHALL use settings semantic seams or equivalent settings/theme tokens
- **AND** controller synchronization, dirty state, model option editing, and save behavior SHALL be preserved.

#### Scenario: AI service management pages are migrated

- **GIVEN** the user opens `AiServiceDetailScreen`, `AiServiceModelScreen`, or `AiServiceWizardScreen`
- **WHEN** service forms, model lists, preset cards, warning rows, validation actions, sync actions, wizard steps, or destructive actions render
- **THEN** those visible surfaces SHALL use settings semantic seams or equivalent settings/theme tokens
- **AND** embedded desktop task surface, unsaved close, service validation, model discovery, model edit/delete, wizard create, route binding, proxy warning, and docs link behavior SHALL be preserved.

### Requirement: AI settings migration SHALL preserve public/private and product boundaries

AI settings UI migration SHALL NOT implement AI summary history, commercial feature gating, private overlay behavior, StoreKit behavior, subscription state, product IDs, prices, receipts, entitlements, paywalls, or `AccessDecision.source` business branching.

#### Scenario: AI summary history remains out of scope

- **GIVEN** `add-ai-summary-history` remains an active product change
- **WHEN** this AI settings UI migration is implemented
- **THEN** it SHALL NOT add history persistence, history list/detail UI, rerun behavior, quota rules, or `AppCapability.aiSummaryHistory` gating.

#### Scenario: Guardrail reflects completed AI settings migration

- **GIVEN** AI settings files have been migrated
- **WHEN** `settings_ui_drift_guardrail_test.dart` runs
- **THEN** migrated AI settings files SHALL be removed from `legacyAllowlist`
- **AND** migrated AI settings files SHALL be present in `migratedFiles`
- **AND** non-allowlisted migrated files SHALL fail architecture verification if they reintroduce direct `return Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`.

### Requirement: Remaining desktop settings surfaces SHALL use settings/platform visual seams

Remaining desktop settings surfaces SHALL render normal settings pages and sidebar visual states through `SettingsPage`, `SettingsSection`, `settingsPageTokens`, `ThemeData.colorScheme`, or equivalent settings/platform seams, while preserving desktop window composition-root behavior.

#### Scenario: Desktop shortcut overview is migrated

- **GIVEN** the user opens `DesktopShortcutsOverviewScreen`
- **WHEN** editor and global shortcut groups render
- **THEN** the page SHALL use settings semantic page/section seams or equivalent settings tokens
- **AND** shortcut labels, fallback F1 label, editor/global grouping, and binding normalization SHALL be preserved.

#### Scenario: Desktop settings window sidebar uses theme tokens

- **GIVEN** the desktop settings window workbench renders pane navigation
- **WHEN** selected and unselected pane nav tiles are displayed
- **THEN** visual state colors SHALL come from `ThemeData.colorScheme` or equivalent platform/settings tokens
- **AND** pane switching, target routing, workspace reload, method channel handling, and window lifecycle behavior SHALL be preserved.

#### Scenario: Composition-root palette apply remains narrowly allowed

- **GIVEN** `DesktopSettingsWindowApp` builds its independent `MaterialApp`
- **WHEN** user theme preferences are applied
- **THEN** `MemoFlowPalette.applyThemeColor(...)` MAY remain as a narrow composition-root exception
- **AND** guardrails SHALL NOT allow additional direct `MemoFlowPalette` usage in `desktop_settings_window_app.dart`.

### Requirement: Settings layout SHALL preserve adaptive behavior while unifying presentation geometry

平台适配 UI 系统 SHALL allow settings pages to keep platform-adaptive behavior while moving reusable settings presentation geometry into settings-owned seams. `Switch`、picker/dialog、route/back behavior 和 text input behavior SHALL remain adaptive, while section spacing、row padding、typography、field block geometry、divider 和 card hierarchy SHALL be controlled by settings UI seams rather than platform default list row geometry.

#### Scenario: Adaptive behavior remains platform-owned

- **WHEN** a migrated settings page renders a toggle、choice picker、confirmation dialog、navigation route、back action 或 editable text field
- **THEN** the behavior SHALL continue to use `PlatformSwitch`, platform picker/dialog/route seams, `PlatformTextField`, or an approved adaptive seam
- **AND** the page SHALL NOT duplicate platform-specific business state or complete platform-specific page trees

#### Scenario: Presentation geometry is settings-owned

- **WHEN** a migrated settings page renders section cards、row titles、row values、descriptions、full-width fields、inline fields 或 dividers
- **THEN** reusable geometry SHALL come from `settings_ui.dart`, settings-owned layout constants, `SettingsSection`, settings row seams, `SettingsFieldBlock`, or an approved settings seam
- **AND** `CupertinoListTile`, Material `ListTile`, or equivalent platform default row geometry SHALL NOT be the primary owner of ordinary settings typography and padding

#### Scenario: Platform visual differences stay below the seam

- **WHEN** the same migrated settings page runs on iPhone and Android
- **THEN** platform-specific controls MAY keep platform-appropriate behavior and interaction details
- **AND** ordinary settings text hierarchy、row spacing、field padding、section inset 和 divider treatment SHALL remain recognizably consistent across both platforms

### Requirement: Settings typography SHALL express a stable hierarchy

The platform adaptive UI system SHALL provide settings-owned typography hierarchy for settings screens so section headings、row labels、values、input values、placeholders 和 descriptions have stable relative priority across supported platforms.

#### Scenario: Settings text hierarchy is consistent

- **WHEN** a migrated settings page renders section header、row title、right-side selected value、input value、placeholder 和 description text
- **THEN** row title text SHALL be visually stronger than right-side selected values and descriptions
- **AND** description text SHALL be visually weaker than row title and selected/input values
- **AND** section header text SHALL be secondary to page title and suitable as a group label rather than a primary heading

#### Scenario: Typography uses existing theme colors

- **WHEN** settings typography renders in light mode or dark mode
- **THEN** foreground colors SHALL resolve from settings tokens, `ThemeData`, `ColorScheme`, or approved design tokens
- **AND** the hierarchy SHALL NOT require new hard-coded hex colors, a new color system, or global theme changes

### Requirement: Settings field geometry SHALL be platform-safe but visually unified

Settings field seams SHALL provide unified input height、content padding、label/helper/error spacing、hint/value styling 和 suffix icon treatment while preserving platform text input behavior.

#### Scenario: Full-width field geometry is unified

- **WHEN** a migrated settings page renders URL、password、API key、path、notes 或 other full-width input through `SettingsFieldBlock`, `SettingsFormFieldRow`, `SettingsMultilineFieldRow`, or an approved seam
- **THEN** label、input surface、helper/error text 和 suffix action SHALL align to the same settings-owned grid
- **AND** input height and padding SHALL be defined by the settings seam rather than page-local widgets

#### Scenario: Inline fallback uses unified field geometry

- **WHEN** an inline settings field falls back to stacked layout due to narrow width、large text scale 或 long label
- **THEN** it SHALL use the same settings-owned field geometry as other full-width fields
- **AND** controller、focusNode、keyboardType、inputFormatters、enabled state 和 callbacks SHALL be preserved

#### Scenario: Platform text input behavior remains available

- **WHEN** a settings field runs on iPhone, Android, desktop, or web
- **THEN** editing behavior, keyboard behavior, focus behavior, obscured input behavior, and platform-safe rendering SHALL continue through `PlatformTextField` or an approved platform input seam
- **AND** unified geometry SHALL NOT force a separate iOS-only or Android-only settings page tree
