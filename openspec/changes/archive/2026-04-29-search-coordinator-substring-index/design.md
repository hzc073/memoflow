## Context

当前 memo search 已经在多个入口中逐步使用 `MemoSearchMatcher.matchesText` 做 literal substring 校验，但真正的搜索执行仍然分散在多处：

- `AppDatabase.listMemos` 同时混用 `FTS MATCH` 与 `LIKE`.
- `remoteSearchMemosProvider` 自己负责 remote filter、local merge、去重、fallback 和刷新。
- shortcut search、quick search、link-memo lookup 又各自重复一部分 query planning 逻辑。
- 本地 searchable document 目前通过 `buildMemoSearchDocument(...)` 拼接 memo content、clip-card metadata 和 URL host，但只被 `memos_fts` 与少量 fallback 路径间接消费。

这带来两个问题：

1. **一致性问题**：每个入口都可能在“什么时候查本地、什么时候查远端、如何校验 substring、如何处理脏数据”上做出不同决定。
2. **扩展性问题**：当前方案主要依赖 `LIKE` 与 `FTS` 混合兜底；当缓存 memo 数量上升时，correctness 虽然能靠后置校验守住，但查询代价和维护复杂度会持续上升。

用户提出的方向是把 memo search 收敛为 `SearchCoordinator + substring index + incremental invalidation`，因此这次设计直接围绕这三个支柱展开。

## Goals / Non-Goals

**Goals:**

- 让非空 memo search 统一经过一个 `SearchCoordinator` 执行 query planning。
- 保持 app-level search contract：plain-text query MUST match any continuous literal substring in the memo search document.
- 用本地 substring index 代替当前分散的 `FTS`/`LIKE` 候选策略，降低 CJK 中间片段搜索的路径分裂。
- 让 memo content、tags、clip-card searchable metadata 的变更只触发受影响 memo 的 index rebuild。
- 保持 main search、shortcut search、quick search、link-memo lookup 的最终可见结果语义一致。
- 在 index 尚未完全 warm-up 或 remote server 行为不一致时，仍然保证结果 correctness。

**Non-Goals:**

- 不修改 Memos server 的搜索语义，也不要求 server 原生支持 substring index。
- 不在本次设计中引入外部搜索引擎或平台相关 tokenizer。
- 不改变 advanced filters、shortcut predicate、排序、pinning、分页目标数量等既有产品行为。
- 不要求一次性删除所有现有 `memos_fts` 相关代码；遗留清理可以作为后续收尾。

## Decisions

### Decision 1: Introduce `SearchCoordinator` as the only app-side planner for non-empty memo search

新增 `SearchCoordinator`（可由 Riverpod provider 暴露）作为统一入口，负责：

- query normalization；
- local candidate lookup；
- remote fetch and merge；
- exact-match verification；
- db change refresh；
- fallback when index is warming or temporarily unavailable。

各搜索 surface 不再各自实现“remote + local + verify + refresh”流程，而是只负责提供：

- search surface kind（main / shortcut / quick / link-memo）；
- filters（state/tag/date/advanced filters/shortcut predicate）；
- page size；
- optional remote participation policy。

这样可以把 “结果应该长什么样” 与 “不同入口的 UI 状态” 解耦，避免以后每修一次 search semantics 就要在多个 provider/controller 里重复补丁。

**Alternatives considered:**

- 继续让 `remoteSearchMemosProvider`、shortcut provider、link lookup 各自维护逻辑：改动表面更小，但语义和 invalidation 仍会继续分叉。
- 只抽 matcher，不抽 coordinator：仍然无法统一 local/remote merge 和 index freshness policy。

### Decision 2: Replace FTS-first lookup with a canonical search document plus substring postings

本地索引拆成两层：

1. `memo_search_documents`
   - 每个 memo 一行，保存 canonical searchable text。
   - 内容来源复用 `buildMemoSearchDocument(...)` + tags，确保 content、clip-card metadata、URL host 与 tags 使用同一份规范化文档。
2. `memo_search_substrings`
   - 保存 memo 对应的 substring postings。
   - postings 使用 **distinct 1-character and 2-character grams**，而不是完整 materialized substrings。

查询时：

- query 长度为 1：直接命中 1-character gram postings。
- query 长度大于等于 2：拆成 overlapping 2-character grams，取 posting list intersection 作为候选 memo 集合。
- 最终再对候选 memo 的 canonical search document 执行 exact `contains` 校验，保证结果遵守 literal substring contract。

这样选择的原因：

- 1-char + 2-char grams 对 CJK substring 非常友好，不依赖空格分词；
- posting list 只做 candidate narrowing，exact correctness 由最终 `contains` 负责；
- 相比 materialize 全部 substring，存储膨胀更可控；
- 相比继续依赖 SQLite `FTS` tokenizer，语义更可预测，也不受 token-prefix 行为限制。

**Alternatives considered:**

- 保留 `FTS` 为主、`LIKE` 为辅：实现复用高，但无法从根上消除 tokenizer/prefix semantics 差异。
- 使用 trigram-only index：对英文长词不错，但对长度 1-2 的 CJK 查询支持较弱。
- 存全部 substring：查询简单，但写入和存储成本过高。

### Decision 3: Use dirty-queue based incremental invalidation instead of synchronous full backfill

新增 `memo_search_dirty`（或等价 dirty-marker 机制）记录需要重建 index 的 memo。

当以下数据变化时，只标记对应 memo dirty：

- memo insert / update；
- memo delete / archive state change that affects visibility；
- tags change；
- clip-card searchable fields change；
- sync merge 覆盖本地 memo 内容；
- migration 初次启用时的历史 memo。

`SearchCoordinator` 在执行搜索前/后按批次调用 `refreshDirtyMemoSearchIndex(limit: N)`：

- 读取一批 dirty memo；
- 重建其 canonical search document；
- 删除该 memo 旧 postings；
- 写入新 postings；
- 清除 dirty marker。

为了保证“dirty queue 未清空时也不能漏结果”，coordinator 对仍然 dirty 的 memo 集合保留 correctness guard：

- 优先使用 fresh index 查候选；
- 对尚未刷新的 dirty memo 做 bounded literal verification fallback；
- 当 dirty queue 被逐步 drain 后，fallback 工作量自然收敛。

这让我们避免 migration 或大批量 sync 时执行一次阻塞式全量 backfill，同时又不会因为 lazy rebuild 而漏掉刚修改的 memo。

**Alternatives considered:**

- 每次写入同步重建 substring postings：单条编辑结果最及时，但 bulk sync 和批量导入成本高。
- 每次 schema 变更后全量 backfill：实现直接，但首启和大库迁移体验差。

### Decision 4: Remote results remain optional candidates; final visible semantics stay local-authoritative

server 仍然可以提供 remote candidates，特别是在主列表 search 与部分 shortcut 场景中，但 `SearchCoordinator` 负责最终归一化：

- remote memo 必须通过本地 equivalent matcher 校验后才能展示；
- local indexed matches 必须能够补上 server 因 dialect/version 差异漏掉的 memo；
- 去重以 memo uid / stable key 为主；
- db change refresh 时优先保留已有 remote seed 的顺序，再用本地新命中的 memo 补齐。

这保留了 remote search 的覆盖面，又把 app-visible contract 固定在 client 侧，避免 server 版本差异重新把 substring semantics 打散。

**Alternatives considered:**

- 完全依赖 remote search：无法保证离线与旧 server 行为一致。
- 完全禁用 remote search：可能丢失尚未同步到本地缓存但 server 可返回的候选。

## Risks / Trade-offs

- **Index size grows with memo corpus** → 使用 distinct grams 而非全部 substring，并限制为 1-char + 2-char postings。
- **Dirty queue backlog may delay full warm-up** → coordinator 每次搜索按批次 drain，并对 remaining dirty memos 保留 literal fallback 保障正确性。
- **Canonical document drift between index build and exact verification** → 所有路径复用同一个 `buildMemoSearchDocument(...)` + normalization helper。
- **Single-character queries may still be broad** → 允许 coordinator 在极宽查询上保持 page-size bounded candidate resolution，必要时记录性能日志调优批次。
- **Migration complexity increases database surface area** → 把新表引入、dirty 标记、重建逻辑和 provider 收敛拆成明确任务，并保留旧 literal fallback 作为回退路径。

## Migration Plan

1. Add new tables/indexes for `memo_search_documents`, `memo_search_substrings`, and dirty markers.
2. During migration, enqueue existing memos into the dirty set instead of blocking startup with a full rebuild.
3. Introduce `SearchCoordinator` and switch non-empty search flows to coordinator-driven execution while keeping literal fallback available.
4. Drain dirty entries incrementally during normal app usage and search requests until the corpus is fully indexed.
5. After the new path is stable, stop relying on `memos_fts` for memo search reads; legacy cleanup can follow in a separate refactor if desired.

Rollback strategy:

- If the substring index is unavailable or corrupted, coordinator falls back to literal local search plus existing remote normalization.
- Because the old memo rows remain authoritative, rollback does not require data migration of user content.

## Open Questions

- `memos_fts` 是否在本次实现中完全退役，还是先保留一个 release 作为低风险过渡层？这不影响本次 capability 的 user-visible requirement，但会影响最终清理范围。
- Dirty queue batch size（例如每次 20 / 50 / 100 条）需要在实现阶段通过本地大库测试定最终默认值。
