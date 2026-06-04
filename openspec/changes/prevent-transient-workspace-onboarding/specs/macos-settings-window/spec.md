## ADDED Requirements

### Requirement: Desktop settings workspace reload SHALL preserve active workspace identity
桌面设置窗口与主窗口之间的 workspace reload 通知 SHALL 保留 active workspace identity。当 settings 子窗口能读取到非空 `session.currentKey` 时，`desktop.main.reloadWorkspace` payload MUST 包含 `currentKey`，包括因 local library list 变化触发的通知。

#### Scenario: Local libraries change while current key is known
- **GIVEN** desktop settings window 已加载 session，且 `session.currentKey` 非空
- **WHEN** settings window 的 `localLibrariesProvider` 发生 key 集合变化并通知主窗口 reload workspace
- **THEN** `desktop.main.reloadWorkspace` payload MUST include `currentKey`
- **AND** 主窗口 SHALL 使用该 key 先恢复或对齐 session，再 reload local libraries

#### Scenario: Stale settings window is recreated
- **GIVEN** 旧 settings sub-window id 已失效，主窗口重新创建 settings window engine
- **WHEN** 新 settings window 完成 session/local library refresh 并向主窗口同步 workspace 状态
- **THEN** 同步过程 MUST NOT cause 主窗口把 active local workspace 误判为 absent
- **AND** 主窗口 MUST NOT 因 settings window 初始 provider 空状态而跳转到 onboarding 模式选择页

### Requirement: No-key workspace reload SHALL NOT clear or destabilize main workspace
当主窗口收到不包含 `currentKey` 的 `desktop.main.reloadWorkspace` 通知时，系统 SHALL 将其视为有限范围刷新请求。该请求 MUST NOT 单独清空主窗口 `session.currentKey`，也 MUST NOT 单独触发用户可见 onboarding 跳转。

#### Scenario: No-key local library reload arrives before keyed reload
- **GIVEN** 主窗口已有 active local workspace
- **WHEN** 主窗口先收到不包含 `currentKey` 的 workspace reload，随后收到包含 `currentKey` 的 reload
- **THEN** 第一笔 reload MUST NOT clear active session key
- **AND** 第一笔 reload MUST NOT make `MainHomePage` render onboarding before the keyed reload can restore workspace state

### Requirement: Settings workspace sync SHALL remain boundary-safe
settings workspace sync 修复 SHALL 复用现有 desktop channel、`DesktopWindowManager`、`DesktopSettingsWindowApp` 和 provider/repository seams。实现 MUST NOT 新增 lower-layer imports from `features/*`，也 MUST NOT 引入 commercial/private behavior。

#### Scenario: Workspace sync implementation is checked
- **WHEN** settings workspace sync、route gate 或 local library reload 代码被修改
- **THEN** 变更 SHALL NOT introduce new `application -> features`、`state -> features` 或 `core -> features` dependencies
- **AND** 变更 SHALL include focused tests or guardrails covering the workspace sync behavior
- **AND** public code MUST NOT include subscription、billing、entitlement、receipt、paywall、StoreKit、private overlay 或 paid-feature branching logic
