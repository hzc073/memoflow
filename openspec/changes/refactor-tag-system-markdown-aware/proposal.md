## Why

Issue `hzc073/memoflow#203` shows the current tag extractor can treat code content such as `#include` as a memo tag. The app already has a richer tag storage model (`tags`, `tag_aliases`, `memo_tags`, redundant `memos.tags`, and tag stats), but tag recognition is still centered on line-by-line string scanning in `core/tags.dart`. That makes Markdown contexts such as fenced code, inline code, and link destinations easy to overmatch.

This change defines the rules for a broader tag-system cleanup: make tag extraction Markdown-aware, centralize tag normalization and reconciliation, and keep persisted tag indexes consistent without moving shared tag logic into feature UI.

## What Changes

- Replace whole-content line scanning with a Markdown-aware tag extraction contract.
- Keep tag character compatibility from `memos-tag-compatibility` while excluding Markdown code/link contexts from extraction.
- Define a shared tag reconciliation seam so memo create/edit/import/sync paths derive canonical tags consistently.
- Treat `memo_tags` as the relationship/statistics source of truth while keeping `memos.tags` as a synchronized compatibility/search payload.
- Add a controlled maintenance path to recompute stored memo tags from content when tag rules change or historical false positives need cleanup.
- Add focused regression tests and architecture guardrails for parsing, persistence consistency, and lower-layer ownership.

## Capabilities

### Modified Capabilities

- `memos-tag-compatibility`: Adds Markdown-aware extraction, canonical tag reconciliation, persistence consistency, and maintenance rebuild requirements.

## Impact

- Affected runtime areas: `memos_flutter_app/lib/core/tags.dart`, memo mutation/write paths, import/sync paths that call `extractTags`, `TagDbPersistence`, `AppDatabaseWriteDao`, tag stats, search indexing, and tag display consumers.
- Affected tests: `test/core/tags_test.dart`, focused state/data tests around memo writes and tag stats, search consistency tests, and architecture guardrails for shared tag logic ownership.
- No Memos server API route, request/response model, version adapter, or files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` are intended for this change.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 because shared tag parsing/reconciliation must stay out of screens/widgets; item 7 because touched memo write paths need clear owners; item 8 because guardrails should prevent parser drift and boundary regressions; item 10 because coupled tag write areas must be left equal or better structured.
- Scoped modularity improvement: extract or formalize stable lower-layer seams for tag extraction and tag reconciliation so feature UI and state code consume shared behavior instead of duplicating parsing rules.

## Non-Goals

- Do not redesign the tag editing UI in this change.
- Do not add commercial/private tag behavior or subscription-gated tag state.
- Do not change Memos server API compatibility files unless separately approved.
- Do not remove the existing `tags`, `tag_aliases`, `memo_tags`, or `memos.tags` storage model.
- Do not change public tag character grammar except where required to make extraction Markdown-aware.
