## Context

Memos `0.27.1` exposes tags in two relevant API surfaces:

- `Memo.tags`, populated from the server-side Markdown payload extraction.
- `UserStats.tag_count`, used by the official web client for tag counts.

The Flutter app currently reads `Memo.tags`, merges remote tags with content-derived tags during remote sync, stores canonicalized tag paths in SQLite, and displays tags through `tagStatsProvider`. The weak point is not the route itself; it is grammar drift. The backend accepts additional tag characters such as `&`, Unicode marks, variation selectors, and ZWJ emoji sequences, while the app's `core/tags.dart` grammar strips or misses some of those characters. The app's fallback content extraction also only scans the first and last non-empty lines, which can miss valid tags when backend payload tags are empty or stale.

This change is in architecture phase `evolve_modularity`. It touches shared domain parsing and tag sync, so the design keeps dependency direction stable:

- Before: `core/tags.dart` owns shared tag helpers; `state/memos` and `state/tags` consume them; UI consumes `tagStatsProvider`.
- After: the same direction remains; the shared grammar is tightened in `core`, and UI widgets/screens do not gain parsing responsibilities.

Relevant modularity checklist items:

- Item 4: shared domain logic must not be hidden in screens or widgets.
- Item 8: regression tests should guard the tag grammar and v0.27 API/sync behavior.

## Goals / Non-Goals

**Goals:**

- Align local tag grammar with Memos `0.27.x` for the characters the backend accepts in tag names.
- Preserve non-empty backend `Memo.tags` values exactly enough that valid v0.27 tags appear in local tag lists and tag statistics.
- Make fallback extraction scan all relevant memo content lines so middle-line tags are not missed when backend tag payloads are unavailable.
- Add focused tests for v0.27 non-empty `tags`, `#science&tech`, complex emoji/ZWJ tags, and multi-line fallback extraction.
- Keep tag grammar centralized in `core/tags.dart` and consumed by data/state/UI layers through existing seams.

**Non-Goals:**

- Do not introduce a new tag metadata model for Memos instance `tags_setting`, blur content, or server-side tag colors.
- Do not switch the Flutter tag list to read `UserStats.tag_count` directly in this change.
- Do not add new SQLite tables or migrate the local tag schema.
- Do not change private/commercial hooks or public shell extension seams.
- Do not broaden unrelated API version compatibility behavior beyond v0.27 tag handling.

## Decisions

### Decision 1: Treat `core/tags.dart` as the single app-side tag grammar seam

The v0.27-compatible grammar should live in `core/tags.dart`, because existing sync, mutation, search, autocomplete, and UI flows already consume this seam.

Alternatives considered:

- Add v0.27-specific parsing inside sync code. Rejected because it duplicates shared domain logic in `state/memos` and risks drift.
- Add display-only cleanup in tag widgets. Rejected because it hides shared logic in UI and violates modularity item 4.

### Decision 2: Preserve backend tags first, then use content fallback as a safety net

Remote sync should continue merging backend `Memo.tags` with content-derived tags, but normalization must no longer strip valid v0.27 characters. Backend tags are authoritative when present; content extraction is fallback/augmentation for stale or absent payload tags.

Alternatives considered:

- Trust backend tags only. Rejected because stale payloads or older imported data can omit tags even when content contains valid `#tags`.
- Recompute all tags only from content. Rejected because the backend already exposes canonical extracted tags and may parse Markdown edge cases more accurately.

### Decision 3: Expand fallback extraction without intentionally matching protected URL/link fragments

Fallback extraction should scan all non-empty lines, while preserving the current protection against Markdown links, inline URLs, escaped hashes, headings, and adjacent tag characters.

Alternatives considered:

- Keep scanning first/last non-empty lines only. Rejected because it directly explains the reported multi-line miss case.
- Use a full Markdown parser dependency. Rejected for this scoped compatibility fix; the existing lightweight parser can be aligned with the backend grammar without adding a dependency.

### Decision 4: Use regression tests as the modularity guardrail

The implementation should add tests at the lowest stable layer that owns behavior:

- `test/core/tags_test.dart` for grammar and fallback extraction.
- v0.27 API route/model tests under `test/data/api` for non-empty `tags` payloads.
- focused sync/state tests under `test/state/memos` to prove tags survive remote sync into SQLite tag stats.

Alternatives considered:

- Only widget tests. Rejected because rendering failures are downstream symptoms and would not protect parsing/sync ownership.

### Decision 5: No schema migration

The existing local tables (`memos.tags`, `tags`, `memo_tags`, `tag_stats_cache`) can represent v0.27-compatible tag paths as strings. A schema migration is unnecessary.

Existing cached rows that were previously normalized incorrectly may need a resync or stats rebuild to correct historical data, but that can be handled by normal sync/cache update paths unless implementation discovers a reproducible stale-cache blocker.

## Risks / Trade-offs

- Parser overmatches protected text → Keep existing protected range checks and add tests for URL fragments and Markdown links.
- Backend grammar still differs in full Markdown edge cases → Document the app-side grammar as compatibility-focused, not a full backend Markdown AST implementation.
- Complex Unicode handling varies by Dart regex support → Add explicit tests for ampersand, combining/variation marks, and ZWJ emoji sequences.
- Existing local caches may already contain stripped tag names → Prefer sync/cache refresh over schema migration; call out any residual manual resync need if discovered during implementation.
- API compatibility files are in scope → Implementation must get explicit user approval before editing `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.

## Migration Plan

1. Update shared tag grammar and fallback extraction in `core/tags.dart`.
2. Add focused grammar tests before or alongside implementation.
3. Add v0.27 API payload coverage proving non-empty `Memo.tags` are parsed.
4. Add sync/state coverage proving v0.27 tags become local tag stats.
5. Run focused checks first, then the API compatibility suite after API route/test changes.

Rollback is straightforward: revert the parser/test changes. No data schema rollback is required.

## Open Questions

- Should implementation include a one-time local stats rebuild for users who already synced v0.27 tags before the fix, or is a normal remote resync sufficient?
- Which exact complex emoji sample should be used in tests to avoid platform/font ambiguity while still exercising ZWJ or variation selectors?
