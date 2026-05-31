# desktop-shell-host-boundary Specification

## Purpose
TBD - created by archiving change phase-2-introduce-desktop-shell-host. Update Purpose after archive.
## Requirements
### Requirement: 桌面功能页面 SHALL 通过外壳宿主组合
项目 SHALL 让桌面功能页面通过桌面外壳宿主边界完成组合，而不是直接导入 Windows 外壳实现，也不得在已迁移的顶层 drawer destination 页面中自行分叉 Windows/macOS shell 树。

#### Scenario: 功能页面需要桌面外壳包装
- **WHEN** 某个功能页面在桌面端需要标题栏、导航、命令栏或页面外壳
- **THEN** 该页面必须依赖桌面外壳宿主边界，而不是直接依赖 `WindowsDesktopPageShell`

#### Scenario: 顶层 destination 使用统一 shell seam
- **WHEN** 某个已迁移的顶层 drawer destination 页面在 Windows 或 macOS 桌面端渲染
- **THEN** 该页面 SHALL 通过 `DesktopShellHost`、`DesktopDestinationShell` 或等价统一 shell seam 表达 destination、title、actions、body 和 navigation context
- **AND** 该页面 SHALL NOT locally branch between `DesktopShellHost` and `Scaffold` for Windows/macOS top-level shell selection

### Requirement: 外壳宿主 SHALL 支持平台外壳路由
桌面外壳宿主 SHALL 提供一个组合点，未来可以按平台路由到 Windows 外壳或私有 macOS 外壳。

#### Scenario: 私有 macOS 外壳接入
- **WHEN** 私有 macOS 版本提供自己的顶层外壳实现
- **THEN** 功能页面必须能通过外壳宿主边界接入该实现，而不需要导入私有 macOS 外壳模块

### Requirement: 桌面外壳宿主 SHALL own titlebar navigation-context policy
桌面外壳宿主 SHALL 根据平台、navigation mode 和页面层级决定 titlebar leading title、top-level title、leading control 和 dismissal control 是否渲染，而不是要求功能页面自行判断窗口控件、安全区、侧边栏状态或返回/关闭控件位置。

#### Scenario: 功能页面提供语义 title
- **WHEN** 功能页面向 `DesktopShellHost` 或等价桌面外壳提供 `leadingTitle`、`center`、`trailing`、command bar 或 body slot
- **THEN** 功能页面 SHALL 只表达语义内容，title visibility 和 chrome-safe placement MUST 由桌面外壳宿主处理

#### Scenario: 顶层 title 不包含 dismissal control
- **WHEN** 顶层 drawer destination 页面向 desktop shell 提供 title 或 leading title
- **THEN** title widget MUST NOT contain page-local back, close, done, or route-dismissal controls
- **AND** any valid top-level dismissal behavior MUST be expressed through an explicit shell semantic input

#### Scenario: 展开侧边栏隐藏重复顶级 title
- **WHEN** 桌面外壳宿主在 macOS expanded sidebar 模式下渲染顶级 drawer destination
- **THEN** 桌面外壳宿主 SHALL omit titlebar leading title when the same destination label and selected state are already visible in the sidebar

#### Scenario: 展开侧边栏保留稳定 toolbar spacer
- **WHEN** 桌面外壳宿主在 macOS expanded sidebar 模式下隐藏顶级 drawer destination 的重复 title 或 leading control
- **THEN** 桌面外壳宿主 SHALL preserve a consistent titlebar or toolbar spacer height so the sidebar and body start position remain stable across top-level destination switches

#### Scenario: 隐藏 chrome 的 spacer 不引入页面级分割线
- **WHEN** 桌面外壳宿主在 macOS expanded sidebar 模式下只保留顶级页面的稳定 titlebar 或 toolbar spacer
- **THEN** 该 spacer SHALL NOT render page-specific bottom dividers or separators unless visible toolbar content explicitly requires the boundary

#### Scenario: 非展开导航保留必要 title
- **WHEN** 桌面外壳宿主在 rail、overlay、narrow 或 navigation labels 不持久可见的模式下渲染顶级 destination
- **THEN** 桌面外壳宿主 SHALL allow a current page title to render in a window-chrome-safe titlebar or toolbar region

### Requirement: 桌面外壳宿主 SHALL distinguish top-level navigation from secondary task context
桌面外壳宿主 SHALL 能区分顶级 drawer destination 与二级任务页面，以避免把所有页面标题一刀切隐藏。

#### Scenario: 顶级页面使用导航选中态
- **WHEN** 当前页面是顶级 drawer destination 且展开侧边栏中存在可读 selected state
- **THEN** 桌面外壳宿主 SHALL treat sidebar selection as sufficient title context

#### Scenario: 二级任务保留上下文
- **WHEN** 当前页面是详情、编辑、设置子页、modal task surface 或带返回语义的 pushed route
- **THEN** 桌面外壳宿主 SHALL keep title or equivalent task context discoverable outside native or custom window-control reserved space

#### Scenario: macOS 二级 route 不渲染 App 级返回控件
- **WHEN** 桌面外壳宿主在 macOS main window 中渲染可 pop 的二级 pushed route
- **THEN** 桌面外壳宿主 SHALL omit app-level back, close, and done controls for dismissing that route

### Requirement: 桌面外壳宿主 SHALL route native close by page depth
桌面外壳宿主 SHALL 根据当前窗口 route depth 分派 native close 行为，使 macOS 主窗口二级 route 优先回到上一层，而 root/top-level route 保持窗口关闭/隐藏语义。

#### Scenario: macOS 二级 route close maps to logical back
- **WHEN** macOS main window 当前 route stack 可以 pop 二级页面
- **THEN** native red close control SHALL trigger logical back / route pop instead of closing or hiding the main window

#### Scenario: macOS root route close keeps window semantics
- **WHEN** macOS main window 当前 route stack 位于 root 或顶级页面
- **THEN** native red close control SHALL use the normal window close or hide policy

#### Scenario: close dispatch remains shell-owned
- **WHEN** feature pages are added or changed under the desktop shell
- **THEN** they SHALL NOT individually intercept native red close or implement window-close fallback behavior

### Requirement: 桌面外壳宿主 policy SHALL be guarded against feature-page drift
桌面外壳宿主 SHALL include focused verification or guardrails so future feature pages do not reintroduce page-local titlebar padding, duplicated macOS top-leading titles, page-local Windows/macOS shell branching, or title-embedded dismissal controls.

#### Scenario: 新桌面顶级页面接入外壳
- **WHEN** a new top-level drawer destination is added to a desktop shell
- **THEN** verification SHALL ensure it follows the centralized titlebar navigation-context policy instead of adding macOS-specific titlebar padding in the feature page

#### Scenario: 已迁移页面不回退到平台分支
- **WHEN** a migrated top-level drawer destination is changed
- **THEN** guardrails SHALL fail if the page reintroduces `isWindowsDesktop ? DesktopShellHost(...) : Scaffold(...)` or equivalent page-local shell split without an explicit documented exception

#### Scenario: shell policy changes
- **WHEN** title visibility, navigation mode routing, or desktop window chrome policy changes
- **THEN** focused tests or guardrails SHALL cover macOS expanded sidebar suppression, secondary-route native close dispatch, and at least one title-visible fallback mode

### Requirement: 桌面外壳宿主 SHALL own window chrome safe-area composition
桌面外壳宿主 SHALL 在平台外壳层组合 titlebar、toolbar、navigation 和 window-control safe-area，而不是要求功能页面自行处理系统窗口控件避让。

#### Scenario: 功能页面进入桌面 titlebar 区域
- **WHEN** 某个功能页面向桌面外壳提供 title、leading action、trailing action、command bar 或 navigation content
- **THEN** 桌面外壳宿主必须负责将这些内容放置在对应平台的 window chrome safe area 之外

#### Scenario: 子窗口复用桌面 chrome 规则
- **WHEN** 独立桌面子窗口（例如 settings window）使用自定义 frame、transparent titlebar 或平台窗口控件
- **THEN** 该子窗口必须复用桌面 window chrome safe-area 规则或等价 shell seam，而不是在子页面中重复 hard-coded padding

### Requirement: Desktop memo list layout SHALL not hide shared desktop behavior behind Windows-only gates

Desktop memo list card-width, preview-pane, and supported inline compose resize behavior SHALL be expressed as desktop layout behavior unless a platform-specific exception is explicitly documented. Preview-pane support and default memo-click preview behavior SHALL use shared desktop memo-list layout tiers rather than a Windows-only tier or a macOS-only legacy preview breakpoint. Supported inline compose resize behavior SHALL use a shared capability decision rather than route-specific omitted flags.

#### Scenario: Shared desktop card width
- **WHEN** a memo card is rendered in a desktop target memo list
- **THEN** it MUST use the shared desktop memo card maximum width rather than a Windows-only width constraint

#### Scenario: Shared desktop media tile proportions
- **WHEN** a memo media grid is rendered in a desktop target memo surface and its configured max height is smaller than its unconstrained square grid height
- **THEN** the grid MUST preserve square tile proportions by shrinking tile width and height together
- **AND** this behavior MUST NOT be limited to Windows-only platform checks

#### Scenario: Expanded desktop memo list supports right-side preview pane
- **GIVEN** the app is running in the desktop home memo list on Windows or macOS
- **AND** the window width is at least the shared expanded desktop threshold of `1200`
- **WHEN** the memo list builds its desktop layout state
- **THEN** the memo list SHALL consider the right-side desktop preview pane supported for that platform
- **AND** this support MUST NOT depend on the legacy `1440` desktop preview breakpoint for macOS home memo list behavior

#### Scenario: Wide desktop memo click opens preview by default
- **GIVEN** the app is running in the desktop home memo list on Windows or macOS
- **AND** the window width is at least the shared wide desktop threshold of `1360`
- **WHEN** the user clicks a memo card
- **THEN** the memo list SHALL select that memo and open or update the right-side desktop preview pane
- **AND** it SHALL NOT navigate directly to `MemoDetailScreen` for the ordinary single-click action

#### Scenario: Expanded non-wide desktop width can support preview without default click-to-preview
- **GIVEN** the app is running in the desktop home memo list on Windows or macOS
- **AND** the window width is at least `1200` and less than `1360`
- **WHEN** the memo list builds its desktop layout state
- **THEN** the right-side preview pane SHALL be available as a supported secondary pane
- **AND** ordinary memo single-click behavior MAY remain non-preview until the preview pane is already active or explicitly opened

#### Scenario: Supported desktop inline compose resize is not hidden by entry flags
- **GIVEN** the app is running in the desktop home memo list on a platform that supports inline compose resize
- **WHEN** the memo list is reached from the initial home route, drawer memos route, or desktop utility return route
- **THEN** the inline compose resize capability SHALL use the same shared desktop decision
- **AND** the behavior MUST NOT disappear because one route omitted `enableDesktopResizableHomeInlineCompose`

#### Scenario: Platform shell chrome remains platform-specific
- **WHEN** shared desktop preview layout tiers or inline compose resize capability are applied outside the original Windows-only path
- **THEN** macOS titlebar, native traffic-light safe area, native close/minimize/zoom semantics, and hybrid titlebar behavior SHALL remain governed by macOS shell policy
- **AND** the implementation MUST NOT introduce Windows-style Flutter-drawn window controls into the default macOS home shell

### Requirement: Desktop shell host SHALL consume desktop kernel policies

The desktop shell host and platform shell implementations SHALL consume desktop kernel policy outputs for route-adjacent layout, titlebar navigation, window command behavior, secondary panes, modal surfaces, and destination shell slots. Feature pages SHALL not own those kernel rules.

#### Scenario: Shell receives shared layout policy
- **WHEN** `DesktopShellHost`, `DesktopDestinationShell`, `WindowsDesktopPageShell`, or `AppleMacosPageShell` resolves navigation mode, sidebar/rail/overlay behavior, titlebar visibility, or secondary pane support
- **THEN** it SHALL use the shared desktop layout/titlebar/surface policy output
- **AND** it SHALL NOT duplicate separate Windows and macOS breakpoint rules for the same semantic behavior

#### Scenario: Shell close control is activated
- **WHEN** a shell-rendered main-window close control is activated
- **THEN** the shell SHALL invoke the desktop window close command seam
- **AND** the resulting lifecycle side effect SHALL be handled by the shared close coordinator or an injected application-level callback

#### Scenario: Feature page participates in desktop shell
- **WHEN** a feature page provides title, actions, body, secondary pane, modal surface, search action, compose action, or preview slots to a desktop shell
- **THEN** the feature page SHALL provide semantic widgets and callbacks
- **AND** the feature page SHALL NOT decide platform-specific desktop kernel behavior that belongs to shell or desktop policy

### Requirement: Desktop shell surface inputs SHALL be honored or explicitly unsupported

Desktop shell implementations SHALL either honor provided secondary pane, modal surface, motion, resize, and barrier inputs or expose a documented unsupported capability/fallback for that platform.

#### Scenario: Secondary pane input reaches platform shell
- **WHEN** a feature passes `secondaryPane`, `secondaryPaneVisible`, `secondaryPaneWidth`, `secondaryPanePresentation`, `secondaryPaneMotionSpec`, or `onSecondaryPaneWidthChanged` through a desktop shell seam
- **THEN** the platform shell SHALL apply the relevant policy output for the current platform
- **AND** it SHALL NOT accept those inputs while ignoring motion or resize behavior without an explicit capability fallback

#### Scenario: Modal input reaches platform shell
- **WHEN** a feature passes `modalSurface`, `modalSurfaceVisible`, `modalBarrierColor`, `modalBarrierBlurSigma`, or `modalSurfaceMotionSpec` through a desktop shell seam
- **THEN** the platform shell SHALL apply modal surface policy consistently for that platform
- **AND** tests SHALL cover both Windows and macOS behavior or an explicit unsupported/fallback path
