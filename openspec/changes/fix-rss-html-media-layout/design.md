## Context

RSS article content is rendered from sanitized/feed-provided HTML. Before this change, both continuous reader and article-flow detail built `HtmlWidget` directly:

```text
CollectionReaderVerticalView
  -> HtmlWidget(item.content)

CollectionArticleFlowScreen
  -> HtmlWidget(item.content)
```

This left RSS media layout to the package defaults. For HTML shaped like:

```html
<p>Before <a href="..."><img src="..."></a> after.</p>
```

`img` can be flattened as an inline widget. When the line has only a narrow remaining width, Flutter tries to dry-layout or baseline-measure image/gesture/semantics render objects under constraints around `20.7px`, while the child wants an intrinsic `48px` loading/gesture size. The repeated layout exceptions cause visible stutter.

## Design

Introduce `CollectionRssHtmlContent` in `features/collections` as the only RSS HTML renderer for collection reader surfaces.

```text
CollectionReaderVerticalView
  -> CollectionRssHtmlContent
       -> HtmlWidget + RSS customStylesBuilder

CollectionArticleFlowScreen
  -> CollectionRssHtmlContent
       -> HtmlWidget + RSS customStylesBuilder
```

The renderer keeps the same package and render mode, but adds media-specific CSS:

```text
img, video:
  display: block
  max-width: 100%
  height: auto
  min-width: 0

a containing img/video:
  display: block
  max-width: 100%
  min-width: 0

figure:
  display: block
  max-width: 100%
  min-width: 0
```

This forces media out of narrow inline baseline layout and keeps it within the reader column width.

## Dependency Direction

Before:

```text
features/collections/collection_reader_vertical_view.dart
  -> flutter_widget_from_html

features/collections/collection_article_flow_screen.dart
  -> flutter_widget_from_html
```

After:

```text
features/collections/collection_reader_vertical_view.dart
  -> features/collections/collection_rss_html_content.dart
      -> flutter_widget_from_html

features/collections/collection_article_flow_screen.dart
  -> features/collections/collection_rss_html_content.dart
      -> flutter_widget_from_html
```

No lower layer imports `features/collections`. No `state`, `application`, `data`, or `core` dependency direction changes are introduced.

## Modularity

The active phase is `evolve_modularity`. This change does not touch a known reverse-dependency hotspot, but it does touch a coupled collection reader area. The improvement is scoped seam extraction:

- RSS HTML rendering rules live in one feature-local widget instead of being repeated in multiple reader screens.
- Future RSS HTML rendering adjustments can be made without expanding `CollectionReaderVerticalView` or `CollectionArticleFlowScreen`.
- Domain/application concerns remain outside widgets; parser/sanitizer/fetcher logic is unchanged.

## Verification Strategy

- Add a widget test that pumps `CollectionRssHtmlContent` in a `32px` wide `SelectionArea` with a linked image.
- Run `flutter analyze`.
- Run `flutter test test/features/collections --reporter expanded`.

## Risks

- Some feeds may rely on inline small icons inside text. The chosen rule prioritizes stability and readable article layout over preserving inline icon flow in RSS article bodies.
- Existing sanitized HTML may include width/height attributes. `max-width: 100%` and `height: auto` should keep those images bounded without changing parser behavior.
