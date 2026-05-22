## ADDED Requirements

### Requirement: 桌面外壳宿主 SHALL own titlebar navigation-context policy
桌面外壳宿主 SHALL 根据平台、navigation mode 和页面层级决定 titlebar leading title 是否渲染，而不是要求功能页面自行判断窗口控件、安全区或侧边栏状态。

#### Scenario: 功能页面提供语义 title
- **WHEN** 功能页面向 `DesktopShellHost` 或等价桌面外壳提供 `leadingTitle`、`center`、`trailing`、command bar 或 body slot
- **THEN** 功能页面 SHALL 只表达语义内容，title visibility 和 chrome-safe placement MUST 由桌面外壳宿主处理

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
桌面外壳宿主 SHALL include focused verification or guardrails so future feature pages do not reintroduce page-local titlebar padding and duplicated macOS top-leading titles.

#### Scenario: 新桌面顶级页面接入外壳
- **WHEN** a new top-level drawer destination is added to a desktop shell
- **THEN** verification SHALL ensure it follows the centralized titlebar navigation-context policy instead of adding macOS-specific titlebar padding in the feature page

#### Scenario: shell policy changes
- **WHEN** title visibility, navigation mode routing, or desktop window chrome policy changes
- **THEN** focused tests or guardrails SHALL cover macOS expanded sidebar suppression, secondary-route native close dispatch, and at least one title-visible fallback mode
