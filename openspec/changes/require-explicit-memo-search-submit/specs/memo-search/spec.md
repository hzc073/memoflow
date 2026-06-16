## ADDED Requirements

### Requirement: Main memo keyword search requires explicit submit
主笔记列表的关键词搜索 SHALL 区分用户正在编辑的 `draft query` 和实际用于查询的 `submitted query`。用户编辑 `draft query` MUST NOT 自动启动新的关键词搜索、远端搜索请求或本地 memo provider 查询；只有显式提交后，`submitted query` 才能更新并驱动搜索结果。

#### Scenario: Typing does not start keyword search
- **GIVEN** 用户已经打开主笔记列表搜索框
- **WHEN** 用户在搜索框中输入或删除字符但没有提交搜索
- **THEN** 系统 MUST 只更新 `draft query`
- **AND** 系统 MUST NOT 因该输入变化启动新的主笔记关键词搜索 provider 查询

#### Scenario: Search button submits draft query
- **GIVEN** 搜索框中的 `draft query` 去除首尾空白后非空
- **WHEN** 用户点击搜索栏右侧 `搜索` action
- **THEN** 系统 MUST 将 trimmed `draft query` 设为 `submitted query`
- **AND** 系统 MUST 使用该 `submitted query` 启动主笔记关键词搜索
- **AND** 系统 MUST 将该 `submitted query` 作为搜索历史记录候选

#### Scenario: Keyboard search submits draft query
- **GIVEN** 搜索框中的 `draft query` 去除首尾空白后非空
- **WHEN** 用户通过键盘 Search/Enter 提交搜索框
- **THEN** 系统 MUST 执行与点击 `搜索` action 相同的提交行为

#### Scenario: Empty draft cannot start search
- **GIVEN** 搜索框中的 `draft query` 去除首尾空白后为空
- **WHEN** 用户点击 `搜索` action 或通过键盘提交
- **THEN** 系统 MUST NOT 启动关键词搜索
- **AND** 系统 SHOULD 保持搜索 landing 或待输入状态

#### Scenario: Clearing draft resets submitted search
- **GIVEN** 当前存在非空 `submitted query`
- **WHEN** 用户清空搜索框内容，使 trimmed `draft query` 变为空
- **THEN** 系统 MUST 清空 `submitted query`
- **AND** 系统 MUST return to the unsearched search state
- **AND** 系统 MUST NOT keep showing the previous keyword search result page

### Requirement: Submitted query is the visible search source of truth
主笔记列表 SHALL 使用 `submitted query` 作为 provider 查询、结果列表 key、搜索结果高亮和 AI 搜索入口的关键词来源。`draft query` 仅用于输入框显示和搜索 action enablement，不得改变内容区页面或被用作已执行搜索结果的语义来源。

#### Scenario: Draft edits keep current content unchanged
- **GIVEN** 当前 `submitted query` 是 `alpha`
- **AND** 搜索框 `draft query` 被用户编辑为 `beta` 但尚未提交
- **WHEN** 页面展示内容区
- **THEN** 系统 MUST keep the current content state unchanged
- **AND** 系统 MUST continue using `alpha` for provider query, result list key, highlight, and AI search source
- **AND** 系统 MUST NOT show a new draft-only search/pending page because of the draft edit

#### Scenario: Empty submitted query landing remains while typing
- **GIVEN** 用户已打开搜索模式
- **AND** 当前 `submitted query` 为空
- **WHEN** 用户在搜索框输入非空 `draft query` 但尚未提交
- **THEN** 系统 MUST keep showing the existing search landing or equivalent current content state
- **AND** 系统 MUST NOT start keyword search until explicit submit

#### Scenario: Highlight uses submitted query
- **GIVEN** 当前可见搜索结果来自 `submitted query` `alpha`
- **AND** 搜索框 `draft query` 是未提交的 `beta`
- **WHEN** memo card 渲染搜索高亮
- **THEN** 系统 MUST 使用 `alpha` 作为高亮查询
- **AND** 系统 MUST NOT 使用未提交的 `beta` 高亮现有结果

#### Scenario: History and suggested tags submit explicitly
- **WHEN** 用户选择搜索历史记录或推荐标签搜索建议
- **THEN** 系统 MUST 同时更新 `draft query` 和 `submitted query`
- **AND** 系统 MUST 使用该值启动关键词搜索

### Requirement: Search UI exposes submit and loading states
主笔记列表搜索 UI SHALL 提供明确的提交 action 和搜索中页面状态。移动端搜索模式下，右侧 primary action MUST 是 `搜索` 而不是 `取消`；关闭搜索 MUST 由左侧返回/关闭入口或平台等价关闭入口负责。

#### Scenario: Mobile search action is submit
- **GIVEN** 主笔记列表处于移动端搜索模式
- **WHEN** 搜索栏显示右侧 primary action
- **THEN** 该 action MUST 表示 `搜索`
- **AND** 点击该 action MUST 提交当前 `draft query`
- **AND** 该 action MUST NOT 关闭搜索模式

#### Scenario: Search can still be closed
- **GIVEN** 主笔记列表处于搜索模式
- **WHEN** 用户点击左侧返回/关闭入口或平台等价关闭入口
- **THEN** 系统 MUST 退出搜索模式
- **AND** 系统 MUST 清理 draft/submitted keyword search state、quick search state、AI search state 和 advanced search state according to existing close-search semantics

#### Scenario: Initial submitted search shows loading page
- **GIVEN** 用户提交了非空 `submitted query`
- **AND** 当前 submitted query 尚无可展示结果
- **WHEN** 关键词搜索 provider 仍在加载
- **THEN** 系统 MUST 显示明确的搜索中页面状态
- **AND** 系统 MUST NOT 显示空白页面作为唯一反馈

#### Scenario: Same-query refresh may preserve visible results
- **GIVEN** 当前页面已经展示某个 `submitted query` 的结果
- **WHEN** 同一 `submitted query` 因本地数据库变化或同步刷新而重新加载
- **THEN** 系统 MAY 保留现有结果
- **AND** 系统 MUST 提供轻量加载反馈 if refresh is user-visible
