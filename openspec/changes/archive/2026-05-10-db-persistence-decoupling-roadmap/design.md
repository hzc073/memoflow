## Context

`AppDatabase` 目前约 4000 行，`AppDatabaseWriteDao` 约 2200 行。前面已经完成的 `ComposeDraftDbPersistence`、`MemoSearchDbPersistence`、`OutboxDbPersistence` 证明了一个可持续方向：保留 `AppDatabase` 作为 database lifecycle/public facade/desktop write-proxy dispatcher，把 table-specific SQLite details 移到 focused data-layer persistence owner。

当前 change 本身不实现代码，而是固化后续 DB persistence 解耦的边界和批次。这样之后可以按任务批量执行，不需要每次重新探索 `AppDatabase` 里哪些对象值得拆。

当前依赖方向大致是：

```text
features/state/application
        |
        v
AppDatabase public facade
        |
        +--> schema + migration SQL for many tables
        +--> read queries for many table groups
        +--> some table-specific payload/mapping helpers
        |
        v
AppDatabaseWriteDao
        |
        +--> transaction owner
        +--> notifyDataChanged owner
        +--> mixed writes that touch memo/outbox/search/tags/etc.
```

目标方向：

```text
features/state/application
        |
        v
AppDatabase facade / lifecycle / desktop proxy
        |
        +--------------------+---------------------+
        |                    |                     |
        v                    v                     v
AppDatabaseWriteDao   TagDbPersistence      MemoLifecycleDbPersistence
transaction/notify    schema/read/prims     schema/read/prims
        |                    |                     |
        +--------------------+---------------------+
                             |
                             v
                     other *DbPersistence seams
```

这不会直接解决现存的 `state -> features`、`application -> features`、`core -> higher layer` hotspot，但会避免 lower data/db seam 继续扩大，并让 touched write paths 有更清晰 owner。它符合 `evolve_modularity` 下“触碰耦合区域必须 equal or better structured”的要求。

## Goals / Non-Goals

**Goals:**

- 固化 `AppDatabase`、`AppDatabaseWriteDao`、`*DbPersistence` 的职责边界。
- 固化 DB persistence extraction 的推荐批次顺序和每批完成标准。
- 让未来 change 可以直接从 roadmap 选择下一批，而不是重复进行全局探索。
- 要求后续每个 extraction change 保持 public facade、desktop write-proxy operation names、SQLite row compatibility、migration ordering 和 user-visible behavior 稳定，除非该 change 明确声明 breaking scope。
- 要求后续每个 extraction change 加入或收紧 architecture guardrail，防止 persistence seam 重新引入 upward imports 或 transaction ownership 扩散。

**Non-Goals:**

- 不在本 change 中移动任何 app runtime code。
- 不重设计 SQLite schema、sync protocol、desktop write-proxy protocol、server API route/version compatibility。
- 不强制一次性创建所有后续 concrete changes。
- 不把所有 `AppDatabase` public methods 立即迁移到 repositories/services。
- 不把 highest-risk `memos` core table 作为早期目标。

## Decisions

### Decision 1: Use one normative roadmap spec, not one giant implementation change

Create `db-persistence-boundaries` as a planning and architecture capability. It defines extraction order, role boundaries, and completion criteria. Concrete work should still happen in separate changes such as `decouple-tag-db-persistence` or `decouple-ai-db-persistence`.

Rationale: a single giant implementation change would touch too many migrations, write paths, sync behavior, tests, and guardrails at once. A normative roadmap keeps context available while preserving batch-sized implementation risk.

Alternative considered: create several concrete changes immediately. Rejected for now because exact batch details should be refreshed when implementation starts; stale scaffolds can become misleading.

### Decision 2: Keep `AppDatabase` as public facade and lifecycle owner

`AppDatabase` should continue to own:

- database open/close lifecycle
- `onCreate`, `onUpgrade`, and `onOpen` ordering
- public compatibility facade methods
- desktop write-proxy dispatch and local envelope operation names
- public constants/protocol values that existing callers already depend on, unless a concrete change explicitly moves them

It should not continue to own table-specific schema SQL, additive column ensure logic, payload parsing, or table-specific read/write SQL once a focused persistence seam exists.

Alternative considered: move callers directly to repositories while extracting each table. Rejected as the default because it combines two migrations: persistence ownership and caller ownership. A concrete change may still scope caller migration if that is the actual problem being solved.

### Decision 3: Keep transaction and notification ownership in `AppDatabaseWriteDao`

Focused persistence files should accept `DatabaseExecutor`, `Database`, or `Transaction` from callers, but should not call `.transaction(` directly. `AppDatabaseWriteDao` should continue to own transaction boundaries, mixed write orchestration, and `notifyDataChanged`.

Rationale: the hard part in this DB layer is often multi-table atomicity, not single-table SQL. Keeping transactions in the write owner lets mixed flows such as memo updates, outbox enqueue/delete, search invalidation, tag mapping, recycle-bin moves, and local-library replacement remain atomic.

Alternative considered: allow each `*DbPersistence` to own transactions. Rejected because it expands the direct transaction surface and makes nested/mixed writes harder to reason about.

### Decision 4: Focused `*DbPersistence` files own table-specific SQLite details

Each focused persistence owner should own:

- `CREATE TABLE IF NOT EXISTS ...`
- `CREATE INDEX IF NOT EXISTS ...`
- additive column ensure and table-local legacy normalization
- table-specific read queries
- executor-based write primitives
- table-local row mapping or payload helpers when those helpers are not public domain logic

They must not import `features/`, `state/`, or `application/`. If reusable domain logic is needed above SQL, it should live in a lower data/core seam that both DB persistence and state/application code can use.

Alternative considered: keep pure mapping helpers as static methods on `AppDatabase`. Rejected for new extractions because it keeps unrelated table knowledge in the monolith and makes future guardrails weaker.

### Decision 5: Use risk-based extraction order

Recommended order:

1. `decouple-tag-db-persistence`: high value, medium risk. `TagRepository` already exists, but tag schema/mapping and tag text normalization still live close to `AppDatabase`.
2. `decouple-memo-lifecycle-db-persistence`: high value, medium-high risk. Covers `memo_versions`, `recycle_bin_items`, `memo_delete_tombstones`, `memo_relations_cache`, and `memo_inline_image_sources`; many flows are mixed memo/outbox/search/local-library writes.
3. `decouple-ai-db-persistence`: medium-high value, medium risk. The `ai_*` schema block is large and cohesive.
4. `decouple-collections-db-persistence`: medium value, lower-medium risk. Covers `memo_collections`, `memo_collection_items`, and `collection_read_progress`.
5. `decouple-small-db-tables`: lower risk cleanup for tables such as `memo_reminders`, `import_history`, and `memo_clip_cards`, if they have not already moved with a more natural owner.
6. Optional `decouple-memo-core-db-persistence`: highest risk, last. Core `memos` table touches nearly every write/read/sync path and should wait until surrounding tables are clearer.

Alternative considered: start with the largest `memos` table. Rejected because it has the widest blast radius and is easier after dependent table groups are separated.

### Decision 6: Every concrete extraction must include guardrail work

For each concrete extraction, add or tighten checks that:

- new persistence files under `lib/data/db` do not import `features/`, `state/`, or `application/`
- direct `.transaction(` allowlists do not expand without an explicit design decision
- `AppDatabase` no longer owns the extracted table’s schema SQL and table-local helpers after the extraction
- public facade compatibility remains tested where callers still use `AppDatabase`

Alternative considered: rely on code review only. Rejected because this area has already been repeatedly touched by AI-assisted changes and needs mechanical regression checks.

## Risks / Trade-offs

- Risk: roadmap becomes stale as code evolves -> Mitigation: each concrete change must verify its target table group before implementation and update this spec if the ordering or boundary rules become wrong.
- Risk: future changes over-preserve `AppDatabase` facade and never reduce caller coupling -> Mitigation: this roadmap scopes persistence extraction only; later repository/caller changes are allowed when explicitly proposed.
- Risk: extraction changes accidentally alter migration behavior -> Mitigation: keep `AppDatabase` lifecycle ordering authoritative and require migration/backward-compatibility tests for table groups with legacy columns or data normalization.
- Risk: transaction ownership becomes fragmented -> Mitigation: require persistence helpers to accept executors and keep `.transaction(` ownership in `AppDatabaseWriteDao` unless explicitly approved.
- Risk: small tables get split into too many tiny files -> Mitigation: group small tables by natural owner when a cohesive persistence seam is clearer than one-file-per-table.

## Migration Plan

1. Archive/sync already completed compose draft, memo search, and outbox changes so their specs are canonical precedents.
2. Use this roadmap to create concrete batch changes in the recommended order.
3. For each batch, read this roadmap plus the target table code, then create a focused proposal/design/spec/tasks for that batch.
4. Implement one batch at a time, preserving public facade compatibility and adding guardrails.
5. After each batch, sync specs and archive the completed change before starting the next high-risk batch.

Rollback is per concrete change. This roadmap changes documentation only and has no runtime rollback requirement.

## Open Questions

- Should tag text normalization eventually move out of DB persistence into a reusable tag domain helper, or remain table-local until caller ownership is cleaned up?
- Should `AppDatabase` public constants/protocol values eventually move to lower protocol files after all table-specific SQL is extracted?
- Should the final `memos` core extraction happen at all, or is it enough to leave `AppDatabase` owning core memo rows once surrounding persistence seams are clean?
