## Why

Google Play builds currently read the same remote update announcement config as full APK builds. When the Android config points at a full APK release, Play users can receive an update prompt that sends them outside Google Play.

This change separates update announcement behavior by app channel so Play builds avoid full-channel update prompts while full builds keep the existing self-update announcement flow.

## What Changes

- Route startup update announcement fetching by `AppChannel`.
- Prevent Play-channel builds from fetching or showing remote update announcements intended for full APK distribution.
- Keep full-channel Android builds and desktop builds on the current remote update announcement flow.
- Preserve public donation/release-note surfaces unless their behavior is explicitly scoped by the spec.
- Add tests or guardrails that verify Play-channel startup does not request remote update announcement config.

## Capabilities

### New Capabilities

- `update-announcement-channel-routing`: Defines how update announcement fetching and update prompts are routed by app channel and platform.

### Modified Capabilities

- None.

## Impact

- Affected runtime areas: `memos_flutter_app/lib/application/updates/update_announcement_runner.dart`, `memos_flutter_app/lib/core/app_channel.dart`, and related provider/bootstrap seams.
- Affected tests: focused update announcement routing tests and, if needed, architecture guardrails around the existing `application/updates -> features/updates` hotspot.
- Active architecture phase: `evolve_modularity`.
- Modularity checklist items touched: item 2 because `application/updates` already imports update UI dialogs from `features/updates`; item 8 because this change should add or tighten tests that prevent channel-routing regressions.
- Scoped modularity improvement: keep channel policy in a stable non-UI seam and test it independently so the touched `application/updates` hotspot does not gain additional feature-layer coupling.
