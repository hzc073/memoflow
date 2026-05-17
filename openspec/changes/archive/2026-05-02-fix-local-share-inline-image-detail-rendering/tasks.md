## 1. Local Inline Image Policy Seam

- [x] 1.1 Add a feature-level helper for current memo-owned local inline image source policy, including allowed URL set and deterministic fingerprint.
- [x] 1.2 Implement canonical local file URL/path comparison so `file:///...` attachment URLs match equivalent inline content sources without accepting host-mutated `file://host/path` variants.
- [x] 1.3 Derive allowed local inline image URLs only from current memo image attachments and matching inline content image sources.
- [x] 1.4 Add focused unit coverage for allowed current memo attachment sources, blocked unowned file sources, and canonical `file:///` behavior.

## 2. Sanitizer and Render Pipeline

- [x] 2.1 Extend `sanitizeMemoHtml` with an optional local image allowlist while keeping default `file:` blocking behavior unchanged.
- [x] 2.2 Thread allowed local image URLs through `MemoRenderPipeline.build`, `buildMemoRenderArtifact`, and `MemoMarkdown`.
- [x] 2.3 Preserve existing remote image request resolution and auth header behavior for relative and same-origin Memos file URLs.
- [x] 2.4 Add render-pipeline tests proving allowed local file images are preserved and unallowlisted local file images are removed.

## 3. Detail and Reader Integration

- [x] 3.1 Build the local inline image source policy inside `buildMemoDocumentResolvedData` and include its fingerprint in detail Markdown cache keys.
- [x] 3.2 Pass the policy through `_CollapsibleText` to `MemoMarkdown` for expanded detail content.
- [x] 3.3 Apply the same policy in `MemoReaderContent` for reader surfaces that render memo content without a detail `contentOverride`.
- [x] 3.4 Ensure inline-rendered local images are not duplicated in `MemoMediaGrid`; tighten shared source comparison if existing de-duplication is insufficient.

## 4. Regression Tests

- [x] 4.1 Add detail resolved-data/widget coverage for a third-party share memo whose inline `file:///...local_attachments...` image matches an image attachment.
- [x] 4.2 Add assertions that the same local image is rendered inline and omitted from duplicate detail media grid entries.
- [x] 4.3 Add a negative test proving `file:///...` sources without current memo image attachment ownership remain blocked.
- [x] 4.4 Add a negative test proving `file://host/path` is not treated as equivalent to canonical `file:///path`.
- [x] 4.5 Keep existing tests for remote inline image auth propagation passing unchanged.

## 5. Verification and Boundary Review

- [x] 5.1 Run focused tests for `memo_html_sanitizer`, `memo_render_pipeline`, `memo_image_grid`, and `memo_detail_screen`.
- [x] 5.2 Run `flutter test test/features/memos` from `memos_flutter_app` if focused tests pass.
- [x] 5.3 Review imports to confirm no new `state -> features`, `application -> features`, or `core -> features` dependency is introduced.
- [x] 5.4 Confirm no API route, request/response model, database schema, sync payload format, or private/commercial hook is changed.
