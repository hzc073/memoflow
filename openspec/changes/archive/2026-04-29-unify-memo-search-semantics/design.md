## Context

当前 Memo search 存在多条执行路径，用户看到的是同一个搜索框或类似入口，但底层语义并不完全一致：

- 本地/offline 列表搜索主要通过 `AppDatabase.listMemos` 查询 SQLite，本地文本匹配依赖 `SQLite FTS`。
- 主列表中非空搜索词会进入 remote-search provider，再通过不同 Memos server 版本的 API 获取候选结果。
- shortcut search、quick search、link-memo lookup 各自有 provider/controller 路径。
- 不同 server flavor 和 filter dialect 会导致 `content.contains(...)`、`content_search == [...]`、本地 FTS prefix search 等行为混用。

已观察到的典型问题是：memo 内容为“在秩序中安顿”时，搜索“在”和“在秩序”可以命中，但搜索“秩序”失败。原因是本地 `SQLite FTS` 将连续 CJK 文本视为 token，并把查询转换为类似 `term*` 的 prefix expression；这不是用户期望的“任意连续片段搜索”。

## Goals / Non-Goals

**Goals:**

- 明确定义 app-level plain-text memo search contract。
- plain query SHALL 按 literal continuous substring 匹配 memo content，而不是只匹配 token prefix。
- 本地 cached memo search MUST 支持 CJK 中间片段匹配。
- main search、local/offline search、shortcut search、quick search、link-memo lookup SHOULD 使用一致的 matcher semantics。
- 保持已有 filters 不变，包括 state、tag、creator scope、date range、advanced filters、shortcut predicate、pin/order/limit 行为。
- remote search 仍作为候选来源，但当 server search semantics 与 app contract 不一致时，app-visible results MUST 被本地 matcher 校正或补充。
- 添加 regression tests 覆盖 CJK prefix/middle-substring 场景和多 search surface 一致性。

**Non-Goals:**

- 不替换或修改 Memos server 的搜索实现。
- 不引入外部 search engine。
- 不保证发现从未 sync 到 local cache 的 remote-only memo；如果 server 不能返回它，client 只能 best-effort。
- 不改变 unrelated ranking、pinning、archive、tag、date filter、visibility 行为。
- 不在 proposal 阶段决定必须使用 n-gram index；首个实现应优先 correctness 和 minimal scope。

## Decisions

### Decision 1: Plain memo search 使用 literal substring semantics

plain search input 先 trim surrounding whitespace，然后作为 literal text 与 memo content 做 continuous substring 匹配。查询文本 MUST NOT 被当成 `SQLite FTS` query syntax、SQL wildcard syntax 或 server filter syntax 执行。

Rationale：用户输入“秩序”时，预期是找到包含“秩序”的 memo，而不是只找以“秩序”作为 token prefix 的 memo。

Alternatives considered：

- 继续使用 `SQLite FTS` prefix semantics：性能好、改动小，但保留当前 bug。
- 在 UI 说明“仅支持前缀搜索”：技术上简单，但违背用户对中文搜索的直觉。
- 直接上 n-gram index：长期性能更好，但会引入 index migration、backfill 和维护复杂度。

### Decision 2: 本地 exact-substring matching 是一致性的底线

local cached search SHOULD 保留 `SQLite FTS` 作为 fast candidate path，但 final visible result set MUST 满足 shared matcher。实现可以选择：

- FTS candidates + additional `LIKE` fallback/union；
- SQL 先按 state/tag/date 缩小候选，再 app-level matcher 过滤；
- 未来升级到 n-gram index。

首个实现建议优先选择 minimal change：在保留 filters/order/limit 的前提下，让 local search 不再因为 CJK token boundary 漏掉合法 substring match。

### Decision 3: Centralize matcher semantics

应抽出共享的 plain-text matcher，例如 `MemoSearchMatcher` 或等价 helper，用于最终判断 memo content 是否匹配 query。provider/controller 不应继续各写一套 `content.contains(...)`、FTS query、remote filter 语义。

Rationale：如果 main search、shortcut search、quick search、link-memo lookup 分别修，会很容易再次出现“这里能搜、那里不能搜”的 drift。

Alternatives considered：

- 每个 provider 独立 patch：短期快，但长期维护成本高。

### Decision 4: Remote search 是 candidate source，不是唯一 truth

remote APIs 仍用于获取 fresh candidates、creator scope 和 server-side filters。但当 plain query 存在时，app-visible results SHOULD：

- 使用 shared matcher 验证 server candidates；
- merge local cached matches，补上 server prefix/token search 漏掉的结果；
- 用 stable memo UID/name deduplicate；
- 保持 state/tag/date/advanced filters 不被绕过。

该方案接受一个限制：如果某个 memo 只存在 remote server 且 local cache 不存在，而 server 又无法按 substring 返回它，client 无法保证发现该 memo。

Alternatives considered：

- 全量 enumerate remote memos 后 client-side filter：一致性最好，但大账号成本高、分页复杂。
- 完全信任 modern `content.contains(...)`：实现简单，但 legacy mode 和 server version 仍会造成行为差异。

## Risks / Trade-offs

- [Risk] `LIKE '%query%'` 或 app-level substring scan 在大库上可能变慢 → [Mitigation] 先 push down state/tag/date filters，保留 `SQLite FTS` candidate optimization，并限制 scan 范围。
- [Risk] remote + local merge 产生重复 memo → [Mitigation] 按 memo UID/name 做 deduplication。
- [Risk] local cache 不完整导致 remote-only memo 仍搜不到 → [Mitigation] 在 design/spec 中明确 remote-only discovery 是 best-effort，并继续使用 server candidates。
- [Risk] 搜索语义变宽后 result count 增加 → [Mitigation] 添加 filters/order/limit regression tests，确保 substring matching 不绕过非文本约束。
- [Risk] 可能需要调整 API compatibility code → [Mitigation] 触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api` 前必须先获得 explicit user approval。
