## 1. Scope And Approvals

- [x] 1.1 Re-read `proposal.md`, `design.md`, and both specs before implementation and keep work scoped to `memos_flutter_app` plus this change folder.
- [x] 1.2 Obtain explicit user approval before editing API-related files under `memos_flutter_app/lib/data/api/**` or `memos_flutter_app/test/data/api/**`.
- [x] 1.3 Map the current quick clip, inline image, deferred video, attachment staging, and outbox write paths with exact file/function owners before making code changes.
- [x] 1.4 Identify the smallest touched-area modularity improvement needed for `evolve_modularity`, including where shared deferred video attachment logic will move out of `NoteInputSheet`.

## 2. Backend-Aware Attachment Size Limit

- [x] 2.1 Add a plain attachment upload size limit model that represents known byte limits and unknown reasons such as local library, permission denied, unsupported endpoint, or request failure.
- [x] 2.2 Add best-effort Memos `0.21` limit lookup from `GET api/v1/status.maxUploadSizeMiB`.
- [x] 2.3 Add best-effort Memos `0.22` through `0.24` limit lookup from `GET api/v1/workspace/settings/STORAGE` and parse `storageSetting.uploadSizeLimitMb`.
- [x] 2.4 Add best-effort Memos `0.25+` limit lookup from `GET api/v1/instance/settings/STORAGE` and parse `storageSetting.uploadSizeLimitMb`.
- [x] 2.5 Implement an attachment size limit resolver that returns unknown for local library mode and never substitutes a hardcoded 30 MiB limit when backend lookup fails.
- [x] 2.6 Add focused API compatibility/unit tests for successful lookup, permission-denied fallback, missing endpoint fallback, malformed response fallback, and local-library unknown behavior.

## 3. Shared Third-Party Share Attachment Appender

- [x] 3.1 Define a plain request/result model for appending third-party share media attachments without exposing Xiaohongshu parser or share UI types to lower layers.
- [x] 3.2 Implement or extract an owned appender seam that stages files, updates local memo attachments, writes inline image source mappings when needed, and enqueues `update_memo` plus `upload_attachment` outbox items.
- [x] 3.3 Refactor existing inline image append behavior to use the shared appender seam without changing current inline image memo content replacement behavior.
- [x] 3.4 Extract reusable deferred video attachment append behavior from `NoteInputSheet._processDeferredShareVideo()` so quick clip and note input can share staging/memo mutation logic.
- [x] 3.5 Add unit tests for appending image and video share attachments, duplicate attachment prevention, memo-missing failure, and outbox payload shape.

## 4. Xiaohongshu Quick Clip Media Integration

- [x] 4.1 Add a media classification helper for successful quick clip capture results that selects video path for Xiaohongshu video results with direct candidates and image path for image/article results.
- [x] 4.2 Implement automatic video candidate selection for quick clip, preferring compatible direct candidates such as H.264 over lower-priority alternatives when available.
- [x] 4.3 Update video download/compression flow to consume the resolved attachment size limit when known and avoid hard rejection based on the client 30 MiB constant when the limit is unknown.
- [x] 4.4 Wire full-mode Xiaohongshu video quick clip to download, optionally compress, stage, append, and enqueue the selected video attachment after memo content capture succeeds.
- [x] 4.5 Wire full-mode Xiaohongshu image/article quick clip to append prepared inline images or deferred image discoveries through the shared appender seam.
- [x] 4.6 Add parser-level image seed fallback for Xiaohongshu image/article captures whose `contentHtml` does not expose usable image nodes, with focused parser tests and fixtures.
- [x] 4.7 Preserve `titleAndLinkOnly` and `textOnly` behavior so those modes do not run image or video media download paths.
- [x] 4.8 Add diagnostics for media classification, selected video candidate, known/unknown upload limit, appended image/video counts, and media attachment failures.

## 5. Error Handling And Sync Behavior

- [x] 5.1 Ensure media download/staging failures keep captured memo content and clip metadata instead of deleting or rolling back the memo.
- [x] 5.2 Ensure server upload failures such as HTTP 413 or `file size exceeds the limit` are summarized as attachment-too-large sync failures with useful detail.
- [x] 5.3 Ensure remote unknown-limit uploads proceed until the server/proxy accepts or rejects them.
- [x] 5.4 Ensure local library mode can keep large video attachments locally without applying the Memos backend 30 MiB default as a hard pre-check.

## 6. Architecture Guardrails And Verification

- [x] 6.1 Verify the implementation does not introduce new `state -> features`, `application -> features`, or `core -> state|application|features` dependencies.
- [x] 6.2 Add or tighten a focused architecture/modularity guardrail if the extracted attachment appender seam exposes a new dependency risk.
- [x] 6.3 Run focused share tests covering quick clip image/video media behavior, mode skips, and failure preservation.
- [x] 6.4 Run focused API tests under `memos_flutter_app/test/data/api --reporter expanded` after API route/model changes.
- [x] 6.5 Run `flutter test test/architecture/modularity_dependency_guardrail_test.dart` from `memos_flutter_app`.
- [x] 6.6 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.7 Run `flutter test` from `memos_flutter_app` before implementation handoff.
