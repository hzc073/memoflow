## ADDED Requirements

### Requirement: Platform adaptive UI system SHALL centralize platform presentation strategy
The system SHALL provide a platform adaptive UI strategy that maps shared feature intent to platform-appropriate presentation without duplicating business state or full feature page trees.

#### Scenario: Feature page uses adaptive presentation
- **WHEN** a migrated feature page needs scaffold, navigation, primary action, command bar, list section, dialog, picker, sheet, popover, master-detail, or form control behavior
- **THEN** the page SHALL use `platform/` adapters, desktop shell host boundaries, adaptive UI components, or feature-owned composition seams instead of scattering direct platform branches through the page

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
The system SHALL preserve independent shell strategies for mobile, tablet, macOS, Windows, and Linux while sharing feature intent and navigation state.

#### Scenario: Desktop shell host is used
- **WHEN** a migrated desktop feature needs sidebar, rail, toolbar, command bar, preview pane, modal surface, or window chrome integration
- **THEN** it SHALL compose through `DesktopShellHost` or an equivalent desktop shell boundary rather than importing a specific Windows or macOS shell implementation directly

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
