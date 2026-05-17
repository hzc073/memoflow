## Context

The remaining small DB table surfaces have different coupling levels:

- `memo_reminders` has simple schema, reads, writes, and UID rename behavior.
- `import_history` has simple schema, lookup, upsert, and update behavior.
- `memo_clip_cards` has simple schema and row primitives, but changes must still refresh memo search entries.
- stats caches are more complex because they are maintained by memo write deltas and read by state providers.

This change extracts the first three tables and leaves stats cache for a later dedicated decision.

## Decisions

### Decision 1: Use one memo-adjacent auxiliary owner

`MemoAuxiliaryDbPersistence` will own:

- `ensureMemoReminderTable`
- `ensureImportHistoryTable`
- `ensureMemoClipCardsTable`
- reminder reads/writes and reminder UID rewrite
- import-history reads/writes
- clip-card reads and row upsert/delete primitives

This avoids unnecessary one-file-per-table churn while keeping unrelated stats-cache complexity out of scope.

### Decision 2: Keep orchestration outside the persistence seam

`AppDatabase` remains lifecycle/facade owner.

`AppDatabaseWriteDao` remains transaction/notification owner. For clip-card mutations, it continues to refresh memo search rows in the same transaction after delegating the `memo_clip_cards` row primitive.

### Decision 3: Preserve migration ordering

The existing ordering remains:

- version 4 creates `import_history`
- version 5 creates `memo_reminders`
- version 25 creates `memo_clip_cards`

`onOpen` still ensures clip-card table availability for compatibility.

## Dependency Direction

Before:

```text
AppDatabase -> auxiliary schema + auxiliary reads
AppDatabaseWriteDao -> auxiliary row primitives + transaction/notify
```

After:

```text
AppDatabase -> lifecycle/facade delegation -> MemoAuxiliaryDbPersistence
AppDatabaseWriteDao -> transaction/notify/search refresh -> MemoAuxiliaryDbPersistence
MemoAuxiliaryDbPersistence -> sqflite + data-layer models
```

This does not add new `state -> features`, `application -> features`, or `core -> higher layer` imports.

## Risks

- Clip-card writes affect search results. Preserve FTS refresh in the DAO transaction.
- Reminder UID rewrite happens inside memo UID rename. Keep that inside the existing rename transaction.
- Stats cache remains in `AppDatabase`; guardrails should not block its existing SQL until a dedicated stats-cache extraction is scoped.
