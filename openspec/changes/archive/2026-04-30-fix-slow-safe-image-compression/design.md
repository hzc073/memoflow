## Context

The current image attachment path mixes user-visible attachment admission with slower staging, image probing, compression, hashing, and upload preparation. Several of those steps are repeated:

- Gallery/editor code waits for all selected attachments to be staged before adding them to the composer state.
- `QueuedAttachmentStager` performs image probe work in required stage logging, including pre-copy and post-copy probes.
- Creating a memo can stage upload payloads again even when the selected attachment is already in the managed attachment directory.
- `DefaultAttachmentPreprocessor` probes an image before `CompressionPipeline`, and the pipeline probes the same image again.
- The Caesium FFI engine exposes an async Dart method but calls synchronous native compression on the current isolate.

The UX result is that users do not see selected images immediately, can submit while attachment staging is still in flight, and then wait again during upload-time compression. The correctness constraint is equally important: earlier long-image / screenshot stretch regressions must not return. Any speed improvement must preserve aspect ratio, EXIF display orientation, and readable long-image behavior.

Architecture phase is `evolve_modularity`. This change touches write paths and attachment orchestration, so the implementation must keep ownership in `state`/`application` seams and avoid adding `application -> features` or `state -> features` dependencies.

## Goals / Non-Goals

**Goals:**

- Show selected image attachments in the composer immediately after picker/file metadata is available.
- Track attachment processing state explicitly so submit cannot create a memo that silently omits selected attachments.
- Remove expensive synchronous image probing from staging logs and avoid duplicate staging for managed paths.
- Move expensive compression work behind a bounded background execution seam.
- Reuse source probe metadata across preprocessing, planning, compression, and logging.
- Preserve aspect ratio for regular photos, screenshots, long images, and EXIF-rotated images.
- Add tests that would fail if long images are resized into unreadable stretched/narrow outputs.
- Improve modularity by centralizing reusable attachment processing state and policy outside feature screen files.

**Non-Goals:**

- Changing server API compatibility behavior or files under `memos_flutter_app/lib/data/api`.
- Changing memo content format, attachment JSON schema sent to existing servers, or WebDAV archive layout beyond metadata updates already supported by the app.
- Introducing commercial/private feature hooks.
- Replacing Caesium itself or adding a new image compression dependency unless the existing engine cannot be safely moved off the UI isolate.
- Solving unrelated image preview rendering bugs outside the attachment processing path.

## Decisions

### 1. Introduce explicit attachment processing state

Selected local attachments will enter composer state before staging/compression completes. Each pending attachment should carry a status such as:

- `admitted`: picker/file metadata exists and local preview can be shown.
- `staging`: source is being copied or normalized into managed storage.
- `ready`: staged payload is safe to submit/sync.
- `failed`: staging or required processing failed and user action is required.

The exact enum names can follow existing model style, but the state must live in reusable state/application models rather than inside individual screens.

Alternative considered: keep waiting for staging before adding attachments. Rejected because it preserves the slow visual feedback loop reported in the issue.

### 2. Submit must gate on readiness

Memo creation/edit submit paths must not snapshot an attachment list while selected attachments are still `admitted` or `staging`. The UI may either disable submit with a visible "images processing" state or let submit await the ready futures with clear feedback. The important invariant is that selected attachments cannot be silently dropped.

Alternative considered: allow submit and enqueue attachments later. Rejected for this change because existing create memo outbox semantics expect attachment payloads to be known when the create payload is queued.

### 3. Keep staging lightweight and idempotent

`QueuedAttachmentStager` should only guarantee a stable local file path and normalized metadata. Required staging should not decode images for logging. Rich image diagnostics may run asynchronously, behind debug/diagnostic mode, or after the user-visible state is updated.

For paths already under `queued_attachment_uploads`, staging should return the existing managed file without running duplicate copy or duplicate expensive diagnostics.

Alternative considered: keep current diagnostic logs for every stage. Rejected because the logs decode full images on the user-visible path and amplify latency for multi-image selection.

### 4. Add a bounded background compression executor

Compression should run through an `application/attachments` executor abstraction that can:

- run synchronous native FFI work outside the UI isolate where supported,
- bound concurrency to a small number such as 1 or 2 jobs,
- coalesce duplicate in-flight jobs by source signature/settings/engine key,
- expose deterministic behavior in tests.

The executor should be injectable into the pipeline/preprocessor for tests. UI and feature screens must not import engine implementations directly.

Alternative considered: wrap multi-image work in unbounded `Future.wait`. Rejected because concurrent decode/compress of multiple phone images can increase memory pressure and jank.

### 5. Reuse source probe metadata

`DefaultAttachmentPreprocessor` should compute or receive a `CompressionSourceProbe` once and pass it to the compression pipeline. The pipeline should support processing with a provided probe to avoid re-reading and re-decoding the same file. Logging should consume the same probe data.

Alternative considered: keep pipeline self-contained and accept duplicate probes. Rejected because image decode is one of the expensive operations identified in the slow path.

### 6. Add safe resize policy before compression

Resize planning must distinguish:

- regular photos where long-edge resize is acceptable,
- ordinary screenshots where aspect ratio must be preserved and readability must remain acceptable,
- long images / long screenshots where default resize should be disabled or very conservative,
- EXIF-rotated images where display dimensions and encoded pixel axes may differ.

Safe policy should calculate display-space intent and encoded-space engine parameters separately when required. After compression, output dimensions should be probed or read from the engine result and compared with the expected aspect ratio. If the output aspect ratio deviates beyond a small tolerance, the pipeline should fallback to the original or a known-safe output and log a specific fallback reason.

Alternative considered: simply re-enable default `longEdge: 1920` resize for all images. Rejected because very tall images can become too narrow/readability-breaking, and EXIF axis mistakes can reintroduce stretch regressions.

### 7. Preserve dependency direction

Before:

```
features/memos screens
  ├─ local staging loops
  ├─ local submit assumptions
  └─ repeated attachment orchestration

state/memos + application/attachments
  └─ upload-time preprocessing
```

After:

```
features/memos screens
  └─ render composer attachment state and dispatch user actions

state/memos composer/controller seam
  └─ owns pending attachment lifecycle and submit readiness

application/attachments
  ├─ staging
  ├─ source probing
  ├─ safe resize planning
  ├─ compression executor
  └─ preprocessing result metadata
```

No new `application -> features` dependency should be introduced. Reusable domain logic must not be hidden inside screen/widget files.

## Risks / Trade-offs

- [Risk] Moving attachment admission before staging could expose file paths that later fail to copy. → Mitigation: show per-attachment failed status and block submit until failed attachments are removed or retried.
- [Risk] Isolate-based FFI execution may be platform-sensitive. → Mitigation: hide it behind an executor seam and keep fallback behavior for unsupported platforms.
- [Risk] Bounded compression can make total background processing longer than unbounded parallelism. → Mitigation: optimize perceived latency first, then tune concurrency with memory-safe defaults.
- [Risk] Safe long-image policy may produce less size reduction for long screenshots. → Mitigation: prefer quality compression without resize and preserve readability over aggressive shrinking.
- [Risk] Additional attachment status state may require changes in multiple compose surfaces. → Mitigation: centralize state transitions in shared composer/controller seams and keep UI changes mechanical.
- [Risk] Removing synchronous diagnostics could reduce immediate troubleshooting detail. → Mitigation: preserve structured logs using reused probes or asynchronous diagnostic logging outside the critical path.

## Migration Plan

1. Add attachment processing state and readiness gating without changing persisted memo/server attachment formats.
2. Make staging lightweight and idempotent, preserving existing managed directory layout.
3. Add compression executor and probe reuse behind injectable application-layer interfaces.
4. Add safe resize policy and output validation.
5. Update sync/upload paths to consume processed metadata without changing server API models.
6. Keep rollback simple: existing staged files and cache files remain valid; disabling the new executor should fall back to current synchronous behavior if needed during debugging.

## Open Questions

- What exact long-image threshold should be used initially: aspect ratio only, pixel height threshold, or both?
- Should submit wait for processing automatically, or should the primary UI strictly disable submit until all attachments are ready?
- Should diagnostic image probing be controlled by debug mode only, a runtime log-level setting, or asynchronous best-effort logging in all builds?
