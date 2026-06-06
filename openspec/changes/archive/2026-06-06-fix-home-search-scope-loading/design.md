## Context

主页 memo 列表当前根据 `MemosListScreenQueryState.sourceKind` 在本地 stream、远端搜索、快捷搜索和 AI 搜索之间切换。非空关键词默认进入 `remoteSearchMemosProvider`，由 `MemoSearchCoordinator` 合并本地匹配和远端候选后转成 `LocalMemo` 给主页卡片渲染。

两个问题来自同一个边界：

- UI 在新 query 的 provider 还没有值时继续使用 `_animatedMemos`，因此搜索中仍可能显示上一批全量笔记。
- 远端候选在仍保留 `Memo.creator` 时没有形成“主页只显示我的 memo”的最终可见结果规则；一旦转成 `LocalMemo`，creator/ownership 信息丢失，主页卡片会按普通可编辑 memo 处理。

当前架构阶段为 `evolve_modularity`。本变更触及 `features/memos` 与 `state/memos`，实现时必须保持依赖方向不变：UI 只渲染搜索状态，搜索作用域和远端候选过滤仍由 `state/memos` 或更低层 seam 负责，不新增 `state -> features` 依赖。

## Goals / Non-Goals

**Goals:**

- 主页非空关键词搜索只展示当前用户自己的 memo，不展示探索页或其他用户 memo。
- 新 query 首次加载时内容区为空白等待态，不显示旧列表、skeleton、无结果文案或探索内容。
- 搜索完成后仍保持现有结果、空状态、错误状态语义。
- 用测试覆盖搜索作用域和等待态，防止后续回归。

**Non-Goals:**

- 不改变探索页浏览/搜索逻辑。
- 不把探索 memo 作为只读结果显示在主页搜索中。
- 不引入新的搜索索引、AI 搜索语义或商业/private 功能。
- 不在未获用户明确批准前修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。

## Decisions

### 1. 主页搜索采用“不可证明为我的 memo 就不展示”的最终过滤

远端请求仍可尽量带 `creator_id`、`creator` 或 `parent` 等服务端过滤条件，但可见结果不能只信任服务端。`MemoSearchCoordinator` 应在远端 `Memo` 转为 `LocalMemo` 之前执行最终作用域判断：

- `memo.creator` 与当前账号 user name/user id 匹配时可保留。
- memo 已存在当前工作区本地 DB 且满足 query/filter 时可保留，因为本地 DB 是主页“我的笔记库”的来源。
- 远端-only memo 如果 creator 缺失、无法解析、或与当前账号不匹配，则不进入主页搜索结果。

备选方案是把其他用户 memo 显示为只读卡片，但这会让主页搜索混入探索语义，并需要给 memo 卡片、详情页、编辑入口增加额外只读分支。用户已经明确希望“不要搜索出来”，因此不采用只读方案。

### 2. 等待态在 UI 层按 query key 判断，不改变搜索 provider 语义

主页列表应区分“当前可见列表属于哪个 query key”和“新 query 的 provider 是否已有值”。当 query key 改变且新 provider 正在首次加载时，内容区进入空白等待态：

```
旧 query 结果
   │
输入新关键词
   │
   ├─ provider loading && 新 query 尚无 value
   ▼
空白等待态
   │
   ├─ 有结果 -> 结果列表
   ├─ 无结果 -> 空结果态
   └─ 错误   -> 错误态
```

这个行为应限制在新 result set 的首次加载，避免同一 query 的刷新或分页加载无谓清空已有结果。UI 只需要知道是否应显示 blank waiting，不应把搜索匹配或 ownership 逻辑放进 widget。

### 3. 不扩大 `LocalMemo` 模型来表达探索/只读来源

因为目标是“不展示非我的 memo”，实现应优先在远端 `Memo` 尚未转为 `LocalMemo` 前过滤掉非当前用户候选。给 `LocalMemo` 增加 creator/source/readOnly 字段会扩大本地模型和卡片行为表面，且容易把探索语义泄漏进主页编辑链路。

### 4. 用测试作为本阶段的模块化 guardrail

本变更不需要新增架构层，但必须收紧测试：

- `test/state/memos/...` 覆盖远端返回其他用户 memo 时主页远端搜索不会输出该 memo。
- `test/features/memos/...` 覆盖新 query loading 时不渲染旧 memo 列表。
- 若实现触及 API 适配层，先请求用户批准，再补充 `test/data/api` 兼容测试。

这些测试是 `evolve_modularity` 阶段的 scoped guardrail，防止 `state/memos` 搜索边界和 `features/memos` UI 状态再次漂移。

## Risks / Trade-offs

- [Risk] 某些旧服务端返回远端 memo 时 creator 字段缺失，导致主页搜索不展示远端-only 的当前用户 memo。
  [Mitigation] 本地已同步 memo 仍可通过本地 DB 结果展示；远端-only 且 ownership 不可证明时优先保护主页边界。

- [Risk] 如果只在请求 filter 中加 creator 条件，服务端版本差异仍可能返回探索内容。
  [Mitigation] 必须保留客户端最终过滤，服务端过滤只能作为优化。

- [Risk] UI 清空旧列表可能让快速网络下出现短暂空白闪烁。
  [Mitigation] 只在 query key 改变且新 provider 首次加载时清空；同 query 刷新和分页加载可继续保留当前结果。

- [Risk] 搜索 UI 状态修复若直接散落在 screen build 中会增加页面复杂度。
  [Mitigation] 优先在 view-state/animated-list controller seam 中表达 blank waiting 判断，widget 只负责渲染。
