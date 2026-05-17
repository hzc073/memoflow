## Context

The active architecture phase is `evolve_modularity`. The touched area is the share parser seam, not the known reverse-dependency hotspots. The implementation should still leave the area more explicit by moving Xiaohongshu-specific note evidence and cleanup rules into a focused helper.

## Design

Add `xiaohongshu_note_content_cleaner.dart` under `features/share/parsers`.

The helper returns a plain result containing:

- cleaned `contentHtml`
- cleaned `textContent`
- resolved `title`
- target note `noteType`
- normalized `imageAttachmentUrls`
- `hasArticleBody`
- `isVideoNote`

`XiaohongshuSharePageParser` will build candidate roots from existing bridge/network data, call the helper, and then classify the target note with target-scoped evidence:

- video when target note type/video candidates indicate the target note itself is video
- article when target note body or image URLs exist
- unknown otherwise

The parser must not classify an image note as video solely because unrelated deep values under recommendations, comments, or author-other-notes contain `type: video`.

## URL Normalization

The helper normalizes Xiaohongshu image CDN URLs from `http` to `https` when the host is a known Xiaohongshu image CDN such as `xhscdn`, `sns-webpic`, `sns-img`, or `sns-na`. This gives the formatter and inline image downloader HTTPS URLs before WebView mixed-content blocking can remove them from useful capture output.

## Boundaries

Before: Xiaohongshu parsing used broad deep scans directly inside `XiaohongshuSharePageParser`.

After: target-note cleanup and image URL normalization live in a parser helper. Existing generic `ShareCaptureResult` and quick clip media paths remain unchanged.

No new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies are introduced.
