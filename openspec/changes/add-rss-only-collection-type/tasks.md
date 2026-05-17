## 1. Collection Type and Model

- [x] 1.1 Add `MemoCollectionType.rss` and update collection serialization/deserialization fallbacks safely.
- [x] 1.2 Add RSS collection factory/defaults with RSS-appropriate icon, sort, and empty-state behavior.
- [x] 1.3 Audit collection type switches so `smart`, `manual`, and `rss` are handled explicitly.
- [x] 1.4 Ensure RSS collections are excluded from manual memo membership/add-to-collection flows.

## 2. RSS Collection Creation and Source Management

- [x] 2.1 Add RSS as a first-class option in collection creation.
- [x] 2.2 Add RSS creation flow with feed/site URL input, discovery/parse preview, and draft feed list.
- [x] 2.3 Allow one or more feeds to be attached before saving an RSS collection.
- [x] 2.4 Require at least one valid RSS/Atom feed before saving an RSS collection.
- [x] 2.5 Reuse existing RSS preview/subscription repository seams instead of duplicating parser/fetch logic in widgets.
- [x] 2.6 Provide a clear management entry for adding/removing feeds from an existing RSS collection.

## 3. RSS-Only Collection Surfaces

- [x] 3.1 Update collection list cards, labels, icons, filters, and diagnostics for RSS collections.
- [x] 3.2 Update dashboard/preview providers so RSS collection counts and latest timestamps reflect RSS articles, not memo items.
- [x] 3.3 Update reader/detail empty states for RSS collections with source-focused actions.
- [x] 3.4 Ensure smart-rule controls and manual memo picker controls are hidden for RSS collections.
- [x] 3.5 Ensure RSS collections render only RSS readable items and do not compose memo items.

## 4. Save-as-Memo Shortcut

- [x] 4.1 Add a visible article-scoped save-as-memo shortcut on RSS article list/detail rows or cards.
- [x] 4.2 Add a visible current-article save-as-memo shortcut in the reader toolbar or current item action area.
- [x] 4.3 Preserve the existing overflow/current item action as a fallback path.
- [x] 4.4 Show saved state for RSS articles that already have `saved_memo_uid`.
- [x] 4.5 Ensure shortcut actions save only the selected RSS article and never bulk-save a feed or collection.

## 5. Tests and Guardrails

- [x] 5.1 Add model/persistence tests for `MemoCollectionType.rss` round trips.
- [x] 5.2 Add tests for creating RSS collections with one feed and multiple feeds.
- [x] 5.3 Add resolver/provider tests proving RSS collections do not include memo items.
- [x] 5.4 Add UI tests for RSS creation option, empty-state source actions, and visible save-as-memo shortcuts.
- [x] 5.5 Add tests that add-to-collection/manual membership flows exclude RSS collections.
- [x] 5.6 Add or tighten architecture guardrails so RSS collection creation reuses RSS service/repository seams and does not move parsing/fetching into widgets.

## 6. Verification

- [x] 6.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 6.2 Run focused collection/RSS creation and save-as-memo shortcut tests.
- [x] 6.3 Run relevant architecture guardrail tests.
- [x] 6.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.5 Run `flutter test` from `memos_flutter_app`.
