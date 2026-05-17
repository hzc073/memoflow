## 1. Inventory and Seam Setup

- [x] 1.1 Identify all current outbox schema, migration, read, count, payload decode, memo-uid extraction, enqueue, claim, mark, retry, quarantine, delete, clear, and rewrite code in `AppDatabase` and `AppDatabaseWriteDao`.
- [x] 1.2 Add focused outbox persistence file(s) under `memos_flutter_app/lib/data/db/` without importing `features/`, `state/`, or `application/`.
- [x] 1.3 Define executor-based helper boundaries so `OutboxDbPersistence` does not directly call `.transaction(` and `AppDatabaseWriteDao` remains transaction owner.

## 2. Schema and Migration Extraction

- [x] 2.1 Move `CREATE TABLE IF NOT EXISTS outbox` SQL into the new persistence owner while preserving `onCreate` behavior.
- [x] 2.2 Move additive outbox column ensure logic for `retry_at`, `failure_code`, `failure_kind`, and `quarantined_at` into the new persistence owner while preserving upgrade ordering.
- [x] 2.3 Move legacy outbox state/error-chain migration behavior into the new persistence owner while preserving v12/v19 migration semantics.
- [x] 2.4 Keep `AppDatabase` responsible for database lifecycle ordering and delegate only outbox-specific schema/migration details.

## 3. Read-Side Extraction

- [x] 3.1 Move `listOutboxPending`, `listOutboxAttention`, `listOutboxQuarantined`, and latest attention row query internals to the new persistence owner while preserving row maps and ordering.
- [x] 3.2 Move outbox count helpers for pending, retryable, failed, quarantined, and attention states into the new persistence owner.
- [x] 3.3 Move `listOutboxPendingByType`, `listOutboxByMemoUid`, `hasPendingOutboxTaskForMemo`, and `listPendingOutboxMemoUids` internals to the new persistence owner.
- [x] 3.4 Move outbox payload decode, memo uid extraction, and derived attention field helpers to the new persistence owner without changing supported task type semantics.

## 4. Write Primitive Extraction

- [x] 4.1 Move enqueue and batch enqueue primitives into executor-based outbox persistence helpers while preserving payload JSON shape, pending state, and insertion order.
- [x] 4.2 Move claim-next and claim-by-id primitives into executor-based helpers while preserving runnable predicates for pending and due retry tasks.
- [x] 4.3 Move recover running, mark done, complete, error, retry scheduled, retry pending, quarantine, retry item, and retry errors primitives into the new persistence owner.
- [x] 4.4 Move delete-by-id, delete items, clear, delete-for-memo, and discard/update helpers that directly mutate outbox rows into the new persistence owner where scoped to outbox rows.
- [x] 4.5 Move outbox memo uid rewrite and pending create memo payload update helpers into the new persistence owner while preserving changed-count semantics.
- [x] 4.6 Keep mixed memo/local-library transaction orchestration in `AppDatabaseWriteDao`, delegating only outbox row operations to the persistence owner.

## 5. Facade, Proxy, and Boundary Preservation

- [x] 5.1 Keep existing `AppDatabase` public outbox method signatures and `AppDatabase.outboxState*` constants available.
- [x] 5.2 Preserve desktop write-proxy operation names and payload keys for all outbox write commands.
- [x] 5.3 Preserve `notifyDataChanged` behavior in `AppDatabase` / `AppDatabaseWriteDao` owner paths after outbox writes.
- [x] 5.4 Confirm no server API route/version compatibility files are touched by this change.

## 6. Guardrails

- [x] 6.1 Add or tighten an architecture guardrail proving outbox DB persistence files under `lib/data/db/` do not import `features/`, `state/`, or `application/`.
- [x] 6.2 Verify the direct transaction guardrail remains stable and does not need to add the outbox persistence file to its allowlist.
- [x] 6.3 Add or tighten a guardrail that fails if `AppDatabase` re-owns outbox table creation SQL, payload decode helpers, or outbox state transition SQL after extraction.
- [x] 6.4 Verify existing modularity allowlists are not expanded for `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.

## 7. Verification

- [x] 7.1 Run DB migration tests covering legacy outbox retry/quarantine behavior from `memos_flutter_app`.
- [x] 7.2 Run DB write envelope tests covering outbox desktop write proxy and batch order behavior from `memos_flutter_app`.
- [x] 7.3 Run sync queue controller, remote sync outbox, local sync outbox, memo mutation, and memo delete focused tests that cover enqueue/claim/retry/quarantine/delete semantics.
- [x] 7.4 Run `flutter test test/architecture` from `memos_flutter_app`.
- [x] 7.5 Run `flutter analyze` from `memos_flutter_app`.
- [x] 7.6 Run `flutter test` from `memos_flutter_app`.
- [x] 7.7 Review the final diff to confirm `AppDatabase` no longer directly owns outbox persistence details and visible sync queue behavior remains unchanged.
