## 1. Full-Content State

- [x] 1.1 Add RSS-owned full-content fields or companion table for extracted article content and fetch status.
- [x] 1.2 Add per-feed full-content preference state.
- [x] 1.3 Add migration/backfill behavior that preserves existing RSS article content.

## 2. Fetch and Extraction Service

- [x] 2.1 Add an RSS full-content service with timeout, size, redirect, and content-type constraints.
- [x] 2.2 Add readable-content extraction for fetched article pages.
- [x] 2.3 Add HTML sanitization before storing or rendering extracted content.
- [x] 2.4 Record article-local full-content success, skipped, and failure metadata.
- [x] 2.5 Keep extraction and sanitization services outside collection widgets.

## 3. Reader Integration

- [x] 3.1 Update RSS article reader content selection to prefer extracted full content when available.
- [x] 3.2 Preserve feed content and summary fallback when full-content fetch fails or is unavailable.
- [x] 3.3 Add manual per-article full-content fetch and retry actions.
- [x] 3.4 Add per-feed full-content opt-in controls.
- [x] 3.5 Ensure "save as memo" remains an explicit action and uses the current readable RSS content only when invoked.

## 4. Optional Refresh Integration

- [x] 4.1 If background refresh is present, integrate full-content fetching behind the per-feed opt-in setting.
- [x] 4.2 Bound full-content fetch concurrency separately from feed XML refresh.
- [x] 4.3 Ensure full-content failures do not fail the feed refresh run.

## 5. Tests and Guardrails

- [x] 5.1 Add tests for content selection order and fallback.
- [x] 5.2 Add tests for successful extraction and sanitized storage.
- [x] 5.3 Add tests for timeout, unsupported content type, oversized response, and extraction failure.
- [x] 5.4 Add tests that full-content fetch does not create memos automatically.
- [x] 5.5 Add or tighten guardrails so reusable extraction logic does not live inside widgets or import feature UI into lower layers.

## 6. Verification

- [x] 6.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 6.2 Run focused RSS full-content tests.
- [x] 6.3 Run relevant architecture guardrail tests.
- [x] 6.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.5 Run `flutter test` from `memos_flutter_app`.
