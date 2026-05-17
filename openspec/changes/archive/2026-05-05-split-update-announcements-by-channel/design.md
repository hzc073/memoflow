## Context

Current startup update announcements are coordinated by `UpdateAnnouncementRunner`. The runner resolves the installed app version, reads device preferences, fetches the remote `UpdateAnnouncementConfig`, and then decides whether to show `UpdateAnnouncementDialog` or `NoticeDialog`.

The remote config is platform-scoped (`android`, `windows`, etc.) but not channel-scoped. Android Play and full APK builds both resolve to the same `version_info.android` block, while the build system already distinguishes the channels through the `play` and `full` flavors and `APP_CHANNEL`.

This change touches the existing `application/updates -> features/updates` hotspot. The dependency direction before the change is:

```text
app.dart
  -> application/updates/UpdateAnnouncementRunner
       -> features/updates dialogs
       -> data/updates config
       -> state bootstrap adapter
```

The dependency direction after the change should remain the same, with channel policy added through a stable non-UI seam:

```text
core/app_channel or application/updates policy
  -> pure channel routing decision

UpdateAnnouncementRunner
  -> asks policy before remote update-announcement fetch
```

## Goals / Non-Goals

**Goals:**

- Play-channel builds do not fetch remote startup update announcement config.
- Play-channel builds do not show full APK update prompts from startup announcement scheduling.
- Full-channel Android builds keep the existing remote update announcement behavior.
- Desktop builds keep the existing remote update announcement behavior.
- Channel routing is covered by focused tests and does not add new feature-layer dependencies.

**Non-Goals:**

- Do not redesign the remote update JSON schema in this change.
- Do not add Google Play in-app update APIs.
- Do not change package IDs, signing, or release artifact naming.
- Do not change donation entry behavior or donor acknowledgement behavior.
- Do not introduce subscription, entitlement, paywall, billing, or other commercial logic.

## Decisions

1. Gate startup fetches by app channel instead of remote `update_source`.

   `update_source` is parsed from remote config but is not currently authoritative for runtime behavior. Using `AppChannel` keeps the decision local to the installed build and prevents a bad remote JSON value from making Play builds open full APK links.

   Alternative considered: split the remote JSON into `android_play` and `android_full`. That can be useful later, but it still requires local fallback behavior when the config is missing, stale, or incorrectly scoped.

2. Keep the initial scope at startup update announcements.

   The risky path is the startup fetch that can immediately show an update CTA. Manual release notes and donor screens can continue to use the existing config unless a later requirement explicitly separates those surfaces.

   Alternative considered: block every `UpdateConfigService.fetchLatest()` call on Play builds. That is simpler globally but could unintentionally remove public release-note or donor content that is not part of the update-prompt problem.

3. Make the channel decision pure and independently testable.

   The routing decision should be expressed in a small policy function or provider seam that depends on `AppChannel`, not on widgets or feature screens. This gives the `evolve_modularity` phase a scoped improvement: the touched hotspot gets a guardrail rather than more UI coupling.

   Alternative considered: inline `isPlayAppChannel` in `UpdateAnnouncementRunner.scheduleIfNeeded`. That is minimal but easier to regress and harder to test without lifecycle/widget setup.

4. Preserve full-channel and desktop behavior.

   Existing full APK and Windows self-update prompts are expected behavior. The change should only suppress Play-channel startup update announcements.

## Risks / Trade-offs

- [Risk] Play users may no longer see release notes via startup announcements. -> Mitigation: keep manual release-note surfaces unchanged and document the startup-only scope in tests/specs.
- [Risk] A future developer may reintroduce direct fetches from another startup path. -> Mitigation: add focused tests for Play-channel startup routing and consider an architecture guardrail if a broader fetch seam is introduced.
- [Risk] Channel detection may default to Play when flavor metadata is missing. -> Mitigation: rely on existing `AppChannel` resolution tests and add routing tests for both explicit `play` and `full`.
- [Risk] The existing `application/updates -> features/updates` dependency remains. -> Mitigation: do not add new feature imports and keep the new policy in a stable non-UI seam.

## Migration Plan

1. Add the channel routing policy and tests.
2. Apply the policy before startup update announcement config fetching.
3. Verify Play-channel startup skips remote update announcement fetches.
4. Verify full-channel startup still fetches and evaluates remote update announcements.
5. Rollback by removing the policy gate if Play update announcements must be restored.

## Open Questions

- Should Play builds eventually show a Google Play Store update prompt from a separate Play-specific source?
- Should the remote config schema later add explicit channel scopes such as `android.play` and `android.full` for release notes and notices?
