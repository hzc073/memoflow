## Why

`AppDatabase` has become a persistence coupling hotspot: compose draft schema, compose draft queries, write dispatch plumbing, and unrelated memo/outbox/search/AI responsibilities all live in the same large class. Now that sent memo edit drafts are complete, the compose draft persistence path is a good first low-risk extraction target because its behavior is covered by focused repository, backup, and Draft Box tests.

## What Changes

- Extract compose draft database persistence into a focused data-layer component while preserving the existing `AppDatabase` public facade during the first implementation step.
- Keep compose draft row shape, schema version behavior, unique edit-draft constraint, and repository behavior unchanged.
- Keep `ComposeDraftRepository` and `ComposeDraftMutationService` as the write/read ownership boundary used by state and feature code.
- Add or tighten architecture guardrails so compose draft persistence code cannot depend on `features/`, and feature widgets cannot bypass repository/mutation ownership to call draft DB write methods directly.
- Do not refactor unrelated `AppDatabase` areas such as outbox, FTS/search index, stats cache, collections, AI tables, or migration coordination in this change.

## Capabilities

### New Capabilities

- `compose-draft-persistence`: Defines the persistence behavior and architecture boundary for compose draft rows, including create/edit draft row compatibility, repository ownership, facade-preserving extraction, and guardrail coverage.

### Modified Capabilities

- None. Existing Draft Box and note input behavior should remain unchanged; this change introduces a persistence architecture contract rather than changing user-facing requirements.

## Impact

- Active architecture phase: `evolve_modularity`.
- Modularity checklist items touched:
  - `7.` Touched write paths have clear owners such as services, repositories, or mutation seams.
  - `8.` Architecture guardrail tests protect the highest-risk dependency directions.
  - `10.` Changes touching coupled areas leave the touched area equal or better structured than before.
- Affected app areas:
  - `memos_flutter_app/lib/data/db/app_database.dart`
  - `memos_flutter_app/lib/data/db/app_database_write_dao.dart`
  - New focused data-layer compose draft persistence file(s) under `memos_flutter_app/lib/data/db/`
  - `memos_flutter_app/lib/state/memos/compose_draft_provider.dart`
  - `memos_flutter_app/lib/state/memos/compose_draft_mutation_service.dart`
  - Architecture guardrails under `memos_flutter_app/test/architecture/`
  - Existing compose draft, backup, transfer, Draft Box, and note input tests as verification targets
- No server API route/version changes are intended.
- No database schema changes are intended unless implementation discovers a missing idempotent helper required to preserve existing behavior.
