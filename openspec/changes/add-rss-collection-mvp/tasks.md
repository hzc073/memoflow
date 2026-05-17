## 1. Persistence and Models

- [x] 1.1 Add RSS-owned models for feeds, articles, feed preview/discovery results, and article read/saved state.
- [x] 1.2 Add focused RSS DB persistence for `rss_feeds`, `rss_articles`, and `collection_rss_sources`.
- [x] 1.3 Wire RSS table creation and migration through the existing focused DB persistence pattern.
- [x] 1.4 Add migration tests for new RSS tables and indexes.

## 2. Feed Parsing and Manual Refresh

- [x] 2.1 Add RSS/Atom parser behavior for common feed metadata and article entries.
- [x] 2.2 Add basic HTML feed discovery for alternate RSS/Atom links.
- [x] 2.3 Add a fetch service that supports manual refresh and preserves existing local article state on upsert.
- [x] 2.4 Add parser/fetch tests covering RSS, Atom, duplicate articles, malformed feeds, and network failure reporting.

## 3. Collection Source Integration

- [x] 3.1 Add repository methods to attach/detach feeds from collections and list collection RSS sources.
- [x] 3.2 Introduce a collection readable-item seam that can represent memo items and RSS article items.
- [x] 3.3 Update collection resolver/provider code to compose memo items and RSS articles without converting RSS articles to `LocalMemo`.
- [x] 3.4 Preserve existing smart/manual memo collection behavior and tests.

## 4. UI and Reader MVP

- [x] 4.1 Add a collection-level RSS subscription flow with URL input, discovery/parse preview, and collection attachment.
- [x] 4.2 Add manual refresh actions and loading/error feedback for collection RSS sources.
- [x] 4.3 Render RSS articles in collection detail and reader surfaces with source, title, time, and available content.
- [x] 4.4 Hide memo-only actions for RSS articles and expose RSS-appropriate actions such as mark read/unread, open original, and save as memo.

## 5. Save as Memo

- [x] 5.1 Add an explicit save-as-memo flow for RSS articles using existing memo creation/mutation seams.
- [x] 5.2 Store `saved_memo_uid` on the RSS article after successful save.
- [x] 5.3 Include source attribution and clip-card metadata for saved articles.
- [x] 5.4 Add tests that saving an RSS article creates a memo only after explicit action and does not duplicate saved state incorrectly.

## 6. Modularity and Guardrails

- [x] 6.1 Add or tighten architecture guardrails so RSS DB persistence remains in the data layer.
- [x] 6.2 Add guardrail coverage preventing lower layers from importing collection or share UI while handling RSS parsing/fetching.
- [x] 6.3 Ensure no Memos API files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` are touched.

## 7. Verification

- [x] 7.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 7.2 Run focused RSS parser/repository/provider tests.
- [x] 7.3 Run focused collection reader/detail tests.
- [x] 7.4 Run relevant architecture guardrail tests.
- [x] 7.5 Run `flutter analyze` from `memos_flutter_app`.
- [x] 7.6 Run `flutter test` from `memos_flutter_app`.
