# apple-platform-ui-adaptation Specification

## Purpose
TBD - created by archiving change adapt-apple-platform-ui. Update Purpose after archive.
## Requirements
### Requirement: Apple platform UI adapter

The system SHALL provide a public platform UI adapter layer for Apple platform presentation differences without duplicating feature page trees or embedding commercial logic.

#### Scenario: Platform UI seam is used
- **WHEN** Apple-specific page chrome, route, dialog, picker, action sheet, grouped list, icon, or adaptive control behavior is implemented
- **THEN** the behavior MUST be exposed through `platform/` UI adapter APIs or an equivalent centralized seam instead of scattered `Platform.isIOS` / `TargetPlatform.macOS` branches inside feature pages

#### Scenario: Feature page trees are not copied
- **WHEN** iOS, iPadOS, or macOS UI is adapted
- **THEN** the system MUST NOT create full duplicate `features_ios/`, `features_ipad/`, or `features_macos/` page trees

#### Scenario: Platform seam dependency direction
- **WHEN** files under the platform UI adapter are added or changed
- **THEN** they MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`

#### Scenario: Commercial logic is excluded
- **WHEN** Apple platform UI shell or adapter code is added to the public repository
- **THEN** it MUST NOT include StoreKit, subscription, buyout, entitlement, receipt, product ID, price, paywall, App Store Connect, signing secret, notarization, TestFlight, or private release automation logic

### Requirement: Apple shell differentiation

The system SHALL provide differentiated Apple shell strategies for iOS, iPadOS, and macOS while reusing existing business state and destination models.

#### Scenario: macOS memo list uses desktop card and preview behavior
- **WHEN** the app runs on macOS in a wide desktop home memo list layout
- **THEN** memo cards MUST remain bounded to the shared desktop memo card maximum width
- **AND** memo card media tiles MUST avoid height-limited horizontal stretching by preserving desktop square tile proportions when the media grid is capped by available height
- **AND** tapping a memo card SHOULD open or update the desktop preview pane instead of navigating directly to the full detail route
- **AND** the implementation MUST reuse the existing memo list preview state and desktop layout seams instead of creating macOS-only memo state

### Requirement: Platform page and route behavior

The system SHALL route page-level chrome and transitions through platform-aware abstractions.

#### Scenario: Platform page chrome
- **WHEN** a migrated page needs title, leading action, trailing actions, body, safe area, drawer, sidebar, bottom navigation, or toolbar behavior
- **THEN** it MUST use `PlatformPage` or an equivalent platform page abstraction rather than directly encoding Apple-specific page chrome in the feature page

#### Scenario: Platform routes
- **WHEN** a migrated flow pushes a new page on iOS, iPadOS, macOS, Android, Windows, Linux, or web
- **THEN** it MUST use a platform route abstraction that preserves existing Material / Windows behavior while using Apple-appropriate transitions and back gesture behavior on Apple platforms

#### Scenario: Existing fallback
- **WHEN** a platform page or route adapter cannot provide a specialized Apple implementation yet
- **THEN** it MUST fall back to the existing Material behavior without changing business state or data flow

### Requirement: Platform dialogs, action sheets, menus, and pickers

The system SHALL provide semantic wrappers for high-perception transient UI on Apple platforms.

#### Scenario: Confirm and destructive dialog
- **WHEN** a migrated flow asks users to confirm, discard, delete, exit, overwrite, restore, or perform a destructive action
- **THEN** it MUST use a platform dialog abstraction that maps to Apple-appropriate alert or sheet behavior on Apple platforms

#### Scenario: Action menu
- **WHEN** a migrated flow presents contextual actions such as memo more menu, share, edit, delete, attach, visibility, template, or tag actions
- **THEN** it MUST use a platform action sheet, menu, or popover abstraction appropriate to iPhone, iPadOS, macOS, and existing non-Apple platforms

#### Scenario: Enum and date-time selection
- **WHEN** a migrated flow asks the user to choose an enum value, single option, multi option, date, time, schedule, font, theme mode, or similar picker value
- **THEN** it MUST use a platform picker abstraction rather than hardcoding `AlertDialog`, `SimpleDialog`, `DropdownButton`, or `showModalBottomSheet` for all platforms

### Requirement: Platform grouped settings and form controls

The system SHALL provide Apple-appropriate grouped list and form controls for settings and configuration pages.

#### Scenario: Settings grouped list
- **WHEN** a migrated settings or configuration page displays groups of navigable rows, toggles, value rows, text input rows, or destructive rows
- **THEN** it MUST use `PlatformGroupedList`, `PlatformListTile`, or equivalent abstractions that can render Apple inset grouped lists on Apple platforms and preserve existing style elsewhere

#### Scenario: Adaptive form controls
- **WHEN** a migrated page displays switch, checkbox, radio, slider, progress, text field, search field, or segmented control behavior
- **THEN** it MUST use platform control wrappers or a documented platform adapter entry point rather than scattering direct `*.adaptive` or platform branches through the page

#### Scenario: Settings pilot
- **WHEN** the first Apple UI migration batch is implemented
- **THEN** `SettingsScreen` and `PreferencesSettingsScreen` MUST be treated as pilot pages for grouped list, picker, dialog, switch, route, and page chrome behavior

### Requirement: Apple UI migration coverage and progress tracking

The system SHALL track Apple UI migration coverage until all high-perception Apple UI areas are completed.

#### Scenario: Migration inventory
- **WHEN** implementation begins
- **THEN** the change MUST create or update a migration inventory covering scaffold / app bar / navigation, tab / sidebar / drawer, dialog / alert, bottom sheet / popup menu, picker, form controls, text input, grouped list / card, key icons, route transition / back gesture, scrolling, safe area, dark mode, dynamic type, accessibility, and macOS menu / window behavior

#### Scenario: Batch progress
- **WHEN** each migration batch is completed
- **THEN** `tasks.md` or an associated OpenSpec note MUST identify which Apple UI areas are complete, in progress, and still pending

#### Scenario: Completion standard
- **WHEN** the change is considered complete
- **THEN** high-perception Apple UI areas in home shell, settings, memo list, memo detail, memo editor, note input, collections, reminders, review, stats, and debug flows MUST either use the platform UI adapter or have a documented reason why existing behavior is acceptable on Apple platforms

### Requirement: App Store and modularity guardrails

The system SHALL preserve public/private boundaries and modularity constraints while adapting Apple UI.

#### Scenario: Public/private commercial boundary
- **WHEN** Apple UI code is added to public shell, settings, home, memo, platform, or shared UI files
- **THEN** it MUST NOT branch on subscription, paid feature, entitlement, receipt, product, price, Family Sharing, StoreKit, or `AccessDecision.source`

#### Scenario: Architecture guardrail
- **WHEN** platform UI adapter files are added or changed
- **THEN** architecture tests or repo scans MUST prevent new `platform -> features`, `platform -> state`, `platform -> application`, and `platform -> data` dependencies unless an explicit OpenSpec-approved adapter exception is documented

#### Scenario: Coupling hotspot touched
- **WHEN** a migration batch touches an existing coupled area such as `home`, `settings`, `memos`, `core`, or desktop shell code
- **THEN** the touched area MUST remain equal or better structured by extracting platform behavior into a seam, reducing platform-specific feature-page branching, or tightening a guardrail

### Requirement: macOS shell SHALL avoid redundant top-leading titles in expanded sidebar mode
The macOS Apple shell SHALL treat the expanded sidebar selected state as the page context for top-level drawer destinations and SHALL NOT place duplicate destination titles in the native traffic-light titlebar area.

#### Scenario: Top-level destination uses sidebar context
- **WHEN** the app runs on macOS, the main shell shows an expanded sidebar, and the selected page is a top-level drawer destination such as memos, explore, review, collections, resources, tags, stats, settings, or about
- **THEN** the macOS shell SHALL use the sidebar selected state as the current-page indicator instead of rendering the same destination label in the top-leading titlebar region

#### Scenario: Expanded sidebar navigation remains vertically stable
- **WHEN** the app runs on macOS with an expanded sidebar and switches between top-level drawer destinations that omit duplicated titlebar content
- **THEN** the macOS shell SHALL keep a consistent titlebar or toolbar spacer height so the sidebar menu position does not jump between destinations

#### Scenario: Apple shell still supports compact context
- **WHEN** the app runs on macOS with rail, overlay, narrow, or otherwise hidden navigation labels
- **THEN** the macOS shell SHALL allow the current destination title to appear only in a region that is outside native traffic-light reserved space

#### Scenario: Secondary Apple pages preserve task titles
- **WHEN** a macOS page represents a secondary task, detail, editor, subwindow, modal surface, or route with back semantics
- **THEN** the Apple shell SHALL preserve meaningful title or navigation context outside native window-control reserved space

### Requirement: macOS main-window close control SHALL dismiss secondary routes
The macOS Apple shell SHALL use the native red close control to dismiss secondary routes inside the main app window before applying normal root-window close or hide behavior.

#### Scenario: Secondary route uses native close as route dismissal
- **WHEN** the macOS main window displays a pushed secondary route such as release notes, diagnostics, detail, editor, or settings subsection and that route can be popped
- **THEN** activating the native red close control SHALL pop that route and return to the previous app context while keeping the main window open

#### Scenario: Root route keeps native window behavior
- **WHEN** the macOS main window displays a root or top-level route
- **THEN** activating the native red close control SHALL keep the normal macOS window close or hide behavior

#### Scenario: App-level route dismissal controls are omitted
- **WHEN** the macOS main window displays a secondary route whose dismissal is handled by native close dispatch
- **THEN** the Apple shell SHALL NOT render an additional app-level back button, close button, or done button for that route

### Requirement: Apple titlebar context SHALL use centralized shell policy
The macOS Apple shell SHALL derive title visibility from a centralized desktop shell or platform adapter policy rather than feature-page-specific traffic-light padding or page-by-page title suppression.

#### Scenario: Feature page does not own traffic-light decisions
- **WHEN** a feature page passes `leadingTitle`, command-bar content, or navigation content to a macOS desktop shell
- **THEN** the feature page SHALL NOT hard-code macOS traffic-light offsets, native close interception, or expanded-sidebar title hiding rules

#### Scenario: macOS policy remains public-shell safe
- **WHEN** Apple titlebar context rules are added or changed in the public repository
- **THEN** they MUST NOT include StoreKit, subscription, entitlement, receipt, price, product ID, paywall, private overlay, or `AccessDecision.source` business branching

### Requirement: macOS Apple shell SHALL respect native traffic-light chrome
The system SHALL treat macOS native traffic lights as reserved window chrome when Apple shell content is drawn into a transparent or full-size titlebar region.

#### Scenario: Apple shell titlebar content is offset
- **WHEN** `AppleMacosPageShell` or an equivalent macOS shell renders top-leading titlebar, toolbar, navigation, or command content
- **THEN** that content MUST be offset, constrained, or otherwise laid out so it does not overlap native red/yellow/green window controls

#### Scenario: Apple shell uses centralized chrome metrics
- **WHEN** macOS shell code needs traffic-light spacing
- **THEN** it SHALL use the desktop window chrome safe-area seam rather than embedding unrelated page-specific padding in feature widgets

### Requirement: macOS settings window SHALL be treated as a high-perception Apple UI surface
The Apple platform UI adaptation SHALL treat the macOS settings window as a high-perception Apple UI surface that must look and behave intentionally on macOS while reusing shared settings state and pages.

#### Scenario: macOS settings surface is opened
- **WHEN** the user opens settings on macOS
- **THEN** the system SHALL prefer a macOS-appropriate independent settings window or equivalent native-feeling settings surface
- **AND** it SHALL NOT rely on an Android-style drawer transition as the primary macOS settings experience

#### Scenario: Settings window cannot be opened
- **WHEN** the macOS independent settings window cannot be opened
- **THEN** the fallback settings page SHALL still use existing platform page, route, grouped list, and Apple shell adaptations where available

### Requirement: macOS settings adaptation SHALL avoid duplicate feature page trees
The macOS settings adaptation SHALL reuse existing feature screens, platform adapters, and settings composition seams instead of creating a parallel Apple settings feature tree.

#### Scenario: macOS-specific settings behavior is added
- **WHEN** macOS-specific settings window behavior, chrome, routes, or entry handling is added
- **THEN** it SHALL be implemented through platform, desktop window, shell, or composition seams
- **AND** it MUST NOT create a full duplicate `features_macos/`, `features_ios/`, or Apple-only settings page hierarchy

### Requirement: macOS settings adaptation SHALL preserve public/private boundaries
The macOS settings adaptation SHALL remain public-shell safe and SHALL NOT introduce commercial branching into shared Apple UI or settings code.

#### Scenario: macOS settings UI code is changed
- **WHEN** macOS settings UI, shell, menu, route, or window code is added or changed in the public repository
- **THEN** it MUST NOT branch on subscription, paid feature, entitlement, receipt, product, price, Family Sharing, StoreKit, or `AccessDecision.source`

