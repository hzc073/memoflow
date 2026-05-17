## Context

Earlier DB decoupling changes extracted most table-specific persistence details from `AppDatabase` and `AppDatabaseWriteDao`. The remaining high-value coupling is the memo main write path:

- `update('memos', ...)` for sync state, attachments JSON, UID rename, and full row updates
- `insert('memos', ...)` for new memo rows
- `delete('memos', ...)` for memo deletion
- `query('memos', ...)` row reads used to clean pending attachment placeholders and refresh search after clip-card changes

`AppDatabaseWriteDao` also coordinates multiple concerns in the same write path: tag resolution, `memo_tags` mapping, SQLite FTS/index refresh, stats cache deltas, lifecycle cleanup, auxiliary clip-card writes, outbox coordination, and change notifications.

## Decisions

### Decision 1: Extract only table-local `memos` primitives

`MemoWriteDbPersistence` owns direct `memos` table row operations:

- sync-state updates
- attachments JSON updates
- attachment-placeholder cleanup in `attachments_json`
- UID rename on the `memos` row
- insert/update of memo row values
- delete by UID
- row reads needed by write-side orchestration

The new class does not own transaction creation, cache deltas, FTS/index refresh, tag mapping, outbox behavior, or lifecycle cleanup.

### Decision 2: Keep write orchestration in `AppDatabaseWriteDao`

`AppDatabaseWriteDao` remains the owner of memo write workflows because those workflows coordinate many persistence owners inside shared transactions.

For example, `_upsertMemo` still resolves tags, loads stats snapshots, delegates the `memos` row upsert, refreshes search, updates `memo_tags`, and applies stats deltas in a single orchestration flow.

### Decision 3: Use small DTOs instead of exposing raw query maps everywhere

For supporting row reads, `MemoWriteDbPersistence` returns small typed results such as `MemoWriteRowIdResult` and `MemoWriteSearchRefreshRow`. This keeps direct SQL out of the DAO without forcing unrelated domain models into the persistence owner.

## Dependency Direction

Before:

```text
AppDatabaseWriteDao -> direct memos table update/insert/delete/query SQL
AppDatabaseWriteDao -> write orchestration across tag/search/stats/lifecycle/outbox
```

After:

```text
AppDatabaseWriteDao -> MemoWriteDbPersistence for memos row primitives
AppDatabaseWriteDao -> write orchestration across tag/search/stats/lifecycle/outbox
MemoWriteDbPersistence -> sqflite only
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Memo row insert/update must preserve exact column values, conflict behavior, and `display_time` preservation semantics.
- Attachment placeholder cleanup must keep tolerant JSON parsing behavior.
- Delete flow must still capture the memo row id before deletion so FTS/index cleanup remains compatible.
- The DAO will still mention the `memos` domain concept by design; the guardrail should block direct table-local primitives without blocking orchestration.
