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

#### Scenario: Settings actions are rendered
- **WHEN** a migrated settings page renders save, confirm, continue, cancel, reset, destructive, or secondary actions
- **THEN** it SHALL express the semantic action variant instead of hardcoding button foreground/background colors in the screen

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

