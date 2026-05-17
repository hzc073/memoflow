## Why

Full quick clip can save a Xiaohongshu image note without its body text or images when the page contains unrelated video records in comments, recommendations, or author sidebars. The current parser scans broad page state for `type: video`, so a normal image note can be classified as `video`. The formatter then uses the compact video memo body and drops the captured article body.

The same capture path can also miss Xiaohongshu images because note image URLs are commonly emitted as `http://sns-webpic...` on an HTTPS page, causing WebView mixed-content blocking before inline image discovery sees usable `img[src]` nodes.

## What Changes

- Add a Xiaohongshu-specific note content cleanup/helper under the share parser seam.
- Scope Xiaohongshu note kind detection to the target note body/evidence rather than broad page state.
- Preserve target note title/body text for image/article notes even when unrelated recommended videos exist elsewhere in the page.
- Normalize Xiaohongshu image CDN URLs from `http` to `https` for capture HTML and parser-level image attachment URLs.
- Add parser/formatter regression coverage for image notes with unrelated video records.

## Capabilities

### Modified Capabilities

- `xiaohongshu-share-capture`
- `xiaohongshu-share-media-attachments`

## Impact

- Affected app code:
  - `memos_flutter_app/lib/features/share/parsers/xiaohongshu_share_page_parser.dart`
  - new `memos_flutter_app/lib/features/share/parsers/xiaohongshu_note_content_cleaner.dart`
  - focused share parser/formatter tests
- No Memos server API routes, request/response models, or API compatibility tests are changed.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 4 and item 10. The change extracts Xiaohongshu-specific note classification/cleanup out of broad parser logic into a focused share parser helper, keeping platform-specific parsing inside `features/share/parsers` and avoiding new `state`, `application`, or `core` dependencies.

## Non-Goals

- Do not add private/commercial behavior.
- Do not change generic video detection for non-Xiaohongshu pages.
- Do not implement a full Xiaohongshu private API client.
