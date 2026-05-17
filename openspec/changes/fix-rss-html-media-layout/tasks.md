## 1. RSS HTML Rendering Seam

- [x] 1.1 Add `CollectionRssHtmlContent` as a shared renderer for RSS HTML article bodies.
- [x] 1.2 Add RSS-specific media styles for `img`, `video`, media-containing `a`, and `figure`.
- [x] 1.3 Replace direct RSS `HtmlWidget` usage in `CollectionReaderVerticalView`.
- [x] 1.4 Replace direct RSS `HtmlWidget` usage in `CollectionArticleFlowScreen`.

## 2. Tests

- [x] 2.1 Add a focused widget test for narrow selectable RSS content with a linked image.
- [x] 2.2 Verify the test does not report Flutter layout exceptions.

## 3. Verification

- [x] 3.1 Run `dart format` on changed Dart files.
- [x] 3.2 Run `flutter test test/features/collections/collection_rss_html_content_test.dart --reporter expanded`.
- [x] 3.3 Run `flutter analyze`.
- [x] 3.4 Run `flutter test test/features/collections --reporter expanded`.

## 4. OpenSpec

- [x] 4.1 Record proposal, design, tasks, and delta spec for `fix-rss-html-media-layout`.
