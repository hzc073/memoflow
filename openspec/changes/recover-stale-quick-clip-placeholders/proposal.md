## Why

GitHub issue `#195` reports that Android users can clip a WeChat Official Account article, move the app to background or exit before clipping finishes, and then see the memo remain stuck at `剪藏中...` after reopening the app.

The current quick clip flow intentionally saves a local placeholder memo before content extraction completes, then updates that memo from an in-memory background future. This improves offline/local-save behavior, but the extraction job is volatile: if the app process is killed, the durable placeholder survives while the job and its timeout/fallback do not.

## What Changes

- Introduce a recoverable quick clip job record for full quick clips that create a placeholder memo.
- Persist enough job input to either resume extraction or safely replace stale placeholders with link-only fallback content after restart/resume.
- On app startup or resume, scan for pending/stale quick clip jobs and process them conservatively:
  - retry extraction once when the job is still eligible
  - fallback to saved-link content when the job is expired, invalid, missing required data, or retry fails
- Keep `ShareQuickClipSubmission.titleAndLinkOnly` as an immediate local-save path that does not create placeholder recovery work.
- Make stale quick clip placeholders terminal: users should never see `剪藏中...` forever after app backgrounding, process death, or app restart.
- Keep server API routes and compatibility logic unchanged.

## Capabilities

### New Capabilities

- `quick-clip-recovery`: Defines durable recovery behavior for full quick clip placeholders and stale quick clip jobs.

### Modified Capabilities

- None.

## Impact

- Affected Flutter app code:
  - `memos_flutter_app/lib/features/share/share_quick_clip_service.dart`
  - `memos_flutter_app/lib/application/startup/startup_coordinator*.dart` or a startup-adjacent recovery trigger
  - likely new state/data persistence seam under `memos_flutter_app/lib/state/memos/` or `memos_flutter_app/lib/data/db/`
- Affected persistence: local SQLite metadata for quick clip recovery jobs or an equivalent durable marker. No Memos server API change is intended.
- Affected tests:
  - focused quick clip service tests for placeholder/job creation, retry, fallback, and idempotency
  - startup/resume recovery tests where practical
  - architecture guardrail coverage if new seams affect dependency direction
- Architecture phase: `evolve_modularity`. This change touches shared share/memo write behavior and must leave the area better structured by moving recovery policy into a durable state/data seam instead of embedding more lifecycle logic in UI widgets.
