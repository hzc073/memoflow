## Why

RSS 浏览时出现连续 Flutter layout errors，典型日志包含：

- `RenderBox.size accessed in RenderImage.computeDryBaseline`
- `_RenderCssSizing.performLayout`
- `RenderPointerListener does not meet its constraints`
- `BoxConstraints(0.0<=w<=20.7, 0.0<=h<=Infinity)` with `Size(48.0, 48.0)`

问题指向 `flutter_widget_from_html` 将 RSS HTML 中的 image/media 或带图链接作为 inline widget 渲染。当图片出现在段落或链接内部时，剩余 inline 行宽可能非常窄，导致图片/gesture/semantics widget 被压进不可满足的 baseline/size 约束中，产生重复异常并造成 RSS 阅读卡顿。

本 change 记录已实施的渲染层修复：为 RSS HTML 正文增加一个 feature-local rendering seam，统一约束 `img`、`video`、`figure` 和包含媒体的 `a` 元素，使媒体以 block 形式占用内容宽度，而不是参与窄 inline baseline 布局。

## What Changes

- Add `CollectionRssHtmlContent` as the shared RSS HTML body renderer under `features/collections`.
- Apply RSS-specific HTML styles through `customStylesBuilder`:
  - `img` / `video`: `display: block`, `max-width: 100%`, `height: auto`, `min-width: 0`, vertical margin.
  - media-containing `a`: `display: block`, `max-width: 100%`, `min-width: 0`.
  - `figure`: block layout with bounded width.
- Replace direct `HtmlWidget` usage in:
  - `CollectionReaderVerticalView`
  - `CollectionArticleFlowScreen`
- Add a focused widget test for narrow selectable RSS content containing a linked image.

## Impact

- Runtime area: RSS article body rendering in continuous reader and article-flow detail.
- No RSS fetch, parser, sanitizer, repository, database, API model, route adapter, or version compatibility change.
- No files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.
- No commercial/private-extension behavior.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - item 4: avoid reused rendering behavior hidden separately in multiple screen/widget files.
  - item 10: touched collection reader area is left equal or better structured.
- Modularity improvement: direct duplicated `HtmlWidget` setup is isolated behind a feature-local RSS HTML rendering seam.

## Non-Goals

- Do not change RSS article parsing, sanitization, or full-content extraction.
- Do not alter image caching, download, or preview behavior.
- Do not add new user-visible settings.
- Do not change reader progress, RSS read state, or save-as-memo behavior.
