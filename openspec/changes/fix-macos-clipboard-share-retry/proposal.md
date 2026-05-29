## Why

On macOS, clipboard URL clipping can respond once, fail, and then ignore a newly copied URL while the app remains foregrounded. This breaks the expected retry loop for a common clipping workflow: copy URL A, clipping fails, copy URL B, clip again.

The active architecture phase is `evolve_modularity`. This change touches checklist item 5 (`app.dart` composition-root responsibility), item 6 (feature/application collaboration through seams), item 8 (guardrail/test coverage), and item 10 (leave touched coupled areas equal or better structured). It also touches the known `application -> features` share-flow hotspot, so the work will add focused behavioral coverage and keep retry policy in the existing startup/share coordination seams instead of spreading more share logic into UI widgets.

## What Changes

- Add clipboard-share retry behavior so a completed, failed, or canceled macOS clipboard clipping attempt can be followed by a newly copied URL without restarting or backgrounding the app.
- Ensure active share-task state is cleared when macOS share task windows cancel or finish, and that stale active state does not indefinitely suppress future clipboard checks.
- Schedule a bounded clipboard re-check after share-flow completion/cancellation so a newly copied URL can be detected once the current clipping task releases ownership.
- Preserve duplicate suppression for the same URL so the app does not repeatedly prompt for an unchanged clipboard value.
- Add focused tests for retry scheduling, active-flow suppression, same-URL suppression, and desktop share task cleanup.
- No API behavior changes.

## Capabilities

### New Capabilities
- `clipboard-share-retry`: Defines how clipboard-detected URL clipping may be retried after failure, cancellation, or completion without requiring an app restart or lifecycle transition.

### Modified Capabilities
- `desktop-share-task-window`: Clarifies that desktop share task cancellation/result cleanup must release active task state so later clipboard clipping attempts are not blocked.

## Impact

- Affected code:
  - `memos_flutter_app/lib/app.dart`
  - `memos_flutter_app/lib/application/startup/startup_coordinator*.dart`
  - macOS desktop share task window cleanup paths as needed
- Affected tests:
  - Startup/share coordinator tests
  - App clipboard-share detection tests or focused testable seams
  - Desktop share task window cleanup tests
- Dependencies:
  - No new runtime dependencies expected.
- Systems:
  - Clipboard-detected third-party share flow
  - macOS desktop share task window lifecycle
  - Quick clip recovery trigger timing
