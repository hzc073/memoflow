## 1. Attachment State and Submit Readiness

- [x] 1.1 Add shared attachment processing status to pending attachment models in `state/memos` so feature screens do not own processing lifecycle logic.
- [x] 1.2 Update memo editor, inline compose, and note input flows to admit selected attachments into composer state immediately with local preview metadata.
- [x] 1.3 Centralize attachment readiness checks in composer/controller or mutation seams instead of duplicating submit assumptions in screen files.
- [x] 1.4 Block or await submit while any selected attachment is not ready, and surface failed attachment states that require remove or retry.
- [x] 1.5 Add focused tests proving submit cannot create a memo that silently omits selected attachments still being staged.

## 2. Lightweight and Idempotent Staging

- [x] 2.1 Refactor `QueuedAttachmentStager` so required staging logs do not synchronously probe or decode image dimensions.
- [x] 2.2 Preserve rich diagnostic logging through reused probe metadata, debug-only diagnostics, or asynchronous best-effort logging outside the user-visible path.
- [x] 2.3 Make managed-path staging idempotent so already staged files return without duplicate copy or duplicate expensive diagnostics.
- [x] 2.4 Replace serial multi-attachment stage loops with a bounded staging helper where safe, preserving deterministic order in composer state.
- [x] 2.5 Add stager tests for managed-path idempotency, no required image probe on staging, and ordered multi-attachment results.

## 3. Compression Pipeline Performance

- [x] 3.1 Introduce an injectable application-layer compression executor with bounded concurrency and deterministic test behavior.
- [x] 3.2 Route Caesium FFI compression through the executor so synchronous native compression does not block the UI isolate.
- [x] 3.3 Restore in-flight compression coalescing by cache/job key so duplicate equivalent jobs share one result.
- [x] 3.4 Pass source `CompressionSourceProbe` metadata from `DefaultAttachmentPreprocessor` into `CompressionPipeline` to avoid duplicate source decode work.
- [x] 3.5 Update compression pipeline tests to verify probe reuse, in-flight coalescing, and bounded executor behavior.

## 4. Safe Resize and No-Stretch Guardrails

- [x] 4.1 Add safe resize policy for regular photos, ordinary screenshots, long images, and EXIF-rotated images.
- [x] 4.2 Ensure long images or long screenshots avoid default resize behavior that would make the readable edge substantially narrower.
- [x] 4.3 Map display-space resize intent to encoded pixel axes correctly for EXIF orientations that swap width and height.
- [x] 4.4 Validate compressed output aspect ratio and fallback safely when output dimensions exceed tolerance.
- [x] 4.5 Add tests for long screenshots, portrait screenshots, regular photos, and EXIF-rotated images to prevent stretch regressions.

## 5. Upload and Sync Integration

- [x] 5.1 Update upload preprocessing paths to consume ready processed attachment metadata without changing server API route adapters.
- [x] 5.2 Ensure compression-disabled and original-image flows still produce ready attachment results and obey the same submit gate.
- [x] 5.3 Avoid re-staging already ready attachments during memo creation payload assembly.
- [x] 5.4 Add sync/upload tests covering processed metadata, original upload bypass, and no duplicate staging during create.

## 6. Modularity and Verification

- [x] 6.1 Keep new reusable attachment orchestration in `state` or `application` seams and avoid new `application -> features` dependencies.
- [x] 6.2 Add or tighten architecture guardrail coverage if new seams touch existing coupling hotspots.
- [x] 6.3 Run focused tests for attachment processing, compression planning/pipeline, memo editor/inline compose submit gating, and sync upload.
- [x] 6.4 Run `flutter analyze` from `memos_flutter_app`.
- [ ] 6.5 Run `flutter test` from `memos_flutter_app` after focused tests pass.
