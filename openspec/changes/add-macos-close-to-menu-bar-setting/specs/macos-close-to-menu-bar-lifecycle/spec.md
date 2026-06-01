## ADDED Requirements

### Requirement: macOS close-to-menu-bar preference SHALL default on and remain platform-scoped
系统 SHALL 提供 macOS 专属的关闭主窗口后保留在菜单栏运行偏好。该偏好 SHALL 对新安装和缺失该字段的既有本地偏好默认开启，并 SHALL NOT 复用 `windowsCloseToTray` 作为存储字段、UI 状态或业务判断来源。

#### Scenario: New preferences use enabled default
- **WHEN** macOS 设备加载没有 macOS close-to-menu-bar 字段的 device preferences
- **THEN** 系统 SHALL 将该偏好解析为 enabled
- **AND** 不需要用户手动开启即可获得关闭主窗口后保留运行的行为

#### Scenario: Preference is macOS-specific
- **WHEN** 用户打开 Desktop settings
- **THEN** macOS close-to-menu-bar 设置 SHALL 只在 macOS desktop experience 中显示
- **AND** Windows close-to-tray 设置 SHALL 继续只在 Windows desktop experience 中显示

#### Scenario: Windows preference is not reused
- **WHEN** macOS close-to-menu-bar 行为被解析
- **THEN** 系统 SHALL 使用 macOS 专属偏好或等价中性 lifecycle policy 输入
- **AND** SHALL NOT 读取 `windowsCloseToTray` 来决定 macOS close behavior

### Requirement: macOS main-window close SHALL hide to menu bar when enabled
当 macOS close-to-menu-bar 偏好开启时，用户关闭主窗口 SHALL 隐藏主窗口并保留应用进程与菜单栏状态图标。该行为 SHALL NOT 触发 full-exit cleanup，也 SHALL NOT 让 Runner 因最后一个窗口关闭而自动退出。

#### Scenario: Main window close hides instead of quitting
- **GIVEN** app 在 macOS 主实例运行
- **AND** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户关闭主窗口
- **THEN** 系统 SHALL 隐藏主窗口
- **AND** 进程 SHALL 继续运行
- **AND** 菜单栏状态图标 SHALL 保持可用

#### Scenario: Hidden window is not minimized to Dock
- **GIVEN** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户关闭主窗口
- **THEN** 系统 SHALL NOT 将主窗口最小化为 Dock 中的窗口项
- **AND** 主窗口 SHALL 处于可由菜单栏恢复的 hidden state

#### Scenario: Secondary route gets first chance to close
- **GIVEN** macOS 主窗口内存在可关闭的 secondary route 或 guarded route
- **AND** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户关闭主窗口
- **THEN** 系统 SHALL 优先请求关闭该 secondary route
- **AND** 只有当 route 未处理关闭请求时，主窗口才 SHALL 隐藏到菜单栏

### Requirement: macOS menu-bar icon SHALL restore the main window
macOS 菜单栏状态图标 SHALL 在主窗口隐藏后继续响应打开 MemoFlow、打开设置、新建 Memo 等既有菜单动作；需要主窗口的动作 SHALL 先恢复并聚焦主窗口，再执行对应操作。

#### Scenario: User restores from menu-bar icon
- **GIVEN** 主窗口已通过 macOS close-to-menu-bar 行为隐藏
- **WHEN** 用户选择菜单栏图标菜单中的打开 MemoFlow
- **THEN** 系统 SHALL 显示主窗口
- **AND** 系统 SHALL 聚焦主窗口

#### Scenario: Menu-bar command foregrounds before action
- **GIVEN** 主窗口已隐藏
- **WHEN** 用户从菜单栏图标菜单选择打开设置或新建 Memo
- **THEN** 系统 SHALL 先恢复并聚焦主窗口
- **AND** SHALL 再执行目标 command

### Requirement: macOS explicit quit SHALL remain a full application exit
macOS close-to-menu-bar 行为 SHALL 只改变主窗口 close request；明确退出命令 SHALL 继续终止应用进程。通过 Dart desktop lifecycle seam 发起的退出（例如菜单栏状态图标退出）SHALL 在终止前执行可用的 bounded cleanup；native application menu Quit / `Cmd+Q` SHALL NOT 被转换为隐藏主窗口。

#### Scenario: Cmd+Q exits the app
- **GIVEN** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户按下 `Cmd+Q`
- **THEN** 系统 SHALL 执行 full application exit
- **AND** SHALL NOT 将该命令解释为隐藏主窗口

#### Scenario: Menu-bar exit exits the app
- **GIVEN** macOS close-to-menu-bar 偏好为 enabled
- **WHEN** 用户选择菜单栏状态图标菜单中的退出命令
- **THEN** 系统 SHALL 执行 full application exit
- **AND** 菜单栏状态图标 SHALL 在退出流程中释放

#### Scenario: Disabled preference does not hide to menu bar
- **GIVEN** app 在 macOS 主实例运行
- **AND** macOS close-to-menu-bar 偏好为 disabled
- **WHEN** 用户关闭主窗口
- **THEN** 系统 SHALL NOT 隐藏主窗口到菜单栏作为 close request 的结果
- **AND** close request SHALL 进入既有 native/full-exit 语义或等价的 application-owned exit path

### Requirement: macOS close-to-menu-bar lifecycle SHALL preserve public boundaries
macOS close-to-menu-bar 实现 SHALL 保持公共仓库边界与模块边界，不得引入商业能力分支或新的 lower-layer 到 feature UI 依赖。

#### Scenario: Public desktop lifecycle is changed
- **WHEN** macOS close-to-menu-bar lifecycle、settings row、Runner close behavior 或 menu-bar restore behavior 被实现
- **THEN** implementation SHALL NOT include subscription、billing、entitlement、StoreKit、receipt、paywall、private overlay、product ID 或 `AccessDecision.source` business branching logic

#### Scenario: Lifecycle tests protect macOS close behavior
- **WHEN** desktop lifecycle tests 或 architecture guardrails 运行
- **THEN** 它们 SHALL 覆盖 macOS enabled close-to-menu-bar、disabled close behavior、secondary route handling 和 explicit quit/full-exit 的分流语义
