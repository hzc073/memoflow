## Context

第三方分享剪藏当前通过 `ShareCaptureInAppWebViewEngine` 使用 headless `flutter_inappwebview` 加载分享页，再运行 DOM/readability bridge，并把结果交给通用和平台专用 `SharePageParser` 合并。小红书分享页在 H5 加载过程中会触发 `xhsdiscover://video_feed/...` deep link；Chromium/WebView 无法加载该 scheme 时会生成 `ERR_UNKNOWN_URL_SCHEME` 错误页，而现有解析流程只根据正文长度和 `contentHtml/textContent` 判断成功，因此错误页可能被保存为正常剪藏内容。

本 change 处于 `evolve_modularity` phase。触及的主要区域是 `features/share`，不应扩大现有 `application/startup -> features/share` 依赖；模块化改进点是把 Xiaohongshu-specific deep link 结构隔离到 parser/helper seam，避免把平台字段解析散落到 WebView engine、UI screen 或 startup flow。

Dependency direction before:

```text
application/startup ──▶ features/share flow
features/share/engine ──▶ platform page parsers
features/share/ui ──▶ controller/formatter models
```

Dependency direction after:

```text
application/startup ──▶ features/share flow       (unchanged)
features/share/engine ──▶ platform parser seam    (generic delegation)
features/share/parsers ──▶ Xiaohongshu deep link helper
features/share/ui ──▶ existing video result model (unchanged)
```

## Goals / Non-Goals

**Goals:**

- Stop saving WebView unknown-scheme error pages as successful article clips.
- Detect Xiaohongshu `xhsdiscover://video_feed/...` deep links observed during share-page loading.
- Parse `h5VideoPreloadInfo` to extract title, first-frame cover, and direct MP4 video candidates.
- Resolve a stable web source URL from `open_url` or the note id for memo links and clip metadata.
- Reuse existing `ShareCaptureResult`, video candidate UI, downloader, and quick-clip flow.
- Add focused tests that cover parser behavior and the unknown-scheme safety net.

**Non-Goals:**

- Do not add scraping that bypasses Xiaohongshu authentication, DRM, private APIs, or app-only permissions.
- Do not introduce new external dependencies, data migrations, API route changes, or sync protocol changes.
- Do not redesign the full third-party share architecture or the existing quick-clip bottom sheet.
- Do not add commercial/private extension logic to public shell files.

## Decisions

### 1. Add a narrow Xiaohongshu deep link parser/helper

Create a dedicated parser/helper such as `xiaohongshu_deeplink_parser.dart` under `memos_flutter_app/lib/features/share/parsers/`. It should accept a `Uri` for `xhsdiscover://...`, decode `h5VideoPreloadInfo`, normalize fields, and return a small typed result or `ShareCaptureResult`-ready data.

Rationale:

- The deep link is not a DOM page snapshot, so overloading `XiaohongshuSharePageParser.parse(snapshot)` would mix two input models.
- The WebView engine should remain responsible for navigation/capture orchestration, not for Xiaohongshu JSON field walking.
- The helper is easy to unit test with the failing URL and future Xiaohongshu variants.

Alternative considered: put all parsing inside `ShareCaptureInAppWebViewEngine`. Rejected because it would make the generic engine own platform-specific JSON structure and weaken modularity checklist item 4.

### 2. Intercept non-HTTP(S) main-frame navigation before it becomes an error page

Enable and use `shouldOverrideUrlLoading` in the headless WebView capture settings. When main-frame navigation targets a non-HTTP(S) URL:

- cancel the navigation so Chromium does not replace the page with an error document;
- if the URL is a supported Xiaohongshu deep link, capture the parsed deep link result;
- otherwise record the attempted URL and allow the capture flow to fail or fall back without using the generated browser error page.

Rationale:

- This handles the root cause before the DOM bridge sees the error page.
- It also creates a generic guardrail for other app schemes without adding platform-specific behavior to UI.

Alternative considered: only filter text containing `ERR_UNKNOWN_URL_SCHEME` after DOM extraction. Rejected as insufficient because it is locale/browser-message dependent and still lets the capture pipeline treat the browser error page as content until late in the flow.

### 3. Keep an error-page safety net after DOM capture

Add a conservative post-capture check that fails capture when the DOM/page title/text clearly represents a WebView browser error page, especially `ERR_UNKNOWN_URL_SCHEME`, rather than user content.

Rationale:

- WebView callbacks can vary by platform and plugin version.
- A safety net prevents regression if navigation interception misses a path.

Trade-off: overly broad error-page detection could reject a legitimate article mentioning the error text. Mitigation is to require strong browser-error signals such as title/body patterns from Chromium error pages and/or a recorded non-HTTP(S) attempted main-frame navigation.

### 4. Represent parsed Xiaohongshu deep links as video capture results

When parsing succeeds, construct a video-style capture result:

- `pageKind: SharePageKind.video`;
- `siteParserTag: 'xiaohongshu'`;
- `articleTitle` from `h5VideoPreloadInfo.title`;
- `leadImageUrl` from `video_info_v2.image.first_frame`;
- direct `ShareVideoCandidate`s from stream fields such as `h264[].master_url`, `h265[].master_url`, and likely snake/camel variants;
- `finalUrl` as a web URL rebuilt from `open_url` when possible, otherwise from the note id.

Rationale:

- Existing `_VideoSuccessBody`, `ShareClipController.attachVideo`, and video downloader already understand `SharePageKind.video` plus direct candidates.
- Using a web `finalUrl` keeps saved links openable outside Xiaohongshu’s private scheme.

Candidate priority should prefer broadly compatible H.264 over H.265 when both are available.

### 5. Test at parser, controller/formatter, and engine-boundary levels

Parser tests should use a representative `xhsdiscover://video_feed/...` fixture and assert title, source URL, cover, candidate count, codec priority, and direct-download flags. Additional tests should verify that unknown-scheme browser error pages are not considered successful article capture.

Rationale:

- Most behavior is pure parsing and result classification, so tests can run without a real WebView.
- Engine-boundary tests can use extracted helper methods or fake capture data if the actual headless WebView is unsuitable for unit tests.

## Risks / Trade-offs

- [Risk] Xiaohongshu may change deep link field names or nesting → Mitigation: support common snake_case/camelCase variants and keep parsing isolated in one helper.
- [Risk] Signed `sns-video-*.xhscdn.com` URLs may expire before download → Mitigation: preserve original source URL and use existing link-only/video fallback behavior if download fails.
- [Risk] H.265 videos may not decode on all devices → Mitigation: prioritize H.264 candidates when present while still listing H.265 as secondary direct candidates.
- [Risk] Cancelling all non-HTTP(S) navigation could affect other share pages that use app links → Mitigation: cancel only main-frame non-HTTP(S) navigation during capture; supported schemes get parser handling, unsupported schemes fall back rather than becoming content.
- [Risk] Error-page text varies by locale or WebView version → Mitigation: use interception as the primary fix and keep post-capture detection conservative.

## Migration Plan

1. Add Xiaohongshu deep link parser/helper and unit tests.
2. Add generic non-HTTP(S) main-frame navigation interception and wire successful Xiaohongshu deep link parsing into capture result creation.
3. Add post-capture browser error-page safety net.
4. Verify focused share tests, then run broader Flutter checks before PR.

No data migration is required. Rollback can remove the new parser wiring and leave existing link-only fallback behavior intact, but the unknown-scheme safety net should be kept if it proves platform-neutral.

## Open Questions

- Should unsupported non-Xiaohongshu app links always become `ShareCaptureFailure.webViewError`, or should they use a more specific failure enum in a future cleanup?
- Should H.265 candidates be shown when H.264 is present, or hidden behind lower priority to reduce user confusion?
- Should the source URL prefer `https://www.xiaohongshu.com` plus `open_url`, or a normalized `/explore/<noteId>` URL without volatile tracking query parameters?
