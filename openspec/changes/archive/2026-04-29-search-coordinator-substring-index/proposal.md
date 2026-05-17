## Why

Memo search 目前虽然已经逐步向 literal substring semantics 靠拢，但执行路径仍然分散在 `AppDatabase.listMemos`、`remoteSearchMemosProvider`、shortcut search 和 link-memo lookup 里，导致同一个查询会重复混用 `FTS`、`LIKE`、remote filter 与本地补偿逻辑。随着本地缓存变大，这种“多入口、多策略”的实现更难保证一致性，也会让 CJK 中间片段搜索、批量同步后的刷新成本和维护复杂度持续上升。

现在需要把“搜索语义正确”进一步推进到“搜索架构统一”：用一个明确的 coordinator 负责搜索计划，用可验证的 substring index 提供本地候选集，并用 incremental invalidation 只重建受影响 memo 的索引数据。

## What Changes

- Introduce a `SearchCoordinator` as the single app-side entry point for memo search planning, local candidate lookup, remote fetch/merge, and final result normalization.
- Replace memo-search reliance on ad hoc `FTS`/`LIKE` fan-out with a local substring index that produces candidate memo IDs for literal substring queries, then verifies exact matches against memo content.
- Add incremental invalidation for search documents so memo edits, sync updates, clip-card changes, and deletions only rebuild affected index entries instead of relying on broad backfills.
- Route main memo search, local/offline search, shortcut search, quick search, and link-memo lookup through the same search coordination flow and matching contract.
- Add regression and performance-oriented coverage for CJK middle-substring matches, remote/local merged results, and repeated local updates that should not trigger full index rebuilds.

## Capabilities

### New Capabilities
- `memo-search`: Defines the unified memo search contract, the coordinator-driven execution model, and the local substring index lifecycle.

### Modified Capabilities
- None.

## Impact

- Local database search and schema in `memos_flutter_app/lib/data/db/app_database.dart`.
- Search helpers such as `memos_flutter_app/lib/core/memo_search_matcher.dart`.
- Memo search orchestration in `memos_flutter_app/lib/state/memos/memos_search_providers.part.dart`.
- Link-memo lookup in `memos_flutter_app/lib/state/memos/link_memo_controller.dart`.
- Likely new search orchestration/index modules under `memos_flutter_app/lib/`.
- Search-related tests under `memos_flutter_app/test/state/memos`, `memos_flutter_app/test/features/memos`, and database-level coverage for local index maintenance.
