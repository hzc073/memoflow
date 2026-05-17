## Context

`AppDatabase` currently owns SQLite connection lifecycle, schema creation, migrations, write proxy dispatch, local write delegation, read queries, and several derived maintenance systems. Compose draft persistence is one small slice of that class, but it now includes create draft rows, sent memo edit draft metadata, edit-draft uniqueness, backup/transfer round-trip behavior, and legacy draft mirroring through `ComposeDraftRepository`.

The active architecture phase is `evolve_modularity` with a recorded modularity score of `4/10`. This change does not attempt to solve the known critical reverse-dependency items (`state -> features`, `application -> features`, `core -> higher layers`). It targets the persistence hotspot around `AppDatabase`, improving checklist items `7`, `8`, and `10` by giving the touched compose draft SQL a clearer owner and by adding guardrails against boundary drift.

Current shape:

```text
ComposeDraftRepository
  -> AppDatabase
       -> compose_drafts read SQL
       -> write proxy dispatch
       -> AppDatabaseWriteDao
            -> compose_drafts write SQL
       -> compose_drafts schema / migration helpers
```

Target first step:

```text
ComposeDraftRepository
  -> AppDatabase facade
       -> write proxy dispatch remains here
       -> ComposeDraftDbPersistence / schema helpers
       -> AppDatabaseWriteDao
            -> ComposeDraftDbPersistence local writes
```

The public call path remains stable while the SQL moves behind a narrower data-layer module.

## Goals / Non-Goals

**Goals:**

- Move compose draft table SQL, read queries, and local write SQL out of the main `AppDatabase` class into focused data-layer file(s).
- Preserve the existing `AppDatabase` public methods for compose drafts during this change so callers and tests do not need a broad migration.
- Preserve desktop write proxy behavior: remote write commands still go through `AppDatabase._dispatchWriteCommand`, and local execution still works through the existing envelope path.
- Preserve all compose draft row semantics, including `draft_kind`, `target_memo_uid`, existing attachment JSON, latest-row ordering, workspace scoping, and one edit draft per `(workspace_key, target_memo_uid)`.
- Keep `ComposeDraftRepository` and `ComposeDraftMutationService` as the state-layer owner of draft persistence decisions.
- Add or tighten focused guardrails for the new persistence files and direct draft DB write calls.

**Non-Goals:**

- Do not change user-facing Draft Box, note input, memo editor, backup, or transfer behavior.
- Do not change server API compatibility.
- Do not change `compose_drafts` schema version unless implementation discovers an idempotency gap required to preserve current behavior.
- Do not refactor outbox, memo search, FTS, stats cache, collections, AI tables, or global migration coordination.
- Do not remove the `AppDatabase` compose draft facade methods in this change.

## Decisions

### Decision: Use facade-preserving extraction first

Keep methods such as `listComposeDraftRows`, `getComposeDraftRow`, `getComposeEditDraftRowForMemo`, `getLatestComposeDraftRow`, `upsertComposeDraftRow`, `replaceComposeDraftRows`, `deleteComposeDraft`, and `deleteComposeDraftsByWorkspace` on `AppDatabase` for now. Their internals should delegate to the new compose draft persistence helper while preserving write proxy checks.

This keeps the first change small:

```text
Before callers: ComposeDraftRepository -> AppDatabase
After callers:  ComposeDraftRepository -> AppDatabase

Before internals: AppDatabase owns compose_drafts SQL
After internals:  AppDatabase delegates compose_drafts SQL
```

Alternative considered: migrate `ComposeDraftRepository` directly to a new DAO interface in the same change. Rejected for the first step because it would mix SQL extraction with dependency injection changes, increasing review and regression risk.

### Decision: Separate pure SQLite row operations from write proxy orchestration

The new compose draft persistence helper should own SQLite details:

- table creation SQL for `compose_drafts`
- indexes, including the partial unique edit-draft index
- idempotent edit-draft column/index ensure logic
- row list/get/latest/get-edit-draft queries
- local insert/replace/delete operations

`AppDatabase` should continue to own:

- database connection lifecycle
- `_dbVersion`
- `onCreate`, `onUpgrade`, and `onOpen` ordering
- desktop write gateway dispatch and envelope execution
- change notification stream

`AppDatabaseWriteDao` should either call the new helper for compose draft local writes or be reduced to a thin notification wrapper around those helper calls. This avoids spreading write proxy decisions into the extracted persistence code.

Alternative considered: move write proxy dispatch into the new compose draft DAO. Rejected because desktop write routing is a cross-cutting `AppDatabase` concern shared by all DB writes.

### Decision: Keep row maps as the compatibility boundary

The extraction should continue returning `Map<String, dynamic>` rows and accepting `Map<String, Object?>` write payloads. Typed conversion stays in `ComposeDraftRecord.fromRow` / `toRow`.

This preserves:

- backup and transfer row compatibility
- existing repository tests
- legacy create draft default decoding
- sent memo edit draft optional fields

Alternative considered: make the new persistence helper return `ComposeDraftRecord`. Rejected for now because it would mix data model conversion ownership into the low-level SQLite module and would force more call-site changes.

### Decision: Add targeted guardrails instead of line-count targets

This change should not use file length as the success metric. Better signals are:

- compose draft SQL no longer lives directly in the large `AppDatabase` class
- new compose draft persistence files do not import `features/`, `state/`, or `application/`
- feature widgets do not directly call draft DB write methods
- existing direct-write allowlists are not expanded

Alternative considered: add a strict maximum line count for `app_database.dart`. Rejected because it is brittle and would encourage mechanical movement without proving a better boundary.

## Risks / Trade-offs

- [Risk] Moving SQL can subtly change query filtering or ordering. -> Mitigation: keep row-map boundaries and run focused compose draft repository tests plus Draft Box and backup/transfer tests.
- [Risk] Desktop write proxy behavior can regress if writes bypass `_dispatchWriteCommand`. -> Mitigation: keep `AppDatabase` write facade methods and existing envelope tests in scope.
- [Risk] Schema helpers can run in a different order during create/upgrade/open. -> Mitigation: preserve `onCreate`, `onUpgrade`, and `onOpen` call ordering; only move SQL text and helper calls.
- [Risk] Guardrails can become too broad and block legitimate data-layer code. -> Mitigation: make them path-specific to compose draft persistence files and direct draft DB write calls.
- [Risk] This does not improve the critical reverse-dependency checklist items. -> Mitigation: document that this is a scoped persistence improvement during `evolve_modularity`, not a phase-transition change.

## Migration Plan

1. Add focused compose draft persistence file(s) under `memos_flutter_app/lib/data/db/`.
2. Move `compose_drafts` schema SQL and idempotent edit-column/index ensure logic into the new helper.
3. Move compose draft read queries from `AppDatabase` into the helper, keeping `AppDatabase` public methods as forwarding methods.
4. Move compose draft local write SQL from `AppDatabaseWriteDao` into the helper while preserving `AppDatabase` write proxy dispatch and `notifyDataChanged` behavior.
5. Add or tighten architecture guardrails for the new data-layer boundary and direct draft write calls.
6. Run focused compose draft, backup/transfer, Draft Box, architecture, analyze, and broader test checks.

Rollback is straightforward because external callers keep using the existing `AppDatabase` facade. If regressions appear, the helper delegation can be reverted without changing user-facing behavior or schema.

## Open Questions

- Should the helper be split into `compose_draft_db_schema.dart` and `compose_draft_db_queries.dart`, or kept as one `compose_draft_db_persistence.dart` file? Start with one file if it stays small; split only if schema and row operations become noisy.
- Should `ComposeDraftRepository` eventually depend on a narrower interface instead of `AppDatabase`? That is a likely follow-up after this facade-preserving extraction proves stable.
