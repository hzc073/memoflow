## ADDED Requirements

### Requirement: Home keyword search is scoped to the current user's memo library
主页非空关键词搜索 SHALL 只展示当前用户自己的 memo。远端搜索返回的探索页 memo、其他用户 memo、或无法证明属于当前用户的 remote-only memo MUST NOT 成为主页搜索可见结果，即使它们满足关键词、tag、state、date range 或 advanced filters。

#### Scenario: Remote search returns another user's memo
- **GIVEN** 当前账号为 `users/1`
- **AND** 主页搜索 query 非空
- **WHEN** 远端搜索返回 `creator` 为 `users/2` 的 memo
- **THEN** 该 memo MUST NOT 出现在主页搜索结果中

#### Scenario: Remote-only candidate has missing or untrusted creator
- **GIVEN** 当前账号为 `users/1`
- **AND** 远端候选 memo 不存在于当前工作区本地 DB
- **WHEN** 该远端候选缺少可验证的 `creator` 或其 `creator` 无法与当前账号匹配
- **THEN** 该 memo MUST NOT 出现在主页搜索结果中

#### Scenario: Current user's memo remains searchable
- **GIVEN** 当前账号为 `users/1`
- **AND** 主页搜索 query 非空
- **WHEN** 远端搜索返回 `creator` 为 `users/1` 且满足当前关键词和筛选条件的 memo
- **THEN** 该 memo SHALL 出现在主页搜索结果中

#### Scenario: Local memo library matches still supplement remote misses
- **GIVEN** 当前工作区本地 DB 中存在满足当前关键词和筛选条件的 memo
- **WHEN** 远端搜索没有返回该 memo
- **THEN** 主页搜索 SHALL 继续展示该本地 memo

#### Scenario: Explore search remains separate
- **WHEN** 用户在探索页浏览或搜索公开 memo
- **THEN** 探索页 SHALL 继续使用探索页自己的结果流
- **AND** 主页搜索的当前用户作用域规则 MUST NOT 移除探索页中的公开结果

### Requirement: Home keyword search uses a blank waiting state for first results
主页非空关键词搜索 SHALL 在新 query 的首次结果返回前显示空白等待态。等待期间内容区 MUST NOT 展示上一 query 的 memo、默认全量 memo、skeleton cards、无结果提示或错误提示；搜索框、筛选入口和搜索 chrome MAY 保持可见。

#### Scenario: New query starts loading after full list is visible
- **GIVEN** 主页正在展示默认全量 memo 列表
- **WHEN** 用户输入非空搜索 query 且该 query 的首次结果仍在加载
- **THEN** 主页内容区 MUST 进入空白等待态
- **AND** 默认全量 memo 列表 MUST NOT 继续显示为搜索结果

#### Scenario: Query changes while previous search results are visible
- **GIVEN** 主页正在展示 query `alpha` 的搜索结果
- **WHEN** 用户将搜索 query 改为 `beta` 且 `beta` 的首次结果仍在加载
- **THEN** 主页内容区 MUST 进入空白等待态
- **AND** query `alpha` 的结果 MUST NOT 继续显示

#### Scenario: Search completes with results
- **GIVEN** 主页内容区处于非空 query 的空白等待态
- **WHEN** 当前 query 搜索完成并返回至少一个可见 memo
- **THEN** 主页内容区 SHALL 显示当前 query 的结果列表

#### Scenario: Search completes with no results
- **GIVEN** 主页内容区处于非空 query 的空白等待态
- **WHEN** 当前 query 搜索完成且没有可见 memo
- **THEN** 主页内容区 SHALL 显示搜索无结果状态
- **AND** 无结果状态 MUST NOT 在首次加载完成前出现

#### Scenario: Same-query refresh can preserve visible results
- **GIVEN** 主页已经展示当前 query 的搜索结果
- **WHEN** 同一 query 触发刷新或分页加载
- **THEN** 主页 MAY 保留当前 query 的已有结果
- **AND** 任何加载反馈 MUST NOT 混入其他 query 或默认全量 memo
