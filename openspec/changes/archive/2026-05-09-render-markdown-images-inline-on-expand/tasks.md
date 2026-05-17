## 1. Rendering Policy

- [x] 1.1 Trace current list card and detail render paths and confirm the change stays within `features/memos`.
- [x] 1.2 Add or extend a feature-level inline image rendering policy that distinguishes collapsed/no-image, ordinary Markdown-only, and clipped Markdown+HTML image modes.
- [x] 1.3 Ensure ordinary Markdown-only mode preserves `![](...)` image syntax but removes raw HTML `<img>` tags before rendering, without changing fenced code blocks.
- [x] 1.4 Reuse `MemoInlineImageSourcePolicy` so local `file:` image rendering remains scoped to current memo-owned image attachments.

## 2. List Card Behavior

- [x] 2.1 Keep collapsed list card body rendering image-free while preserving the existing media grid preview.
- [x] 2.2 Render Markdown image syntax inline after a normal memo card expands.
- [x] 2.3 Keep clipped/third-party share expanded card behavior compatible with existing HTML image rendering.
- [x] 2.4 Exclude inline-rendered images from the expanded card trailing media grid while keeping unreferenced attachments and videos.
- [x] 2.5 Include syntax mode and local inline policy fingerprint in expanded card Markdown cache keys.

## 3. Detail Behavior

- [x] 3.1 Keep collapsed detail preview body image-free.
- [x] 3.2 Render Markdown image syntax inline after detail content is expanded or when detail content starts expanded.
- [x] 3.3 Do not render ordinary raw HTML `<img>` tags inline in detail content.
- [x] 3.4 Exclude inline-rendered images from the detail trailing media grid while keeping unreferenced attachments and videos.
- [x] 3.5 Preserve existing remote image request context propagation: `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute`.

## 4. Regression Coverage

- [x] 4.1 Add render pipeline contract tests proving Markdown image syntax is preserved in Markdown-only mode.
- [x] 4.2 Add render pipeline contract tests proving raw HTML `<img>` is not rendered in ordinary Markdown-only mode and fenced-code examples remain code.
- [x] 4.3 Add list card widget coverage for collapsed grid preview, expanded inline Markdown image rendering, and duplicate grid suppression.
- [x] 4.4 Add detail coverage for expanded inline Markdown image rendering, collapsed image-free behavior, and duplicate grid suppression.
- [x] 4.5 Add local `file:` allowlist coverage for memo-owned Markdown image sources and unowned local file sources.
- [x] 4.6 Add cache freshness coverage for syntax mode and local inline policy fingerprint changes.

## 5. Verification

- [x] 5.1 Run focused Flutter tests for render pipeline, memo image grid/media behavior, memo detail, and memo list card coverage.
- [x] 5.2 Run `flutter test test/features/memos` from `memos_flutter_app` if focused tests pass and runtime is acceptable.
- [x] 5.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.4 Review touched imports to confirm no new `state -> features`, `application -> features`, or `core -> features` dependency is introduced.
