## Context

Relevant existing shape:

```text
SettingsScreen
  -> FeedbackScreen
       -> ExportLogsScreen
       -> GitHub issue link

AppDatabase
  -> rebuildMemoTagsFromContent()
       AppDatabaseWriteDao
         -> MemoTagReconciler
         -> TagDbPersistence.updateMemoTagsMapping
         -> AppDatabase.updateMemoTagsText
              -> MemoSearchDbPersistence.refreshFtsEntryForMemo
              -> MemoSearchDbPersistence.markDirty
              -> StatsCacheDbPersistence.applyMemoCacheDelta

  -> rebuildStatsCache()
       StatsCacheDbPersistence.rebuildStatsCache

MemoSearchDbPersistence
  -> ensureFts(rebuild: true)
  -> ensureIndex(rebuild: true)
  -> drainDirtyEntries(...)
```

The tag refactor already created a controlled lower-layer operation to recompute stored memo tags from content. Search index rebuild support exists at the persistence layer, but the public maintenance facade should expose it through `AppDatabase` rather than requiring UI or state code to import `MemoSearchDbPersistence` directly.

## User Experience

Preferred page shape:

```text
Feedback
  - Submit logs
  - Self Repair
  - How to report

Self Repair
  [Repair abnormal tags]
    Rebuild memo tags from current memo content. This may remove stored tags
    that are not present as #tag text in the memo body.

  [Rebuild search index]
    Rebuild local keyword search data. Memo content is not deleted.

  [Rebuild statistics cache]
    Rebuild heatmap, tag stats, and summary counters.
```

The page should prefer explicit actions over one dangerous "reset database" button. Each action should have:

- localized title and description;
- confirmation before mutation;
- busy/disabled state while running;
- success result that names what completed;
- error state that preserves the page and suggests log export/reporting.

The tag repair copy must be extra clear because recomputing from content can remove tags that exist only in stored tag metadata and not in the memo body.

## Repair Semantics

### Abnormal tag cleanup

The operation should use the existing current-source-of-truth rule:

```text
memo.content
  -> extractTags(content)
  -> MemoTagReconciler.reconcile(...)
  -> memo_tags
  -> memos.tags
  -> FTS/search dirty state
  -> stats cache delta
```

This is a strict recompute from content. It is appropriate for cleaning historical false positives from Markdown code/link contexts. It is not a fuzzy detector for "probably fake" tags.

Open policy decision for implementation:

- The first version may run the existing strict operation directly, with explicit confirmation copy.
- A later version may add preflight counts or diff preview, but that should not be required for the first usable repair page unless implementation risk is low.

### Search index rebuild

The operation should rebuild local keyword search persistence without changing memo content:

```text
AppDatabase.rebuildMemoSearchIndex()
  -> MemoSearchDbPersistence.ensureFts(db, rebuild: true)
  -> MemoSearchDbPersistence.ensureIndex(db, rebuild: true)
  -> optionally drain dirty entries in bounded batches or let existing search paths drain
  -> notify data changed
```

`AppDatabase` should remain the facade/lifecycle owner. Feature or state code should not call `MemoSearchDbPersistence` directly.

### Stats cache rebuild

The operation should use the existing facade:

```text
AppDatabase.rebuildStatsCache()
```

This repair covers heatmap, tag stats, and summary count inconsistencies. It should not imply remote sync repair.

## Architecture

Target dependency direction:

```text
features/settings/self_repair_screen.dart
  -> state/maintenance/self_repair_service.dart
       -> data/db/AppDatabase
            -> AppDatabaseWriteDao
            -> MemoSearchDbPersistence
            -> StatsCacheDbPersistence
            -> TagDbPersistence / MemoTagReconciler
                 -> core/tags.dart
```

Feature UI responsibilities:

- render localized rows, descriptions, confirmations, loading states, and result messages;
- route user intent to the repair service/mutation seam;
- avoid direct SQL, direct persistence helper imports, or manual tag/search/stat rebuild sequences.

State/application seam responsibilities:

- expose focused methods such as `repairTagsFromContent`, `rebuildSearchIndex`, and `rebuildStatsCache`;
- serialize or reject concurrent repair operations for the current page/session;
- convert lower-layer errors into simple UI-consumable results without swallowing diagnostics.

Data-layer responsibilities:

- own the actual maintenance writes;
- preserve desktop write-proxy dispatch for write operations;
- keep transaction boundaries in approved owners;
- notify data changes after repair operations complete.

## Risks / Trade-offs

- Tag cleanup can remove stored tags that are not present in memo content. This is expected for strict repair, but the confirmation copy must say so plainly.
- Search index rebuild may be slow on large local libraries. The first version can show an indeterminate progress state; a later version can add batch progress if lower-layer APIs return counts.
- Running multiple repairs concurrently can create confusing result states. The self-repair service should serialize page-level actions or disable other actions while one is active.
- Desktop settings subwindows may use remote DB write gateways. Repair methods must use existing `AppDatabase` facade/write-proxy behavior so the owner window performs local writes safely.

## Open Questions

- Should the first version include a read-only preflight/diff for tag cleanup, or is explicit confirmation enough?
- Should "Rebuild search index" drain all dirty entries immediately, or is enqueuing all memos for rebuild plus existing lazy drain acceptable?
- Should all three repair actions be available as separate buttons only, or should the page also offer a combined "Run recommended repairs" action later?
