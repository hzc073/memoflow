## 1. Roadmap Canonicalization

- [x] 1.1 Review `proposal.md`, `design.md`, and `specs/db-persistence-boundaries/spec.md` against the current `AppDatabase` and `AppDatabaseWriteDao` table groups before starting runtime code.
- [x] 1.2 Sync `db-persistence-boundaries` into main specs and archive this roadmap change so future DB extraction changes can reference the canonical spec.

## 2. Future Batch Queue

These are reference batches for future concrete OpenSpec changes. They are intentionally not roadmap apply checkboxes because this roadmap change should be synced and archived before concrete runtime implementation starts.

### Batch 1: Tags

- Create `decouple-tag-db-persistence` as a concrete OpenSpec change that references `db-persistence-boundaries`.
- Map the tag persistence surface in `AppDatabase`, `AppDatabaseWriteDao`, `TagRepository`, and tag-related tests.
- Extract `TagDbPersistence` for `tags`, `tag_aliases`, `memo_tags`, and table-local tag mapping primitives while preserving public facade behavior.
- Keep tag write transactions and `notifyDataChanged` ownership in approved write-owner paths.
- Add or tighten guardrails that prevent upward imports and prevent `AppDatabase` from re-owning tag schema/table-local helpers.
- Run focused tag, DB, architecture, and analyzer checks; sync and archive the concrete tag change when complete.

### Batch 2: Memo Lifecycle Tables

- Create `decouple-memo-lifecycle-db-persistence` as a concrete OpenSpec change that references `db-persistence-boundaries`.
- Map lifecycle persistence for `memo_versions`, `recycle_bin_items`, `memo_delete_tombstones`, `memo_relations_cache`, and `memo_inline_image_sources`.
- Extract `MemoLifecycleDbPersistence` or narrower owners for lifecycle schema, indexes, row mapping, and executor-based primitives.
- Preserve mixed transaction behavior for memo, outbox, search, recycle-bin, local-library, and lifecycle writes.
- Add behavior and architecture guardrails for migration compatibility, facade stability, upward imports, and transaction ownership.
- Run focused lifecycle, sync/mutation, migration, architecture, and analyzer checks; sync and archive the concrete lifecycle change when complete.

### Batch 3: AI Tables

- Create `decouple-ai-db-persistence` as a concrete OpenSpec change that references `db-persistence-boundaries`.
- Map AI persistence for `ai_memo_policy`, `ai_chunks`, `ai_embeddings`, `ai_index_jobs`, `ai_analysis_tasks`, `ai_analysis_results`, `ai_analysis_sections`, and `ai_analysis_evidences`.
- Extract `AiDbPersistence` or cohesive AI persistence owners for schema, indexes, additive column ensures, and executor-based primitives.
- Preserve AI search/indexing behavior, task state behavior, and existing public DB facade compatibility.
- Add guardrails that keep AI persistence independent of `features/`, `state/`, and `application/`.
- Run focused AI/search, DB, architecture, and analyzer checks; sync and archive the concrete AI change when complete.

### Batch 4: Collections

- Create `decouple-collections-db-persistence` as a concrete OpenSpec change that references `db-persistence-boundaries`.
- Map collection persistence for `memo_collections`, `memo_collection_items`, and `collection_read_progress`.
- Extract `CollectionDbPersistence` for collection schema, indexes, read progress columns, read queries, and executor-based primitives.
- Preserve collection ordering, archive/pin behavior, read progress behavior, and facade compatibility.
- Add behavior and architecture guardrails for collection persistence ownership.
- Run focused collection, DB, architecture, and analyzer checks; sync and archive the concrete collection change when complete.

### Batch 5: Small DB Tables

- Create `decouple-small-db-tables` as a concrete OpenSpec change that references `db-persistence-boundaries`.
- Re-evaluate whether `memo_reminders`, `import_history`, `memo_clip_cards`, and cache tables should move together or be grouped with more natural owners.
- Extract focused persistence owners for the selected small-table group without creating unnecessary one-file-per-table churn.
- Preserve row compatibility, ordering, filters, and existing facade behavior for selected small tables.
- Add behavior and architecture guardrails for selected small-table persistence ownership.
- Run focused DB, architecture, and analyzer checks; sync and archive the concrete small-table change when complete.

### Final Decision: Core Memos Table

- After batches 1-5 complete, re-assess whether `decouple-memo-core-db-persistence` is still valuable or should be explicitly deferred.
- If proceeding, create a dedicated high-risk OpenSpec change for the core `memos` table with migration, sync, search, tag, outbox, and facade compatibility explicitly scoped.
- If deferring, update `db-persistence-boundaries` with the accepted end state and rationale.
