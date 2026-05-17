## Why

Users report that Memos API `0.27.x` tags are not displayed correctly in the Flutter app. Initial investigation found that the `0.27.1` backend returns `Memo.tags` and `UserStats.tag_count`, but the app's local tag grammar and fallback extraction do not fully match the backend, so valid tags such as `#science&tech`, complex emoji tags, and tags outside the first/last non-empty lines can be normalized incorrectly or missed.

## What Changes

- Align the app's tag parsing and normalization contract with Memos `0.27.x` backend tag grammar for tag characters that the backend treats as valid.
- Preserve backend-provided non-empty `Memo.tags` when syncing v0.27 memos, including tags containing ampersands, Unicode marks, variation selectors, and ZWJ emoji sequences.
- Improve fallback content-based tag extraction so multi-line memo content does not silently miss valid tags when backend payload tags are absent or stale.
- Add v0.27-focused API and sync coverage for non-empty `tags`, `#science&tech`, complex emoji tags, and tags appearing in middle lines.
- Keep tag-display data ownership in stable layers (`core`, `data/api`, `state/memos`, `state/tags`) and avoid moving shared tag grammar into UI widgets or screens.

## Capabilities

### New Capabilities
- `memos-tag-compatibility`: Defines how the Flutter app recognizes, preserves, syncs, and displays Memos tags across API versions, with explicit coverage for Memos `0.27.x` tag grammar.

### Modified Capabilities
- None.

## Impact

- Affected app areas: `memos_flutter_app/lib/core/tags.dart`, memo JSON parsing and v0.27 route compatibility tests, remote sync tag merging, local tag statistics/cache updates, and tag display consumers that depend on `tagStatsProvider`.
- Affected tests: API compatibility tests under `memos_flutter_app/test/data/api`, tag grammar tests under `memos_flutter_app/test/core`, and focused remote sync/state tests under `memos_flutter_app/test/state/memos`.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 (`No reused shared domain logic hidden inside screen or widget files`) because shared tag grammar should remain centralized in `core` rather than UI code; item 8 because guardrail-style regression tests should prevent future tag grammar drift.
- Scoped modularity improvement: consolidate v0.27-compatible tag grammar behavior in the existing `core/tags.dart` seam and keep sync/display layers consuming that seam instead of duplicating parser logic.
- API-related code is in scope for implementation, so actual edits to `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` require explicit user approval before implementation.
