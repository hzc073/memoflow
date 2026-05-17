## Context

当前远端公告实现集中在 `data/updates`, `application/updates`, `features/updates`, and Debug tools:

- `UpdateConfigService` sequentially fetches hard-coded production URLs.
- `UpdateAnnouncementConfig` parses legacy `version_info`, `announcement`, `release_notes`, `notice_enabled`, and `notice`.
- `UpdateAnnouncementRunner` decides startup update/notice display and directly calls `UpdateAnnouncementDialog` / `NoticeDialog`.
- Debug tools can preview the current remote `notice`, but cannot select preview/staging/custom config sources.
- Android Play startup fetch suppression is currently implemented before fetching the remote update config.

The change runs during architecture phase `evolve_modularity`. It touches critical checklist item 2 because `application/updates/update_announcement_runner.dart` currently imports `features/updates` dialogs. The implementation MUST leave this area better structured by moving dialog rendering behind a stable presentation boundary and tightening the architecture guardrail allowlist.

Current dependency direction:

```text
application/updates
      |
      v
features/updates dialogs
```

Target dependency direction:

```text
application/updates
      |
      v
application/updates presentation request/result models
      ^
      |
features/updates presenter implementation
```

`application/updates` will own fetch, compatibility parsing, eligibility, queue selection, and state mutation decisions. `features/updates` will own UI rendering and translate user actions back into application-level results.

## Goals / Non-Goals

**Goals:**

- Establish a phase A-E rule for announcement delivery remediation:
  - Phase A: preview-safe config source workflow.
  - Phase B: schema v3 contract, targeting, status, schedule, and id/revision dismissal.
  - Phase C: startup queue and priority rules.
  - Phase D: UI presentation boundary and architecture guardrail cleanup.
  - Phase E: validation script, release checklist, rollback guidance, and docs.
- Preserve legacy config compatibility during rollout.
- Keep Android Play builds protected from full APK update prompts while allowing ordinary notices where policy permits.
- Make preview before publish a first-class workflow.
- Avoid private/commercial hooks, entitlement state, subscription state, or paywall logic.

**Non-Goals:**

- No backend admin console.
- No push notification service.
- No per-user server-side targeting.
- No analytics/telemetry pipeline.
- No commercial feature gating.
- No broad rewrite of unrelated startup or settings flows.

## Decisions

### Decision 1: Use schema v3 as an additive contract

Introduce v3 fields without removing legacy fields immediately:

```json
{
  "schema_version": 3,
  "environment": "production",
  "generated_at": "2026-05-10T00:00:00Z",
  "notices": [],
  "updates": [],
  "release_notes": []
}
```

Legacy clients can keep reading `version_info`, `announcement`, `notice_enabled`, and `notice`. New clients prefer v3 `notices` and `updates`, then fall back to legacy fields.

Alternative considered: replace the legacy config in one step. Rejected because old clients would still read production JSON and could show stale or unintended content.

### Decision 2: Split config environment from announcement status

Config sources and item status solve different problems:

- Config source: `production`, `preview`, `customUrl`, `localJson`.
- Item status: `draft`, `preview`, `public`, `archived`.

Formal startup MUST read production config only. Debug tools MAY read preview/custom/local sources. Production config MUST NOT rely on `draft` to hide sensitive content; sensitive drafts belong outside public production JSON.

Alternative considered: keep one URL and use `notice_enabled=false` for drafts. Rejected because it is easy to publish test content into a public file and because the field is too coarse for multiple announcements.

### Decision 3: Model notices and updates as delivery candidates

The parser should normalize legacy and v3 data into internal delivery candidates:

```text
AnnouncementConfig
  -> notice candidates
  -> update candidates
  -> release note entries
```

Each candidate carries:

- stable id
- revision
- status
- publish/expire window
- platform/channel/version audience
- priority/severity
- display surface
- dismissal policy
- localized content

This keeps eligibility and queueing independent from the raw JSON shape.

### Decision 4: Prefer id/revision dismissal for v3

Legacy `notice` will continue using content hash. V3 notices use explicit policies:

- `once_per_id`
- `once_per_revision`
- `every_start`

This makes intentional repeats explicit and avoids accidental repeats when wording changes. The persistence shape should remain public-shell-safe and must not include entitlement or commercial concepts.

Alternative considered: keep hashing all notice content. Rejected because hash-based behavior couples display history to text edits and makes rollback/revision semantics hard to reason about.

### Decision 5: Use a single startup queue

Startup should evaluate eligible candidates and show at most one non-forced item per launch. Priority ordering:

```text
1. force update
2. critical blocking notice
3. optional update prompt
4. release highlight
5. ordinary notice
```

Forced updates may remain blocking. Non-forced items should not cascade into multiple dialogs on one startup.

Alternative considered: keep current sequential update-then-notice behavior. Rejected because it can stack dialogs and makes future notice types harder to control.

### Decision 6: Move UI rendering behind a presenter boundary

`application/updates` should emit a `AnnouncementPresentationRequest` and receive an `AnnouncementPresentationResult`. `features/updates` should implement the presenter that opens `UpdateAnnouncementDialog` or `NoticeDialog`.

The boundary can be injected through app composition / provider wiring. After implementation, the architecture guardrail allowlist should remove:

- `lib/application/updates/update_announcement_runner.dart -> lib/features/updates/notice_dialog.dart`
- `lib/application/updates/update_announcement_runner.dart -> lib/features/updates/update_announcement_dialog.dart`

Alternative considered: keep direct imports and only add tests. Rejected because this change touches a known `application -> features` hotspot in `evolve_modularity` and must leave it better structured.

### Decision 7: Treat Play update suppression as candidate eligibility, not blanket notice suppression

For Android `AppChannel.play`, APK-style update candidates MUST be ineligible for startup prompts. Ordinary notices MAY remain eligible if they satisfy status, schedule, platform/channel, and dismissal rules.

If implementation keeps separate update and notice config sources, Play can skip only the update source. If implementation keeps a shared config, Play must fetch/evaluate in a way that filters update candidates without blocking notice candidates.

Alternative considered: preserve the current blanket startup fetch skip for all remote announcement content. Rejected because the new capability intentionally separates update announcements from ordinary notices.

## Risks / Trade-offs

- Production JSON accidentally contains draft/sensitive content -> Mitigation: preview config files, production validation blockers, and release checklist.
- Old clients interpret new production JSON unexpectedly -> Mitigation: additive v3 rollout and safe legacy fields during migration.
- Too many targeting fields make config hard to author -> Mitigation: keep required fields minimal and add validation with clear errors.
- Queueing hides lower-priority notices for one launch -> Mitigation: once-per-startup is intentional; remaining eligible items can appear on later launches if still valid.
- Dismissal state migration is lossy for legacy hash-only notices -> Mitigation: preserve legacy hash behavior and only apply id/revision to v3 items.
- Presenter boundary adds indirection -> Mitigation: the indirection removes a known architecture violation and makes application policy testable without widget dialogs.

## Migration Plan

1. Phase A: add preview config source support for Debug tools while preserving production startup behavior.
2. Phase B: add schema v3 parser and normalize v3/legacy config into delivery candidates.
3. Phase C: add eligibility and queue policy, then route startup through the queue.
4. Phase D: extract presentation request/result boundary and remove `application/updates -> features/updates` dialog imports from the architecture allowlist.
5. Phase E: add config validation script, examples, release checklist, and rollback notes.

Rollback strategy:

- Keep legacy fields in production JSON during the rollout.
- If v3 delivery fails, production can set v3 items to `archived` or remove v3 arrays while legacy fields continue to provide safe fallback behavior.
- If preview source selection fails, formal startup remains pinned to production config.

## Open Questions

- Should production validation live under `memos_flutter_app/tool/` or a root-level config repository script if the remote config is maintained separately?
- Should v3 dismissal state be stored as a bounded list of recent ids/revisions or a compact map with pruning by `expire_at`?
- Should Debug tools support local file import on all platforms or only desktop during the first phase?
