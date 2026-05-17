## 1. Recovery Persistence

- [x] 1.1 Define a durable quick clip recovery job model with `memoUid`, source URL, share payload data, submission mode, tags, locale/language, placeholder lookup fields, status, attempt count, timestamps, and last error.
- [x] 1.2 Add local SQLite persistence for quick clip recovery jobs behind a focused data/state seam.
- [x] 1.3 Add migration and persistence tests for inserting, listing pending/stale jobs, updating attempts/status, and completing/cleaning jobs.

## 2. Quick Clip Service Integration

- [x] 2.1 Update full `ShareQuickClipService.start` flow to create the recovery job before launching background capture.
- [x] 2.2 Mark the recovery job completed after successful placeholder update and media/inline-image append work reaches a terminal state.
- [x] 2.3 Mark the recovery job completed after fallback content is saved.
- [x] 2.4 Keep `ShareQuickClipSubmission.titleAndLinkOnly` free of recovery-job creation.
- [x] 2.5 Keep full quick clip local-first behavior: `start()` still returns after placeholder save, without waiting for extraction or sync.

## 3. Recovery Coordinator

- [x] 3.1 Add a quick clip recovery coordinator/service that scans pending jobs after database/workspace availability.
- [x] 3.2 Implement in-flight dedupe so startup/resume/share-flow triggers do not process the same job concurrently.
- [x] 3.3 Retry eligible jobs once by rebuilding the capture request and updating the existing placeholder memo.
- [x] 3.4 Fallback expired, malformed, failed, or retry-exhausted jobs to saved-link content.
- [x] 3.5 Preserve tags and source link in fallback content.
- [x] 3.6 Log recovery outcomes: retry success, fallback saved, user-edited placeholder skipped, memo missing, malformed job, and unexpected failure.

## 4. Placeholder Safety

- [x] 4.1 Reuse or extract conservative placeholder matching based on `memoUid`, hidden marker, and stripped placeholder lookup content.
- [x] 4.2 Ensure recovery does not overwrite a memo that no longer matches the original placeholder content.
- [x] 4.3 Define terminal handling for user-edited placeholders: mark job abandoned/failed without changing memo content.

## 5. Startup / Resume Trigger

- [x] 5.1 Trigger recovery after app startup once preferences and a workspace/database are available.
- [x] 5.2 Trigger recovery on app resume or after share flow completion if pending jobs may exist, while keeping the trigger lightweight.
- [x] 5.3 Ensure recovery does not block startup launch UI, quick input, widget launch, or normal sync scheduling.

## 6. Modularity And Guardrails

- [x] 6.1 Keep persistence in a data/state seam and avoid new lower-layer imports from `state`, `application`, or `core` into share UI widgets.
- [x] 6.2 If recovery needs share capture/formatting from a state-owned coordinator, introduce a stable seam or plain model boundary instead of adding an unreviewed `state -> features` dependency.
- [x] 6.3 Add or update architecture tests if new dependencies affect the current modularity allowlist.

## 7. Verification

- [x] 7.1 Add quick clip service tests for placeholder+job creation, terminal completion, fallback completion, and title/link-only no-job behavior.
- [x] 7.2 Add recovery tests that simulate process death by seeding placeholder+job, then running recovery.
- [x] 7.3 Add safety tests proving user-edited placeholders are not overwritten.
- [x] 7.4 Run focused share/recovery tests.
- [x] 7.5 Run `flutter test test/architecture/modularity_dependency_guardrail_test.dart`.
- [x] 7.6 Run `flutter analyze`.
- [x] 7.7 Run `flutter test`.
- [ ] 7.8 Manually verify on Android with a WeChat Official Account article: start full clip, background/kill before extraction finishes, reopen app, and confirm the memo reaches captured content or saved-link fallback instead of staying at `剪藏中...`.
