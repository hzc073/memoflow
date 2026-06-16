## Context

主笔记列表当前的搜索状态集中在 `MemosListHeaderController` 的 `searchController`、`searching`、quick search、AI search 和 advanced filters 上。`MemosListScreen.build()` 直接读取 `_searchController.text` 并传给 `buildMemosListScreenQueryState`，因此每次输入变化都会改变 `queryKey`，触发 `remoteSearchMemosProvider` 或本地 `memosStreamProvider` 重新查询。

0611 的 `optimize-keyword-search-latency-feedback` 已经把本地 2000+ 笔记场景的搜索执行成本降下来，但它不改变触发模型。当前触发模型仍会在用户输入 `memoflow` 时产生多次中间查询，例如 `m`、`me`、`memof`、`memoflow`，并且远端兼容失败时会重复进入 fallback。

目标状态是把搜索拆成两个层次：

```text
┌──────────────────────────────┐
│ draft query                  │
│ 搜索框当前文本，用户可自由编辑 │
└──────────────┬───────────────┘
               │ explicit submit
               ▼
┌──────────────────────────────┐
│ submitted query              │
│ provider 查询与结果高亮的来源  │
└──────────────┬───────────────┘
               ▼
remoteSearchMemosProvider / memosStreamProvider
```

## Goals / Non-Goals

**Goals:**

- 关键词搜索 MUST 由显式提交触发，而不是由 `TextEditingController` 每次变更触发。
- 搜索 UI MUST 支持清晰状态：搜索中、结果、空结果、错误；未提交草稿只影响输入框和搜索 action，不切换内容区页面。
- 移动端右侧 `取消` action 改为 `搜索` action；关闭搜索由左侧返回/关闭入口负责。
- 桌面搜索入口保持等价行为：打开搜索不执行查询，提交草稿才执行查询。
- `submitted query` MUST 成为 provider 查询、搜索历史记录和 memo highlight 的一致来源。
- 实施时应改善局部模块性：搜索提交状态集中在 `MemosListHeaderController` 或同层 seam，不继续让 widget build 直接把 draft text 变成查询。

**Non-Goals:**

- 不改变 `MemoSearchMatcher`、`MemoSearchDocumentBuilder` 或 literal substring/CJK 搜索语义。
- 不改变 0611 的 `memo_search_dirty` 维护、SQLite candidate index 或 advanced filter pushdown。
- 不改变 AI 搜索的显式触发规则；AI 搜索仍需要独立用户动作。
- 不修改 `memos_flutter_app/lib/data/api`、API request/response model、route adapter 或 version compatibility logic。
- 不解决远端 `creator_id` filter 兼容失败；该问题应由单独 API 兼容 change 处理。

## Decisions

### 1. `draft query` 与 `submitted query` 分离

`MemosListHeaderController` 应拥有或暴露 `submittedSearchQuery`。`searchController.text` 仅表示 draft；`buildMemosListScreenQueryState` 应接收 submitted query 作为 `searchQuery`，而不是直接使用 draft。

状态关系：

```text
Normal
  │ open search
  ▼
SearchOpenIdle                 draft='', submitted=''
  │ type
  ▼
SearchOpenIdle                 draft!='', submitted unchanged, content unchanged
  │ submit
  ▼
SearchLoading                  submitted=draft, provider loading
  │ provider returns
  ├──▶ SearchResults
  ├──▶ SearchEmpty
  └──▶ SearchError
```

原因：这是减少无效查询的最小结构性改变。相比在 provider 层 debounce 或 throttle，它能直接表达用户意图，并避免远端 API 每个字符都被调用。

清空输入是例外的 reset 行为：当 draft 被清空到空字符串时，controller 应同时清空 submitted query，使内容区回到未搜索状态，而不是继续显示上一轮关键词搜索结果。

替代方案：

- Debounce 输入：可减少请求但仍是“输入即搜索”，无法满足点击后才搜索，也无法完全避免中间 query。
- 只在 UI 按钮层拦截：如果 `build()` 仍读取 `_searchController.text`，仍会触发 provider 查询，属于表面修复。

### 2. 提交入口必须统一

显式提交入口包括：

- 移动端右侧 `搜索` action。
- 搜索框键盘 `TextInputAction.search` / Enter submit。
- 搜索历史记录选择。
- 推荐标签选择。
- 桌面标题栏搜索 action 或等价提交按钮/快捷键。

这些入口最终都应调用同一个 submit seam，执行：trim draft、更新 `submittedSearchQuery`、记录 search history、关闭 AI search active state、通知 UI 刷新。

原因：统一入口可以防止历史记录、标签建议、键盘提交和按钮提交之间行为不一致。

### 3. 草稿变更不能改变内容区

当 `draft query` 与 `submitted query` 不同时，系统不得启动新查询，也不得切换到新的提示/待提交页面。内容区保持上一次状态：

```text
submitted=''       -> 继续展示 search landing / recent searches
submitted='alpha'  -> 继续展示 alpha 的结果/空状态/错误/刷新状态
```

这要求结果语义始终来自 submitted query：

```text
draft='beta', submitted='alpha'
visible content = alpha content
highlight query = alpha
provider query = alpha
```

原因：用户明确要求“搜索框内容改变不导致页面变化”，因此 draft 只代表待提交输入，不代表内容区状态。搜索按钮和键盘提交是唯一改变关键词搜索内容区的入口。

### 4. 搜索中状态应是页面状态，不只是顶部线性进度条

当前 `showBlankSearchWaiting` 可能让页面空白等待。新的搜索中状态应在首次加载当前 submitted query 时显示明确 loading UI，例如居中 `CircularProgressIndicator` 加本地化文字 `搜索中...`。当同一 submitted query 因 DB changes 刷新且已有结果时，可以保留旧结果并显示轻量 `LinearProgressIndicator`。

原因：首次搜索和同查询刷新是不同体验。首次搜索没有结果可保留，应给明确页面反馈；同查询刷新保留旧结果更稳定。

### 5. 高级筛选和 quick search 暂不改为草稿态

本 change 只要求关键词输入显式提交。高级筛选 sheet 的确认、quick search chip、shortcut/tag/day filter 本身已经是显式用户动作，可以继续立即影响 query state。

原因：把所有筛选都引入 draft/apply 双态会显著扩大范围，增加 UI 状态复杂度，不是解决输入高频搜索的必要条件。

### 6. 模块性边界

当前架构阶段是 `evolve_modularity`。本 change 触碰 `features/memos` 中较大的 screen/controller/widget 区域，实施时应保持以下边界：

- `MemosListHeaderController` 或同层 feature controller owns draft/submitted search state。
- `MemosListScreenViewState` 只接收已提交 query 和必要 UI flags，不自己读取 controller。
- `state/memos` providers 不依赖 `features/memos` 类型。
- `data/db` 不依赖 UI state。
- 搜索提交规则的测试优先放在 controller/view-state/widget 层，避免把提交语义塞进 data layer。

## Risks / Trade-offs

- [Risk] 用户习惯了边输入边看到结果，显式提交会改变交互节奏。
  → Mitigation：搜索按钮、键盘 Search、历史/标签点击都作为快速提交入口；待提交状态应简洁明确。

- [Risk] draft 与 submitted 不一致时，内容区仍保持旧 submitted 状态，用户可能以为已经搜索了 draft。
  → Mitigation：provider 查询、高亮、AI 搜索入口都只使用 submitted；移动端 primary action 明确显示为 `搜索`，用户点击后才改变结果。

- [Risk] 桌面和移动端搜索栏实现不同，可能出现平台行为不一致。
  → Mitigation：抽象统一 submit seam，并增加移动、Windows、macOS 相关 widget/controller 测试。

- [Risk] 搜索高亮如果继续使用 draft，会出现“结果来自 submitted，但高亮来自 draft”的错配。
  → Mitigation：highlight query MUST 使用 submitted query。

- [Risk] 新增搜索中 copy 会触碰多语言文件。
  → Mitigation：优先复用已有 `msg_bridge_action_searching`；若新增更准确文案，必须同步所有 locale 和生成文件。
