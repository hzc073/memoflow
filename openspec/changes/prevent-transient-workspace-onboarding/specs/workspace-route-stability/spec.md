## ADDED Requirements

### Requirement: Workspace route gate SHALL preserve active workspace during transient reload
当 `session.currentKey` 非空且用户已有 active workspace identity 时，app route gate SHALL NOT 仅因当前帧 `currentLocalLibraryProvider` 为 `null` 就判定没有 workspace。系统 MUST 将本地库/session reload 期间的短暂不一致视为 pending 或 recoverable 状态，直到 active key 被明确清空，或稳定 reload 明确确认该 key 不存在。

#### Scenario: Local library reload temporarily misses active key
- **GIVEN** 用户当前处于 local workspace，且 `session.currentKey` 指向该本地库 key
- **WHEN** 本地库 reload、settings 子窗口同步或 storage 短暂读空导致当前帧无法匹配 `currentLocalLibraryProvider`
- **THEN** app route gate MUST NOT 渲染 `LanguageSelectionScreen` 或模式选择页
- **AND** 系统 SHALL 保持 startup placeholder、已有 home 内容或等价 pending 状态，直到 workspace 状态恢复或被稳定确认为不可用

#### Scenario: Explicit onboarding reset still works
- **GIVEN** 用户主动删除最后一个 workspace、退出到首次设置流程，或系统通过明确流程清空 `session.currentKey`
- **WHEN** device preferences 要求重新打开 onboarding
- **THEN** app route gate MAY 渲染 `LanguageSelectionScreen`
- **AND** 该行为 MUST 依赖明确的 session/preferences 状态变化，而不是一次 transient local library miss

### Requirement: Local library reload SHALL distinguish missing storage from explicit empty state
本地库 reload SHALL 区分 storage key 缺失、debug 临时读空、读错误和显式持久化空列表。已有非空本地库内存状态遇到 `StorageReadResult.empty()` 时，系统 MUST NOT 立即清空 active workspace；显式持久化的 empty libraries state MAY 清空本地库列表。

#### Scenario: Existing local libraries encounter empty storage read
- **GIVEN** `localLibrariesProvider` 已持有至少一个本地库
- **WHEN** reload 从 repository 获得 `StorageReadResult.empty()`
- **THEN** 系统 SHALL 保留已有本地库状态或进入可恢复 pending 状态
- **AND** 系统 SHOULD 记录诊断日志说明 empty read 被保守处理

#### Scenario: Explicit empty local library state is applied
- **GIVEN** 用户通过受控流程删除最后一个本地库，或 repository 读取到显式 JSON 空列表
- **WHEN** reload 完成
- **THEN** 系统 MAY 将本地库列表更新为空
- **AND** 如果没有任何 account 或 local library，onboarding reset SHALL 仍按既有显式流程执行

### Requirement: Workspace route stability SHALL be covered by focused tests
工作区路由稳定性 SHALL 有 focused tests 覆盖，防止 future reload、route gate 或 provider 改动重新引入 transient onboarding 跳转。

#### Scenario: Route gate test covers transient local workspace miss
- **WHEN** `MainHomePage` 或等价 route gate 在测试中接收到非空 `session.currentKey` 且本地库暂时无法匹配
- **THEN** 测试 SHALL 断言 `LanguageSelectionScreen` 不会出现
- **AND** 测试 SHALL 覆盖本地库恢复后 home route 可继续显示

#### Scenario: Provider reload test covers empty read protection
- **WHEN** `LocalLibrariesController` 在 previous state non-empty 时读取到 `StorageReadResult.empty()`
- **THEN** 测试 SHALL 断言 previous libraries 不会被一次 empty read 清空
