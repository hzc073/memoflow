## Why

小红书视频分享页会在 H5 加载时自动跳转 `xhsdiscover://...` App deep link，当前剪藏 WebView 会把 Chromium 的 `ERR_UNKNOWN_URL_SCHEME` 错误页当作正文保存，导致剪藏内容变成“网页无法打开”。现在需要从根上阻止错误页进入剪藏结果，并复用 deep link 中已有的视频标题、封面和直链候选，让小红书视频剪藏可用。

## What Changes

- Add Xiaohongshu deep link capture support for `xhsdiscover://video_feed/...` URLs observed during share-page loading.
- Prevent non-HTTP(S) main-frame navigation errors from being captured as article content.
- Extract Xiaohongshu-specific deep link parsing into a narrow parser/helper under `features/share/parsers`, keeping the generic WebView capture engine platform-neutral.
- Convert valid Xiaohongshu deep link payloads into existing video capture results with direct video candidates, title, cover image, and original note URL where available.
- Add focused unit tests for deep link parsing, WebView/error-page safeguards, and formatter/controller behavior as needed.
- No breaking changes to existing memo storage, sync, public/private extension seams, or non-Xiaohongshu share capture flows.

## Capabilities

### New Capabilities
- `xiaohongshu-share-capture`: Covers Xiaohongshu share-page capture behavior, especially App deep link interception, video candidate extraction, and protection against saving browser unknown-scheme error pages.

### Modified Capabilities
- None.

## Impact

- Affected runtime code stays scoped to `memos_flutter_app/lib/features/share/**`, especially the WebView capture engine and share parsers.
- Affected tests are expected under `memos_flutter_app/test/features/share/**`.
- No API route/version changes, no request/response model changes, and no files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`.
- Architecture phase is `evolve_modularity`; this change touches modularity checklist item 4 by preventing platform-specific parsing logic from being hidden inside UI or generic engine code. The scoped modularity improvement is a dedicated Xiaohongshu parser/helper seam instead of spreading platform branching into screens or startup coordination.
- The change must not introduce new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies. Existing `application/startup` share-flow coupling should remain unchanged, not expanded.
