## Why

当前小红书分享剪藏已经能识别部分视频候选，但启动时的 quick clip 路径只保存 memo 正文和链接，没有自动把小红书图文图片或视频下载并保存为附件。用户分享小红书内容时需要按内容类型得到完整剪藏结果，同时避免继续把视频附件大小限制写死为客户端 30MB。

## What Changes

- Add Xiaohongshu media auto-save behavior for share quick clip: recognized Xiaohongshu content SHALL distinguish image/article notes from video notes and save the corresponding media as memo attachments.
- Reuse generic `ShareCaptureResult`, `ShareVideoCandidate`, and parser outputs so Xiaohongshu-specific parsing remains under `features/share/parsers`.
- Route Xiaohongshu video notes through the existing video download/compression/staging pipeline instead of only updating memo text.
- Route Xiaohongshu image/article notes through inline image discovery/download when full media capture is enabled, with a parser-level fallback when page HTML does not expose usable `<img>` sources.
- Preserve explicit lightweight modes: `titleAndLinkOnly` saves only title/link, and `textOnly` saves text without media attachments.
- Add a dynamic attachment size policy:
  - local library mode MUST NOT enforce the Memos backend 30MB default as a client-side hard limit;
  - remote Memos mode SHOULD use backend `uploadSizeLimitMb` when readable;
  - when the limit cannot be read or permission is denied, the client SHOULD attempt upload and rely on server-side failure handling, including HTTP 413 or equivalent "file size exceeds the limit" responses.
- No breaking changes to existing memo storage, sync format, public/private extension seams, or non-Xiaohongshu share flows.

## Capabilities

### New Capabilities

- `xiaohongshu-share-media-attachments`: Covers automatic Xiaohongshu image/video media classification, download, staging, and attachment save behavior during share quick clip.
- `attachment-upload-size-policy`: Covers backend-aware attachment size limit resolution, local-library behavior, and fallback/error behavior when limits cannot be known in advance.

### Modified Capabilities

- None.

## Impact

- Affected runtime code is expected in `memos_flutter_app/lib/features/share/**`, `memos_flutter_app/lib/application/startup/**`, and attachment staging/mutation seams used by quick clip.
- Dynamic backend limit lookup will affect API-related files under `memos_flutter_app/lib/data/api/**` and compatibility tests under `memos_flutter_app/test/data/api/**`; this requires explicit user approval before implementation edits.
- Existing video download code in `ShareVideoDownloadService`, `ShareVideoCompressionService`, `ShareClipController.attachVideo`, and `NoteInputSheet._processDeferredShareVideo` informs the implementation, but shared attachment-save logic should move behind a stable service seam instead of being copied from UI widgets.
- The active architecture phase is `evolve_modularity`. This change touches checklist item 2 (`application -> features` existing startup share coupling), item 4 (shared domain logic hidden in UI/widget files), item 6 (feature collaboration seams), and item 7 (write-path ownership).
- Scoped modularity improvement: introduce or reuse an owned share-media attachment service/mutation seam so startup quick clip can request media attachment work without embedding platform-specific Xiaohongshu logic or duplicating `NoteInputSheet` UI logic.
- The change must not introduce new `state -> features`, new `application -> features`, or new `core -> state|application|features` dependencies beyond existing approved seams; if a touched hotspot requires collaboration, prefer a boundary service/provider seam and add or tighten a focused guardrail.
