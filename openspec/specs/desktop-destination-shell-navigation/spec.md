# desktop-destination-shell-navigation Specification

## Purpose
TBD - created by archiving change unify-desktop-destination-shell-navigation. Update Purpose after archive.
## Requirements
### Requirement: Desktop top-level destinations SHALL use a unified destination shell
桌面顶层 drawer destination 页面 SHALL 通过统一 desktop destination shell seam 表达页面语义，而不是在 feature page 内自行选择 Windows shell、macOS Scaffold 或其他平台 shell 树。

#### Scenario: Feature page provides semantic destination slots
- **WHEN** a top-level desktop drawer destination renders on Windows or macOS
- **THEN** the feature page SHALL provide semantic slots such as selected destination, title, actions, body, secondary pane, modal surface, and navigation context
- **AND** the feature page SHALL NOT locally branch between `DesktopShellHost` and `Scaffold` for the top-level desktop shell

#### Scenario: Shell routes to platform-specific chrome
- **WHEN** the unified destination shell receives semantic slots for a top-level destination
- **THEN** it SHALL route those slots to the appropriate Windows or macOS shell implementation
- **AND** Windows command bar, macOS toolbar, traffic-light safe area, sidebar, rail, overlay, and title visibility SHALL remain platform-shell-owned behavior

### Requirement: Desktop top-level destinations SHALL not hide dismissal controls inside title widgets
顶层 desktop destination 页面 SHALL NOT encode back, close, done, or route-dismissal controls inside title widgets such as `leadingTitle`. Dismissal intent, when valid for a top-level surface, SHALL be expressed through an explicit shell semantic input.

#### Scenario: Top-level title remains semantic
- **WHEN** a feature page provides a top-level destination title to the desktop destination shell
- **THEN** the title slot SHALL identify the destination or task
- **AND** it SHALL NOT include page-local `IconButton` controls for back, close, done, or equivalent dismissal actions

#### Scenario: Settings close intent remains explicit
- **WHEN** a top-level settings surface needs a close affordance on a desktop platform
- **THEN** the close behavior SHALL be represented through an explicit shell intent or settings-specific shell adapter
- **AND** the shell SHALL decide whether and where to render the control for the current platform and navigation context

### Requirement: Migrated desktop destination pages SHALL preserve navigation behavior
迁移到统一 shell seam 的顶层 desktop destination 页面 SHALL preserve existing drawer navigation, tag navigation, notification entry, filter/search actions, secondary panes, modal surfaces, and back handling semantics unless a later spec explicitly changes them.

#### Scenario: Drawer destination navigation is preserved
- **WHEN** a migrated top-level desktop destination user selects another drawer destination
- **THEN** the existing destination navigation callback SHALL still route to the selected destination
- **AND** the migration SHALL NOT introduce feature-to-feature shortcuts that bypass the existing home/drawer navigation seam

#### Scenario: Page actions remain available
- **WHEN** a migrated top-level desktop destination has existing actions such as filter, search, create, clear, share, or mode selection
- **THEN** those actions SHALL remain available through the unified shell actions or command slots
- **AND** their business behavior SHALL remain owned by the original feature page or existing controller

### Requirement: Desktop destination shell migration SHALL be guarded
The system SHALL include automated guardrails or focused tests that prevent migrated top-level desktop destination pages from reverting to page-local Windows/macOS shell branching.

#### Scenario: Guardrail catches page-local shell split
- **WHEN** a migrated top-level destination page contains a local `isWindowsDesktop ? DesktopShellHost(...) : Scaffold(...)` shell split or equivalent pattern
- **THEN** architecture guardrails SHALL fail and direct the implementation back to the unified desktop destination shell seam

#### Scenario: Guardrail catches title-embedded dismissal controls
- **WHEN** a migrated top-level destination page passes a title widget containing back, close, done, or equivalent dismissal controls into the desktop shell
- **THEN** architecture guardrails or focused tests SHALL fail unless the page has an explicit documented exception

### Requirement: Desktop home quick actions SHALL reuse drawer destination navigation

桌面首页顶部快捷入口打开已有 top-level drawer destination 时，系统 SHALL 复用与侧边栏相同的 destination navigation seam，而不是为同一 destination 创建独立 push-route 语义。

#### Scenario: Desktop quick AI summary matches drawer navigation
- **GIVEN** app 运行在 desktop homepage memo list
- **WHEN** 用户点击顶部快捷胶囊中的 `aiSummary`
- **THEN** the app SHALL navigate using the same desktop destination semantics as selecting `AppDrawerDestination.aiSummary` from the sidebar
- **AND** the resulting AI summary destination SHALL expose the same selected drawer state, titlebar ownership, and back behavior as sidebar navigation
- **AND** the action SHALL NOT use a separate `Navigator.push` path that makes the destination feel like a different interface.

#### Scenario: Desktop quick daily review matches drawer navigation
- **GIVEN** app 运行在 desktop homepage memo list
- **WHEN** 用户点击顶部快捷胶囊中的 `dailyReview`
- **THEN** the app SHALL navigate using the same desktop destination semantics as selecting `AppDrawerDestination.dailyReview` from the sidebar
- **AND** the resulting daily review destination SHALL expose the same selected drawer state, titlebar ownership, and back behavior as sidebar navigation.

#### Scenario: Desktop quick destinations preserve account availability rules
- **GIVEN** a quick action maps to a destination that requires an account, such as explore or notifications
- **WHEN** the current workspace is local-library-only
- **THEN** the app SHALL preserve the existing unavailable feedback
- **AND** it SHALL NOT bypass drawer destination availability checks through the quick action path.

### Requirement: Desktop workspace-internal navigation SHALL use consistent motion policy

桌面首页中属于同一 workspace 的 quick action 和 drawer destination transitions SHALL use one consistent motion policy for the same target type.

#### Scenario: Top quick and sidebar destination motion match
- **GIVEN** app 运行在 desktop homepage context
- **WHEN** 用户通过顶部快捷入口进入 `aiSummary` 或 `dailyReview`
- **AND** 用户通过侧边栏进入同一 destination
- **THEN** both entry paths SHALL use the same destination transition policy for the current desktop navigation mode
- **AND** neither path SHALL add an extra route-level animation on top of the shared destination transition.

#### Scenario: Primary-column utility swap avoids route-level animation
- **GIVEN** app 运行在 desktop homepage context
- **WHEN** 用户打开 stats、sync queue、notifications 或 draft box as a primary-column utility
- **THEN** the transition SHALL be a workspace-internal content swap
- **AND** it SHALL NOT use a standalone route transition to replace the whole window surface.
