## Why

Schema v3 announcement delivery already separates delivery candidates by `display.surface` and stores new notices under `notices[]`, but two consumers still route them as if they were legacy startup notices. This can show release-highlight content as a startup dialog and prevents Debug preview from validating v3-only preview configs before release.

## What Changes

- Tighten startup notice eligibility so only `AnnouncementDisplaySurface.startupDialog` notice candidates can be selected by formal startup delivery.
- Keep non-startup surfaces such as `release_highlight` out of the startup dialog path unless a future surface-specific presenter explicitly handles them.
- Update Debug announcement preview so preview/custom/local sources can render v3 `noticeCandidates` in addition to legacy `notice`.
- Preserve the existing rule that Debug preview must not persist formal startup dismissal state.
- Add focused tests for startup surface filtering and v3 preview behavior.
- Keep the application/UI presentation boundary introduced by `standardize-announcement-delivery`; no new `application/updates -> features/updates` dialog imports should be introduced.

## Capabilities

### New Capabilities

- `announcement-v3-routing`: Defines the corrective routing behavior for schema v3 startup notice surfaces and Debug preview of v3 notice candidates.

### Modified Capabilities

- `update-announcement-channel-routing`: Preserve the existing channel-routing intent while ensuring the fix does not reintroduce blanket fetch suppression or UI coupling.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/application/updates/announcement_delivery_policy.dart`
  - `memos_flutter_app/lib/features/debug/debug_tools_screen.dart`
  - `memos_flutter_app/lib/features/updates/announcement_dialog_presenter.dart` if shared candidate-to-dialog conversion needs a reusable seam
- Affected tests:
  - `memos_flutter_app/test/application/updates/announcement_delivery_policy_test.dart`
  - Debug preview/widget coverage where practical, or a focused extraction test if UI-level testing is too brittle
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - Item 2, no `application -> features` reverse dependencies: the change must preserve the presenter boundary and avoid reintroducing direct feature dialog imports into `application/updates`.
  - Item 4, no reused shared domain logic hidden inside screen or widget files: if v3 notice candidate conversion is shared between startup presentation and Debug preview, it should live behind an appropriate non-screen helper rather than being duplicated inside a widget method.
