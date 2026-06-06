## 1. 搜索作用域

- [x] 1.1 在 `MemoSearchCoordinator` 远端候选转为 `LocalMemo` 前增加当前用户 ownership 最终过滤，保留当前用户 memo 和已存在本地 DB 的匹配 memo。
- [x] 1.2 确认 legacy/fallback 搜索路径仍经过同一最终过滤，不让服务端忽略 filter 时返回的探索页或其他用户 memo 进入主页结果。
- [x] 1.3 如实现必须修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，先向用户请求 API 相关编辑批准，再继续 API 适配和测试。

## 2. 空白等待态

- [x] 2.1 在主页搜索 view-state 或列表控制 seam 中表达“新 query 首次加载且尚无当前 query 结果”的 blank waiting 状态。
- [x] 2.2 调整 `MemosListScreen`/`MemosListScreenBody` 渲染逻辑，使 blank waiting 时内容区不显示旧 memo、skeleton、无结果提示或错误提示。
- [x] 2.3 保持同 query 刷新/分页加载可继续显示当前 query 已有结果，避免把正常增量加载误判为空白等待。
- [x] 2.4 确保多语言保持一致。

## 3. Guardrails 与测试

- [x] 3.1 在 `test/state/memos/memo_search_consistency_test.dart` 或相邻测试中增加远端返回 `users/2` memo 时主页远端搜索不输出该 memo 的断言。
- [x] 3.2 增加远端-only memo 缺少/无法验证 `creator` 时不进入主页搜索结果的断言，并保留当前用户 memo 可搜索的正向断言。
- [x] 3.3 在 `test/features/memos` 的 view-state/body/screen 测试中覆盖新 query loading 时不渲染旧 memo 列表、不提前显示无结果态。
- [x] 3.4 确认新增测试不引入新的 `state -> features` 依赖，并在必要时运行现有 architecture guardrail。

## 4. 验证

- [x] 4.1 运行相关 focused tests：`flutter test test/state/memos/memo_search_consistency_test.dart` 以及新增或更新的 `test/features/memos/...` 测试。
- [x] 4.2 如触及 API 适配，运行 `flutter test test/data/api --reporter expanded`。
- [x] 4.3 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 4.4 记录仍未覆盖的风险，例如旧服务端缺失 creator 导致 remote-only 当前用户 memo 只能等同步入本地库后显示。
  - 记录：本次未修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，因此未运行 API 兼容测试；旧服务端若返回缺失 creator 的 remote-only 当前用户 memo，主页搜索会优先保护作用域，等该 memo 同步进入本地库后才会作为本地库匹配显示。
