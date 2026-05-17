## 1. Reading Experience Model and Routing

- [x] 1.1 Add a collection-scoped reading experience model with `articleFlow` and `continuousReader`.
- [x] 1.2 Define default experience resolution by collection type, with RSS defaulting to article flow and smart/manual defaulting to continuous reader.
- [x] 1.3 Persist user switching as a per-collection preference.
- [x] 1.4 Update collection detail routing so it opens the selected reading experience instead of always opening the continuous reader.
- [x] 1.5 Keep existing `CollectionReaderShell` behavior available as continuous reader.

## 2. Article Flow List

- [x] 2.1 Add an article-flow list surface for `CollectionReadableItem` values.
- [x] 2.2 Support RSS filters for all, unread, read, saved, feed, and date.
- [x] 2.3 Show feed icon, feed name, title, excerpt, display time, thumbnail, unread state, and saved state where available.
- [x] 2.4 Add first-pass built-in swipe actions for read/unread and save-as-memo.
- [x] 2.5 Add mark-above-as-read and mark-below-as-read actions for RSS article lists.
- [x] 2.6 Ensure memo items in article-flow mode do not show RSS-only actions.

## 3. Single Article Detail and Adaptive Layout

- [x] 3.1 Add mobile single-article detail navigation from the article flow list.
- [x] 3.2 Add tablet/desktop list-detail two-pane layout.
- [x] 3.3 Mark RSS articles read immediately when opened.
- [x] 3.4 Add top actions for back/close, share, and open original.
- [x] 3.5 Add bottom actions for read/unread, save as memo, next article, and full-content fetch/retry.
- [x] 3.6 Implement next article as the next item in the current filtered list.
- [x] 3.7 Reuse existing reader typography/style preferences for article body rendering.
- [x] 3.8 Show full-content failed/skipped states with fallback content, retry when eligible, and open-original escape hatch.

## 4. Display Settings and Progress

- [x] 4.1 Add collection-scoped article-flow display settings for excerpt, thumbnail, feed icon, density, and auto-hide toolbar.
- [x] 4.2 Default auto-hide article toolbar to enabled.
- [x] 4.3 Store article-flow progress separately from continuous reader progress.
- [x] 4.4 Restore article-flow filter state, list scroll position, and selected/current item without corrupting continuous reader restore.

## 5. Localization

- [x] 5.1 Add Chinese/default i18n strings for article flow, filters, actions, display settings, and failure states.
- [x] 5.2 Add German i18n strings for the same user-facing labels.
- [x] 5.3 Ensure generated localization remains consistent with existing i18n workflow.

## 6. Modularity and Guardrails

- [x] 6.1 Keep reusable RSS filtering/action/routing logic outside large widget files where it will be reused or tested.
- [x] 6.2 Add or tighten architecture guardrails so `state/collections`, `application/rss`, `data`, and `core` do not import collection article-flow widgets.
- [x] 6.3 Add tests that RSS article-flow opening marks articles read but does not create memos automatically.
- [x] 6.4 Add tests that save-as-memo is explicit, article-scoped, and does not duplicate saved memos.
- [x] 6.5 Add tests or guardrails ensuring no commercial/private-extension hooks are introduced into public collection/RSS shells.

## 7. Verification

- [x] 7.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 7.2 Run focused RSS collection/reader tests.
- [x] 7.3 Run relevant architecture guardrail tests.
- [x] 7.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 7.5 Run `flutter test` from `memos_flutter_app`.
