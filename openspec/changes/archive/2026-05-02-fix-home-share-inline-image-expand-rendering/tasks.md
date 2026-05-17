## 1. Home Card Allowlist Propagation

- [x] 1.1 Trace `MemoListCard` expanded article rendering and confirm the change stays within `features/memos` without new lower-layer reverse dependencies.
- [x] 1.2 Build or reuse `MemoInlineImageSourcePolicy` for the current memo when `renderExpandedArticleBody` is enabled.
- [x] 1.3 Pass `allowedLocalImageUrls` into the home/list card `MemoMarkdown` expanded article body path.
- [x] 1.4 Keep collapsed card previews with `renderImages: false` and no local file allowlist-driven image rendering.
- [x] 1.5 Include the local inline image policy fingerprint, or equivalent attachment source metadata, in the expanded card Markdown cache key.

## 2. Preview And Grid Behavior

- [x] 2.1 Verify allowlisted local inline images opened from an expanded card use the shared `ImagePreviewLauncher` with the current private local file source.
- [x] 2.2 Preserve expanded clipped-article duplicate suppression by keeping the media grid hidden when inline article images render.
- [x] 2.3 Preserve collapsed/non-expanded media grid fallback behavior for image attachments.
- [x] 2.4 Preserve remote inline image `baseUrl`, `authHeader`, `rebaseAbsoluteFileUrlForV024`, and `attachAuthForSameOriginAbsolute` propagation.

## 3. Regression Coverage

- [x] 3.1 Add or extend `memos_list_memo_card_container_test.dart` to cover an expanded local-mode clipped card rendering a memo-owned `file:///...` inline image.
- [x] 3.2 Add coverage proving an expanded card blocks an unowned `file:` inline image.
- [x] 3.3 Add coverage proving collapsed card previews do not render inline images or start image preview requests.
- [x] 3.4 Add cache freshness coverage proving the expanded card Markdown cache key changes when local inline image policy or attachment source metadata changes.
- [x] 3.5 Add or update focused tests so card wrapper behavior cannot drift from detail/reader `MemoInlineImageSourcePolicy` behavior.

## 4. Verification

- [x] 4.1 Run focused Flutter tests for the touched memo card and inline image source coverage.
- [x] 4.2 Run `flutter test test/features/memos/memo_render_pipeline_contract_test.dart` if sanitizer/cache contract coverage is changed.
- [x] 4.3 Run `flutter test test/features/memos` from `memos_flutter_app` if focused tests pass and runtime is acceptable. Attempted; the broad feature run exceeded 10 minutes without output, so focused suites were used for this pass.
- [x] 4.4 Run `flutter analyze` from `memos_flutter_app`. Full analyze was run and reports existing unrelated workspace errors; focused analyze on touched files passes.
- [x] 4.5 Review touched imports to confirm no new `state -> features`, `application -> features`, or `core -> features` dependency is introduced.
