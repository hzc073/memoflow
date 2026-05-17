## Context

`standardize-announcement-delivery` introduced schema v3 candidates, startup queue selection, and a presenter boundary that removed direct dialog imports from `application/updates`. Two routing gaps remain:

```text
Formal startup path
  UpdateAnnouncementRunner
    -> AnnouncementDeliveryPolicy.selectStartupCandidate()
       -> currently treats any eligible v3 notice as startup-showable

Debug preview path
  DebugToolsScreen._previewNoticeDialog()
    -> UpdateConfigService.fetchLatest(source)
       -> currently reads only legacy config.notice
```

The active architecture phase is `evolve_modularity`. This change touches modularity checklist item 2 because it must preserve the `application/updates` presenter boundary, and item 4 if v3 candidate-to-dialog conversion is shared between Debug preview and startup presentation.

Current dependency direction to preserve:

```text
application/updates policy
      |
      v
application/updates AnnouncementPresentationRequest/Result
      ^
      |
features/updates DialogAnnouncementPresenter
```

The fix should not move feature dialog imports back into `application/updates`.

## Goals / Non-Goals

**Goals:**

- Formal startup SHALL select only v3 notice candidates whose `display.surface` is `startupDialog`.
- V3 `releaseHighlight` notices SHALL remain available for future/manual surfaces but SHALL NOT appear as startup dialogs.
- Debug tools SHALL preview v3 notice candidates from preview/custom/local config sources, including configs with no legacy `notice`.
- Debug preview SHALL remain non-formal: it SHALL NOT write `seenNoticeRevisions`, `lastSeenNoticeHash`, or other startup dismissal state.
- Tests SHALL cover both review findings directly.

**Non-Goals:**

- No new remote config schema fields.
- No backend or local config manager changes.
- No new release-highlight UI surface.
- No change to production config URL selection.
- No subscription, entitlement, paywall, or private overlay behavior.

## Decisions

### Decision 1: Treat `display.surface` as an eligibility gate for startup

Startup selection should reject non-startup notice candidates before ranking. Ranking may still know about surfaces for future queue behavior, but a candidate whose surface is not `AnnouncementDisplaySurface.startupDialog` should never reach the startup dialog presenter.

Alternative considered: keep `releaseHighlight` in the startup queue with a lower rank. Rejected because rank only controls order; it still permits startup delivery when no higher-ranked candidate exists.

### Decision 2: Prefer a single v3 notice resolution helper for preview and presentation

The feature layer already resolves `AnnouncementNoticeCandidate` into `UpdateNotice` for `NoticeDialog`. Debug preview needs equivalent behavior. If reused, this conversion should live in a small feature-level helper or presenter-owned method, not in `application/updates` and not duplicated across multiple widget methods.

Alternative considered: duplicate conversion inside `DebugToolsScreen`. Acceptable for a narrow patch, but weaker for checklist item 4 because the same localization/content fallback rule would exist in two UI locations.

### Decision 3: Debug preview should select previewable v3 content without formal delivery side effects

Debug preview may show `preview` or `public` candidates because its purpose is pre-release validation. It should not reuse formal startup eligibility wholesale, because formal startup correctly rejects `preview` status. The preview path should instead select a reasonable candidate from loaded config and render it without writing dismissal state.

Alternative considered: call `AnnouncementDeliveryPolicy.selectStartupCandidate()` from Debug preview. Rejected because it would hide `status: "preview"` items, which are the main reason the preview source exists.

### Decision 4: Keep channel routing scoped to update prompts

This change should preserve the newer intent that Android Play builds can fetch shared announcement config while full APK update prompts remain suppressed. The surface fix should not restore the older blanket "do not fetch remote config" behavior for Play startup.

Alternative considered: avoid touching channel-routing tests. Rejected because the existing root spec still describes blanket fetch suppression, and the current v3 delivery model depends on separating ordinary notices from update prompt eligibility.

## Risks / Trade-offs

- Preview candidate selection may not match formal startup ordering exactly -> Mitigation: document/test that Debug preview is for visual validation, while formal startup eligibility remains policy-driven.
- A future release-highlight surface may need separate delivery rules -> Mitigation: keep `releaseHighlight` parsed and ranked concepts intact, but exclude it only from the startup selector.
- Shared conversion helper could create feature-level coupling if placed poorly -> Mitigation: keep it under `features/updates` or behind the existing presenter boundary; do not import it into `application/updates`.
- Channel-routing spec correction broadens the written contract from "skip fetch" to "suppress update prompt" -> Mitigation: add focused tests that Play update prompts stay suppressed while ordinary notices remain eligible.

## Migration Plan

1. Add failing coverage for release-highlight notices not being selected by startup delivery.
2. Add failing coverage for Debug preview resolving v3 `noticeCandidates` from a v3-only config.
3. Apply the routing fixes while preserving the presenter boundary.
4. Run focused tests for announcement delivery policy, Debug preview behavior, and channel routing.

Rollback is straightforward: the change affects only client-side routing and preview behavior. If needed, production config can avoid `release_highlight` notices until the client fix ships, and preview validation can continue using legacy `notice` fallback fields.

## Open Questions

- Should Debug preview choose the first v3 candidate by config order, highest priority, or a user-selected candidate when multiple notices exist?
- Should candidate-to-`UpdateNotice` conversion become a named helper now, or wait until another surface besides startup/debug preview uses it?
