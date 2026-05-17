## Why

After the Markdown-aware tag refactor, users may still have historical local data where code fragments such as `#include`, Markdown link fragments, or stale tag payloads were persisted as memo tags. The app already has lower-layer maintenance primitives for recomputing memo tags from content and rebuilding stats cache data, and the search persistence layer has rebuild support for local search indexes. These tools are useful when users see broken tags, missing search results, or inconsistent statistics, but they are not currently exposed as a clear, user-triggered recovery flow.

This change adds a `Settings -> Feedback -> Self Repair` entry because users naturally visit feedback/logging surfaces when something is wrong. The repair flow should help users resolve known local-data inconsistencies before filing an issue, while keeping high-risk database operations out of scope.

## What Changes

- Add a self-repair entry from the feedback/settings support area.
- Add a dedicated self-repair page for local maintenance actions.
- Expose a user-triggered repair that recomputes memo tags from memo content using the current shared tag extractor and reconciliation rules.
- Expose a user-triggered local keyword search index rebuild.
- Expose a user-triggered stats cache rebuild for heatmap, tag stats, and summary inconsistencies.
- Present clear confirmation, progress, success, and failure states so users understand what will change.
- Route repair actions through a state/application service seam instead of embedding repair orchestration in feature widgets.

## Capabilities

### New Capabilities

- `self-repair-tools`: Defines user-triggered local maintenance tools, including tag cleanup, local search index rebuild, stats cache rebuild, UX safeguards, and modular ownership rules.

### Related Capabilities

- `memos-tag-compatibility`: The tag cleanup action uses the existing Markdown-aware extraction and reconciliation policy.
- `memo-search`: The search rebuild action preserves local literal substring search semantics while rebuilding persistence indexes.
- `db-persistence-boundaries`: Repair orchestration must respect AppDatabase facade, write-owner, and focused persistence-owner boundaries.

## Impact

- Affected runtime areas: `memos_flutter_app/lib/features/settings/feedback_screen.dart`, a new self-repair settings screen, a state/application repair service or mutation seam, `AppDatabase` maintenance facade methods, search persistence rebuild exposure, stats cache rebuild, localization, and focused UI/service tests.
- Affected data behavior: local memo tag mappings, redundant `memos.tags`, FTS/search index rows, search dirty rows, and stats cache rows may be rebuilt by explicit user action.
- No Memos server API route, request/response model, version adapter, or files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` are intended for this change.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 because repair orchestration must not hide reusable maintenance logic in screens/widgets; item 7 because repair write paths need clear owners; item 8 because guardrails/tests should prevent boundary regressions; item 10 because touched coupled data-maintenance areas must be left equal or better structured than before.
- Scoped modularity improvement: introduce or use a focused self-repair service/mutation seam so feature UI only renders state and routes user intent, while data-layer maintenance remains behind approved `AppDatabase` facade and persistence owners.

## Non-Goals

- Do not delete, reset, or recreate the entire local SQLite database.
- Do not clear user accounts, preferences, attachments, local library files, or WebDAV backup data.
- Do not repair remote server data or change remote sync conflict policy.
- Do not add commercial/private repair behavior or subscription-gated maintenance tools.
- Do not silently run tag cleanup during app startup or upgrade.
- Do not change Memos server API compatibility files unless separately approved.
