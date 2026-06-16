## 1. 搜索状态建模

- [x] 1.1 在 `MemosListHeaderController` 或同层 feature seam 中引入 `submittedSearchQuery`，保留 `searchController.text` 作为 `draft query`。
- [x] 1.2 增加统一 submit 方法，负责 trim draft、拒绝空查询、更新 `submittedSearchQuery`、记录 search history、清理 AI active state 并 `notifyListeners()`。
- [x] 1.3 调整 close-search 语义，确保退出搜索时清理 draft/submitted keyword search state、quick search state、AI search state 和 advanced filters，保持现有关闭搜索预期。
- [x] 1.4 调整 `applySearchQuery`，让历史记录和推荐标签选择同时更新 draft 与 submitted query，并复用统一 submit seam。

## 2. QueryState 与结果来源

- [x] 2.1 调整 `buildMemosListScreenQueryState` 调用链，使 provider 查询使用 `submittedSearchQuery`，而不是直接使用 `_searchController.text`。
- [x] 2.2 在 view-state 或 screen 层表达 draft/submitted 是否不一致，同时确保 draft 变化不改变内容区页面。
- [x] 2.3 调整 memo card search highlight 来源，使用 `submittedSearchQuery` 而不是 draft text。
- [x] 2.4 保持 advanced filters、quick search、shortcut、tag/day filter 的现有显式动作行为，不把这些筛选扩大为 draft/apply 双态。

## 3. UI 行为

- [x] 3.1 将移动端搜索模式右侧 `取消` action 改为 `搜索` action，并让它提交当前 draft；关闭搜索继续由左侧返回/关闭入口负责。
- [x] 3.2 调整 `MemosListTopSearchField`，让键盘 Search/Enter 调用统一 submit seam；清空输入时重置 submitted query 并回到未搜索状态。
- [x] 3.3 调整 Windows 标题栏搜索展开态，使其具备等价提交语义，不把展开/关闭搜索与提交搜索混在一起。
- [x] 3.4 调整 macOS 标题栏搜索展开态，使其具备等价提交语义，不把关闭搜索作为唯一右侧 action。
- [x] 3.5 当 draft 非空但未提交时，保持当前内容区不变；不得启动查询或切换到 draft-only 页面。

## 4. 搜索中状态

- [x] 4.1 将首次 submitted keyword search 的 loading 从空白等待改为明确页面状态，至少包含 loading indicator 和本地化搜索中文案。
- [x] 4.2 保留同一 submitted query 刷新时的轻量加载反馈，例如已有结果上方的 `LinearProgressIndicator`。
- [x] 4.3 评估是否复用 `msg_bridge_action_searching`；若新增更准确文案，补齐所有 `strings*.i18n.yaml` 和生成的 `strings.g.dart`。

## 5. 模块性与边界

- [x] 5.1 确保 submit/draft/submitted 状态集中在 feature controller 或同层 seam，避免继续在 `MemosListScreen.build()` 中直接把 controller text 解释成 provider query。
- [x] 5.2 确认未新增 `state -> features`、`application -> features`、`core -> state|application|features` 依赖。
- [x] 5.3 不修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`；如后续要处理远端 `creator_id` 兼容失败，另建 API change 并先取得用户审批。

## 6. 测试与验证

- [x] 6.1 更新 `test/features/memos/memos_list_header_controller_test.dart`，覆盖输入 draft 不提交、按钮/键盘提交、空 draft 不搜索、清空输入 reset、关闭搜索清理状态。
- [x] 6.2 更新 `test/features/memos/memos_list_screen_view_state_test.dart`，覆盖 provider query 使用 submitted query、draft/submitted 不一致不改变 landing/content。
- [x] 6.3 更新 `test/features/memos/widgets/memos_list_screen_body_test.dart`，覆盖移动端右侧 `搜索` action、搜索中页面状态、draft 变化保持当前内容区。
- [x] 6.4 更新 Windows/macOS title bar widget tests，覆盖搜索展开态提交与关闭行为。
- [x] 6.5 运行 focused tests：`flutter test test/features/memos/memos_list_header_controller_test.dart test/features/memos/memos_list_screen_view_state_test.dart test/features/memos/widgets/memos_list_screen_body_test.dart --reporter expanded`。
- [x] 6.6 运行相关搜索回归：`flutter test test/data/db/app_database_search_test.dart test/state/memos/memo_search_consistency_test.dart --reporter expanded`。
- [x] 6.7 运行 `flutter analyze`。
- [x] 6.8 运行 `openspec validate require-explicit-memo-search-submit --type change --strict --no-interactive`。
