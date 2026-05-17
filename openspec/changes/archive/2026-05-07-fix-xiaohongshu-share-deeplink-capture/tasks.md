## 1. Xiaohongshu Parser

- [x] 1.1 Add a representative `xhsdiscover://video_feed/...` fixture or inline test sample that includes `h5VideoPreloadInfo`, `open_url`, title, first-frame image, and H.264/H.265 MP4 stream candidates.
- [x] 1.2 Implement a narrow Xiaohongshu deep link parser/helper under `memos_flutter_app/lib/features/share/parsers/**` that decodes valid deep links without depending on UI, startup, state, core, or API layers.
- [x] 1.3 Normalize parsed results into existing share capture concepts: title, HTTP(S) source URL, lead image URL, direct `ShareVideoCandidate`s, `SharePageKind.video`, and `siteParserTag: xiaohongshu`.
- [x] 1.4 Add parser unit tests for valid payload parsing, invalid/missing payload rejection, H.264 priority over H.265, source URL rebuilding, and candidate de-duplication.

## 2. Capture Engine Guardrails

- [x] 2.1 Update `ShareCaptureInAppWebViewEngine` to intercept main-frame non-HTTP(S) navigation during headless capture and cancel it before Chromium renders an unknown-scheme error page.
- [x] 2.2 Wire supported Xiaohongshu deep link interception into a successful video capture result while keeping unsupported app schemes on a failure/link-only fallback path.
- [x] 2.3 Add a conservative post-DOM safety net that classifies Chromium/WebView `ERR_UNKNOWN_URL_SCHEME` error documents as capture failure instead of article success.
- [x] 2.4 Add focused tests for unknown-scheme interception or extracted helper behavior so browser error text cannot be saved as a successful clip.

## 3. Flow Integration And Modularity

- [x] 3.1 Verify the existing share preview and quick-clip paths consume the Xiaohongshu video result through `ShareCaptureResult` and `ShareVideoCandidate` without new platform-specific UI branches.
- [x] 3.2 Ensure saved memo link text and clip metadata use a web-openable HTTP(S) Xiaohongshu URL rather than the private `xhsdiscover://` scheme.
- [x] 3.3 Keep dependency direction unchanged: do not add new `state -> features`, `application -> features`, or `core -> state|application|features` imports while implementing this change.
- [x] 3.4 If implementation reveals an uncovered dependency risk, add or tighten a scoped guardrail instead of spreading Xiaohongshu logic into coupled startup/UI areas.

## 4. Verification

- [x] 4.1 Run focused share tests from `memos_flutter_app`, including parser, formatter/controller, and quick-clip tests touched by this change.
- [x] 4.2 Run `flutter test test/architecture/modularity_dependency_guardrail_test.dart` from `memos_flutter_app` to verify dependency boundaries did not regress.
- [x] 4.3 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.4 Run `flutter test` from `memos_flutter_app` before PR handoff.
