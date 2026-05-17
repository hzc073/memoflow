## Context

Issue `#195` exposes a lifecycle gap in the quick clip path:

```text
ShareQuickClipService.start
  -> create placeholder memo: "# 剪藏中..."
  -> unawaited(_captureAndUpdate(...))
      -> success: update placeholder with captured article
      -> timeout/error: update placeholder with "saved link" fallback
      -> process death: future disappears, placeholder remains forever
```

The placeholder memo is durable. The extraction job is not. The current `40s` timeout only helps while the Dart isolate remains alive.

The safest fix is not just "make timeout shorter" or "always save link only". The product behavior should keep the useful local-first clipping flow, but make the job recoverable and terminal.

## Goals / Non-Goals

**Goals:**

- Prevent full quick clip placeholders from remaining in `剪藏中...` forever after Android backgrounding, process death, or app restart.
- Preserve local-first behavior: full quick clip may still save a placeholder immediately, then enrich it.
- Persist enough recovery data for the app to either retry extraction or write fallback link content after restart/resume.
- Make recovery idempotent so repeated startup/resume scans do not duplicate memos, duplicate attachments, or enqueue duplicate remote mutations.
- Keep title/link-only quick clip fast and simple; it should not create a recovery job.
- Keep API compatibility untouched.

**Non-Goals:**

- Do not introduce Android foreground services, background workers, notifications, or OS-level long-running execution in this change.
- Do not guarantee clipping continues while the app is killed or background-restricted by the OS.
- Do not change WeChat parser semantics unless a recovery test exposes a parser-specific failure.
- Do not add commercial/private extension hooks.

## Decisions

### Decision 1: Persist a quick clip recovery job before starting full extraction

When full quick clip creates a placeholder memo, it should also create a durable job record containing at least:

- generated `memoUid`
- source URL
- original share text/title needed to rebuild `SharePayload`
- submission mode (`textOnly`, tags, media/full mode)
- locale or enough language information to build fallback copy
- placeholder marker and lookup content, or deterministic enough fields to find the placeholder memo again
- attempt count, status, timestamps, and last error

The job record should be written before launching `_captureAndUpdate`. If the app dies immediately after placeholder creation, recovery still knows what to do.

### Decision 2: Recovery should retry once, then fallback

On startup/resume, a recovery coordinator should find pending jobs and classify them:

```text
pending job
  |
  +-- placeholder already updated or job completed -> mark completed/cleanup
  |
  +-- required data invalid/memo missing/job too old -> fallback or mark abandoned
  |
  +-- attempts remaining -> retry capture/update
  |
  +-- retry fails or times out -> replace placeholder with saved-link fallback
```

Default policy:

- First recovery pass may retry extraction once if the memo still appears to be the original placeholder.
- After retry failure, timeout, malformed job data, or expiration, replace with fallback link content.
- Fallback content should preserve tags and source link so user data is not lost.

This matches the user expectation: best effort to complete clipping, but never indefinite "processing".

### Decision 3: Recovery writes through the same memo mutation path where practical

Recovery should update the existing placeholder memo rather than create a new memo. It should reuse the existing `ShareQuickClipService` content-building and attachment appender paths where possible, but move durable job orchestration into a testable seam.

Preferred shape:

```text
application/startup
  -> state/memos quick clip recovery coordinator
       -> data/db quick clip recovery job persistence
       -> features/share capture/formatting service seam
       -> memo mutation service / attachment appender
```

The current architecture already has application/startup importing share feature flows. For this change, avoid broadening lower-layer reverse dependencies. If new plain models are needed by `state/memos`, place them in a stable location or keep recovery orchestration feature-adjacent while persistence stays data-owned.

### Decision 4: Placeholder detection must be conservative

Recovery should only overwrite a memo when it can prove the memo is still the quick clip placeholder for that job. It can use:

- exact `memoUid`
- hidden marker `<!-- memoflow_quick_clip:<uid> -->`
- placeholder lookup content stripped of the hidden marker

If the user manually edited the memo after placeholder creation, recovery should avoid overwriting it. The job may be marked abandoned or failed with logging, but user edits must win.

### Decision 5: Startup and resume trigger recovery, but no heavy global work loop

Recovery should run after the app has a workspace/database available, similar to other startup launch handling. It should also run on resume or after share flow completion, but with in-flight dedupe so multiple lifecycle events do not start parallel recovery for the same job.

The recovery trigger should be lightweight:

- query pending jobs with a small limit
- process sequentially or with strict concurrency of one
- avoid blocking startup UI
- log outcomes for support diagnostics

## Risks / Trade-offs

- Retrying extraction on startup may cost network time. Mitigation: small pending limit, one retry, timeout, and fallback.
- Recovery can accidentally overwrite a user-edited placeholder. Mitigation: conservative placeholder matching before update.
- Adding local persistence increases schema surface. Mitigation: isolate persistence in a focused DB seam with migration tests.
- Existing share code sits under `features/share`, while durable recovery may want `state/memos` ownership. Mitigation: keep plain recovery models dependency-light and avoid adding `state -> features` imports unless explicitly reviewed and justified.
- WeChat pages may still fail extraction after retry. Mitigation: fallback preserves source link and tags instead of leaving a broken processing memo.

## Migration Plan

1. Add durable quick clip recovery job persistence and migration.
2. When full quick clip creates a placeholder, insert a pending job before starting extraction.
3. Mark jobs completed after successful capture/update, fallback, or safe abandonment.
4. Add startup/resume recovery trigger once workspace/database is available.
5. Add tests for:
   - placeholder and job created together
   - process-death simulation by creating job+placeholder without running capture, then recovery retry succeeds
   - retry failure writes saved-link fallback
   - stale/expired job writes fallback
   - user-edited placeholder is not overwritten
   - title-and-link-only creates no recovery job
6. Run focused tests, architecture guardrails, `flutter analyze`, and `flutter test`.

## Open Questions

- Exact expiration threshold: start with a conservative value such as 10 minutes for stale jobs, while allowing immediate recovery for jobs discovered after app restart.
- Whether recovery should run on every resume or only startup plus share-flow completion. Startup is mandatory; resume is useful but should be deduped.
- Whether completed jobs should be deleted immediately or retained briefly for diagnostics. Prefer cleanup after completion unless logs already capture enough context.
