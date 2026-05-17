## Context

当前分享剪藏有两条主要路径：

- 预览路径：`ShareClipScreen` / `ShareClipController.attachVideo()` 会把 `ShareVideoCandidate` 放进 `ShareDeferredVideoAttachmentRequest`，后续由 `NoteInputSheet._processDeferredShareVideo()` 下载、必要时压缩、再作为附件排队上传。
- 启动 quick clip 路径：`startup_coordinator_share.dart` 对纯文本 URL 分享直接调用 `_openShareQuickClipFlow(payload)`，由 `ShareQuickClipService` 创建占位 memo、异步 capture、更新正文，并只通过 `ShareInlineImageDownloadService` 处理 inline images。

因此小红书视频识别能力仍在，但 quick clip 没有走视频附件保存路径。日志中的 `ShareInlineImage: discover_skipped | reason: missing_content_html | parserTag: xiaohongshu` 也说明小红书内容在 H5 capture 后缺少可用 HTML 图片源时，当前 quick clip 无法补足媒体附件。

附件大小限制当前也有两个来源不一致：

- 客户端视频下载代码硬编码 `kShareVideoAttachmentLimitBytes = 30 * 1024 * 1024`。
- Memos 后端源码中 `0.25+` / `0.27.1` 通过 `InstanceStorageSetting.UploadSizeLimitMb` 校验附件大小，默认值为 `30` MiB；`0.22` 到 `0.24` 使用 `WorkspaceStorageSetting.UploadSizeLimitMb`；`0.21` 在 `/api/v1/status.maxUploadSizeMiB` 暴露旧字段。

本 change 处于 `evolve_modularity` phase。触及的热点是现有 `application/startup -> features/share` quick clip 耦合、`features/share -> state/memos` 写路径调用，以及藏在 `NoteInputSheet` UI 文件里的 deferred video attachment 业务逻辑。

当前依赖方向：

```text
application/startup ──▶ features/share quick clip
features/share       ──▶ state/memos note input + mutation providers
features/memos UI    ──▶ ShareVideoDownloadService + compression + staging
data/api             ──▶ server route compatibility
```

目标依赖方向：

```text
application/startup ──▶ features/share quick clip        (不扩大现有入口)
features/share       ──▶ media attachment appender seam  (plain request model)
state/memos          ──▶ memo update + outbox ownership   (写路径归属清晰)
features/share       ──▶ ShareVideoDownloadService       (下载仍属 share feature)
application/data     ──▶ attachment limit resolver/API   (不依赖 share feature)
```

## Goals / Non-Goals

**Goals:**

- 小红书 quick clip 在 full media mode 下自动判断 `ShareCaptureResult.pageKind`，视频笔记保存视频附件，图文笔记保存图片附件。
- `titleAndLinkOnly` 和 `textOnly` 保持轻量模式语义，不触发图片或视频下载。
- 视频附件下载复用现有 `ShareVideoDownloadService` 和 `ShareVideoCompressionService` 能力，但把“下载后追加到 memo 并排队上传”的共享业务逻辑从 UI 文件中抽到稳定 seam。
- 图文附件优先复用 `ShareInlineImageDownloadService.prepare()` / deferred inline image 逻辑，并为小红书 HTML 缺失图片源的情况保留 parser-level image seed 扩展点。
- 附件大小限制改为 backend-aware：本地库不套 Memos 后端默认限制；远程库优先读取后端限制；读不到时不预阻断，交给上传和 413/error handling。
- API 兼容覆盖 `0.21`、`0.22` 到 `0.24`、`0.25+` 的限制字段读取路径。
- 不引入新的 `state -> features`、`application -> features`、`core -> higher-layer` 依赖；已存在热点必须保持相等或更好。

**Non-Goals:**

- 不绕过小红书登录、DRM、私有接口权限或签名 URL 限制。
- 不保证所有过期视频 URL 都能下载成功；失败时保存正文/链接和 clip metadata 即可。
- 不重写整个分享剪藏架构，不改变非小红书平台默认行为。
- 不改 Memos 后端，不改变附件上传 API payload 结构。
- 不在 public shell 中加入商业/private extension 逻辑。

## Decisions

### 1. Quick clip consumes generic capture result, not Xiaohongshu branches

`ShareQuickClipService` should make the media decision from generic fields:

- `result.isSuccess`
- `result.siteParserTag == 'xiaohongshu'` only for diagnostics or parser-specific fallback eligibility
- `result.pageKind == SharePageKind.video`
- `result.videoCandidates`
- inline image seeds / content HTML image sources

Video notes should prefer a direct, compatible candidate from `ShareVideoCandidate`s, generally H.264 before H.265 when both are available. Image/article notes should use prepared inline image seeds first, then deferred image discovery.

Rationale:

- Xiaohongshu parsing already belongs under `features/share/parsers`; quick clip should not know deep link JSON fields.
- This keeps future platform support possible without turning startup/UI code into a platform switchboard.

Alternative considered: add explicit `if xiaohongshu then parse media` code in `startup_coordinator_share.dart`. Rejected because it expands the existing `application/startup -> features/share` hotspot and duplicates parser logic outside the share feature.

### 2. Extract a plain media attachment appender seam

Introduce a reusable attachment append seam for third-party share media. The exact owner can be implemented as a state/application service, but it should accept plain request data such as:

- `memoUid`
- `filePath`
- `filename`
- `mimeType`
- `size`
- media kind (`inlineImage`, `video`, or generic attachment)
- source URL / local replacement URL when inline HTML replacement is needed
- flags such as `fromThirdPartyShare`, `skipCompression`, and `shareInlineImage`

The seam should own:

- staging into the queued attachment directory;
- updating local memo attachments;
- replacing inline image URLs when applicable;
- writing inline image source mapping when applicable;
- enqueueing `update_memo` and `upload_attachment` outbox items according to existing sync policy.

Rationale:

- `NoteInputSheet._processDeferredShareVideo()` currently mixes UI progress, user confirmation, video compression, staging, and memo mutation.
- `NoteInputController.appendDeferredThirdPartyShareInlineImage()` already contains useful append behavior but is image-specific.
- A plain appender seam lets quick clip and note input reuse attachment save behavior without copying UI code.

Alternative considered: copy the video append logic from `NoteInputSheet` into `ShareQuickClipService`. Rejected because it would worsen checklist item 4 by hiding shared domain logic in another feature service and increase maintenance risk.

### 3. Split media preparation from memo attachment mutation

Keep media preparation in `features/share`:

- images: `ShareInlineImageDownloadService`
- videos: `ShareVideoDownloadService` plus `ShareVideoCompressionService`

Keep memo mutation/outbox ownership in `state/memos` or an existing mutation service seam.

Rationale:

- Share feature owns source-site capture and downloading concerns.
- State/memos already owns local memo updates and outbox write policy.
- The boundary object should contain plain data only, so lower layers do not import share-specific parser or UI types.

### 4. Dynamic attachment size limit is best-effort and non-blocking when unknown

Add a best-effort resolver for attachment upload size:

```text
local library
  └─ limit = unknown/unbounded for client pre-check

remote Memos v0.21
  └─ GET api/v1/status -> maxUploadSizeMiB

remote Memos v0.22-v0.24
  └─ GET api/v1/workspace/settings/STORAGE -> storageSetting.uploadSizeLimitMb

remote Memos v0.25+
  └─ GET api/v1/instance/settings/STORAGE -> storageSetting.uploadSizeLimitMb
     401/403/404/405/format failure => unknown, no pre-block
```

The resolver should return an explicit model rather than a bare integer, for example:

```text
AttachmentUploadSizeLimit
├─ known bytes
├─ unknown because local library
├─ unknown because permission denied
└─ unknown because endpoint unavailable/error
```

Only positive values should become a client pre-check limit. Unknown MUST NOT become 30MB by client default.

Rationale:

- `0.27.1` restricts `STORAGE` settings to admins because storage config may contain credentials.
- Proxy limits such as Nginx or Cloudflare cannot generally be discovered from Memos API.
- The server remains the source of truth; client-side checks only improve UX when the value is available.

Alternative considered: keep `30MB` as a universal fallback. Rejected because local library has no backend upload limit and future backend config may intentionally exceed 30MB.

### 5. Video compression threshold follows the resolved limit when known

When a known backend limit exists, video download/compression should use that limit and choose a target below it, preserving a margin for upload overhead and metadata. When the limit is unknown:

- local library should not force compression solely because the file is over 30MB;
- remote workspace may still offer compression as an optional UX optimization, but must not block attachment save only because the client lacks a known limit.

Rationale:

- Current `kShareVideoCompressionTargetBytes = 29 * 1024 * 1024` is tied to the hardcoded 30MB limit.
- A dynamic policy should calculate target from the resolved limit, with a conservative fallback only for optional compression planning, not for hard rejection.

### 6. Preserve mode flags and sync semantics

`ShareQuickClipSubmission.titleAndLinkOnly` and `ShareQuickClipSubmission.textOnly` remain authoritative:

- `titleAndLinkOnly == true`: create link/title memo, no capture media, no attachment downloads.
- `textOnly == true`: capture/update text content, no image/video attachment downloads.
- full mode: capture text and attach available Xiaohongshu media.

After media append, quick clip should request sync once with context including appended image/video counts. Failed media download should log diagnostics and still leave the captured memo content and metadata intact.

## Risks / Trade-offs

- [Risk] Xiaohongshu video candidates expire before download -> Mitigation: keep source URL and memo content saved; log download failure; do not roll back the memo.
- [Risk] Non-admin users cannot read `instance/settings/STORAGE` -> Mitigation: treat as unknown and upload normally; rely on server rejection.
- [Risk] Refactoring attachment append behavior can touch coupled `state/memos` and `features/share` code -> Mitigation: use a plain request model seam and add focused tests/guardrail checks.
- [Risk] Large local videos may consume storage if local library no longer applies 30MB -> Mitigation: keep visible progress/logging and allow upload/server failure handling for remote sync; do not silently discard.
- [Risk] Parser image extraction for Xiaohongshu image notes may need additional fixtures -> Mitigation: implement fallback behind parser-level tests and keep HTML image discovery as the default path.
- [Risk] API route compatibility differs across Memos versions -> Mitigation: cover `0.21`, `0.22-0.24`, and `0.25+` with focused API compatibility tests and best-effort fallback behavior.

## Migration Plan

1. Add spec tests or unit tests around size-limit resolution and share-media classification before changing quick clip behavior.
2. Add API/data models for best-effort attachment limit lookup after explicit approval for API-related edits.
3. Extract or introduce the third-party share media attachment appender seam and move reusable append logic out of UI-only code paths.
4. Wire quick clip full mode to use image/video media appending based on `ShareCaptureResult`.
5. Replace hardcoded video limit decisions with resolved `AttachmentUploadSizeLimit` where available.
6. Run focused share tests, API compatibility tests, architecture guardrails, `flutter analyze`, and then broader `flutter test`.

No database migration is expected. Rollback can disable quick clip media auto-append while keeping the dynamic limit resolver and appender seam if they are already used safely by other flows.

## Open Questions

- Should remote unknown-limit video downloads offer optional compression, or skip compression until upload failure gives a concrete server error?
- Should quick clip attach only the best video candidate automatically, or keep a fallback candidate list for retry when the first direct URL fails?
- For Xiaohongshu image notes without HTML image sources, what fixture coverage is sufficient before enabling parser-level image extraction by default?
