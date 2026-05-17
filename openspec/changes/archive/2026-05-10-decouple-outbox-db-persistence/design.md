## Context

当前 `AppDatabase` 已经通过 compose draft 与 memo search 拆分减少了一部分 DB hotspot，但 outbox 仍然横跨多个责任：

```text
state/application sync flows
        |
        v
AppDatabase public facade
  |-- desktop write-proxy operation dispatch
  |-- outbox schema / v12-v19 migration
  |-- outbox read queries / counts / derived attention fields
  |-- payload decode / memo uid extraction helpers
  |
  v
AppDatabaseWriteDao
  |-- transaction owner
  |-- notifyDataChanged owner
  |-- enqueue / claim / mark / retry / delete
  |-- rewrite outbox memo uid payloads
  |-- mixed memo/local-library writes that also touch outbox
```

outbox 是 local sync、remote sync、desktop owner write、memo mutation、import/backup 的共同持久化队列。它的复杂度来自状态机和 payload 语义，而不是单纯 CRUD。当前架构阶段是 `evolve_modularity`，本 change 的目标是让触碰区域 equal or better structured：把 outbox SQLite details 移到稳定 data-layer seam，保留上层 API 与现有 mutation owner。

目标依赖方向：

```text
state/application/features
        |
        v
AppDatabase facade
        |
        +--------------------+
        |                    |
        v                    v
AppDatabaseWriteDao     OutboxDbPersistence
 transaction/notify      SQL/payload helpers
```

`OutboxDbPersistence` 只依赖 `sqflite` 和低层 utility，不依赖 `features/`、`state/`、`application/`。如果它需要事务，由调用方传入 `Transaction`/`DatabaseExecutor`；它不直接调用 `.transaction(`。

## Goals / Non-Goals

**Goals:**

- Extract outbox table creation, additive column ensure, and legacy outbox error-chain migration from `AppDatabase` into a focused data-layer persistence owner.
- Extract outbox read-side helpers: pending/attention lists, counts, list-by-memo, pending memo uid collection, and derived attention fields.
- Extract outbox write primitives from `AppDatabaseWriteDao` into executor-based helper methods while keeping `AppDatabaseWriteDao` responsible for transaction boundaries and `notifyDataChanged`.
- Preserve all public `AppDatabase` outbox method signatures, row map shapes, state codes, payload JSON shapes, ordering, and desktop write-proxy operation names.
- Preserve local/remote sync behavior, including pending/running/retry/error/quarantined handling, retry scheduling, and quarantine metadata.
- Add or tighten architecture guardrails for the new persistence seam.

**Non-Goals:**

- Do not redesign sync queue behavior, retry policy, quarantine policy, or payload schemas.
- Do not move state/application callers from `AppDatabase` to a new repository in this change.
- Do not change `AppDatabase.outboxState*` public constants during this extraction.
- Do not modify server API route/version compatibility code.
- Do not broaden direct `.transaction(` allowlists unless the design changes explicitly justify it.
- Do not refactor unrelated DB areas such as tags, import history, AI tables, memo relations, versions, or recycle bin beyond calls needed to preserve outbox behavior.

## Decisions

### Decision 1: Add `OutboxDbPersistence` as a data-layer SQLite owner

Create a focused persistence owner under `memos_flutter_app/lib/data/db/`, conceptually named `outbox_db_persistence.dart`. It should own:

- `CREATE TABLE IF NOT EXISTS outbox`
- additive outbox columns: `failure_code`, `failure_kind`, `quarantined_at`, and `retry_at` support where needed
- legacy state/error-chain migration used around v12/v19
- payload JSON decode and memo uid extraction for known outbox task types
- list/count helpers and derived attention fields
- executor-based primitives for enqueue, claim, mark, retry, quarantine, delete, rewrite, and update pending create memo payloads

Rationale: this matches the recently established `ComposeDraftDbPersistence` and `MemoSearchDbPersistence` direction: `AppDatabase` remains lifecycle/facade owner, while table-specific SQL lives in a focused data-layer seam.

Alternative considered: move all outbox behavior into a state-layer repository. Rejected for this change because outbox is a DB table and sync queue persistence primitive shared by multiple state/application owners. Moving callers now would broaden the blast radius.

### Decision 2: Keep transaction ownership in `AppDatabaseWriteDao`

`OutboxDbPersistence` should accept `DatabaseExecutor` or use already-open `Database` for non-transaction reads, but it should not directly call `.transaction(`. `AppDatabaseWriteDao` currently owns direct transactions and is allowlisted by `db_transaction_guardrail_test.dart`.

Rationale: preserving this seam avoids changing the transaction guardrail and keeps write envelope/desktop proxy behavior stable. It also lets mixed operations such as `deleteMemoAfterRecycleBinMove`, `replaceMemoFromLocalLibrary(clearOutbox: true)`, and memo uid rename keep outbox and memo writes in one transaction.

Alternative considered: add `outbox_db_persistence.dart` to the direct transaction allowlist. Rejected because it would expand a guardrail for convenience and blur write ownership.

### Decision 3: Keep `AppDatabase` public outbox facade stable

Existing callers should continue using methods such as `enqueueOutbox`, `listOutboxPending`, `claimOutboxTaskById`, `markOutboxQuarantined`, `retryOutboxErrors`, `listPendingOutboxMemoUids`, and `deleteOutboxForMemo`.

Rationale: this change is a persistence extraction, not a sync API redesign. Keeping the facade stable lets tests prove behavior preservation while still shrinking `AppDatabase` internals.

Alternative considered: introduce `OutboxRepository` and migrate callers immediately. Rejected as a future change candidate; it would mix persistence extraction with broader state/application ownership changes.

### Decision 4: Keep outbox state constants public on `AppDatabase`

Do not move `outboxStatePending`, `outboxStateRunning`, `outboxStateRetry`, `outboxStateError`, `outboxStateDone`, and `outboxStateQuarantined` in this change.

Rationale: these constants are used across sync queue models, controllers, providers, and tests. Moving them would create noisy cross-layer churn and distract from the persistence boundary. A later change can consider `OutboxState` or `SyncQueueOutboxState` as the public protocol owner.

Alternative considered: create `core/outbox_state.dart` now and rewrite callers. Rejected for scope control.

### Decision 5: Guard the new boundary

Add or tighten architecture tests so:

- outbox persistence files under `lib/data/db/` do not import `features/`, `state/`, or `application/`
- direct `.transaction(` remains confined to existing transaction owner files
- `AppDatabase` no longer directly contains outbox table SQL or payload parsing helpers after extraction, except facade/proxy references and constants

Rationale: without guardrails, `AppDatabase` can easily regain table-specific logic during future sync work.

## Risks / Trade-offs

- Risk: outbox row shapes subtly change during extraction -> Mitigation: run focused sync queue, write envelope, migration, remote sync, local sync, and memo mutation tests that inspect payloads/states/order.
- Risk: claim/retry semantics change under concurrency -> Mitigation: keep SQL predicates and transaction ownership unchanged; move text mechanically into executor helpers.
- Risk: desktop write proxy operations break -> Mitigation: preserve operation names and payload decode in `AppDatabase`; only delegate local execution internals.
- Risk: migration behavior changes for legacy error chains -> Mitigation: preserve the existing v12/v19 ordering and run `app_database_migration_test.dart`.
- Risk: new helper imports `AppDatabaseWriteDao` or higher layers -> Mitigation: guard against higher-layer imports and keep transactions outside the helper.
- Trade-off: `AppDatabase` will still expose many outbox public methods after this change -> Accepted to keep this as a safe persistence extraction; caller migration can be a later change.

## Migration Plan

1. Introduce the persistence owner and move schema/migration helpers while preserving `onCreate`, `onUpgrade`, and `onOpen` ordering.
2. Move read-side list/count/payload helper logic behind `AppDatabase` facade methods.
3. Move write primitives behind `AppDatabaseWriteDao`, preserving transaction boundaries and notifications.
4. Add/tighten architecture guardrails.
5. Run focused and full verification.

Rollback is straightforward: because public APIs and DB schema remain unchanged, the extracted helper can be inlined back into the current owners if needed. No data migration rollback is expected.

## Open Questions

- Should a later change move public outbox state constants from `AppDatabase` to a stable lower-level `OutboxState` seam?
- Should a later change introduce a dedicated outbox repository/mutation boundary for state/application callers, or is `AppDatabase` facade sufficient for now?
