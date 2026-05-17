## 1. Refresh Settings and State

- [x] 1.1 Add RSS refresh preferences for enabled state and interval.
- [x] 1.2 Add stale-feed selection logic based on last success/fetch timestamps.
- [x] 1.3 Add refresh run metadata for collection-open refresh attempts.

## 2. Collection-Open Refresh Coordinator

- [x] 2.1 Add an RSS collection-open refresh coordinator that reuses the MVP RSS fetch service.
- [x] 2.2 Add single-flight protection so overlapping triggers do not run duplicate refreshes.
- [x] 2.3 Add bounded concurrency for refreshing multiple stale feeds in the opened collection.
- [x] 2.4 Ensure per-feed failures do not abort the whole refresh run.

## 3. Collection Opening Integration

- [x] 3.1 Trigger a delayed stale-feed refresh when an RSS collection is opened and refresh is enabled.
- [x] 3.2 Scope the automatic refresh to feeds attached to the opened RSS collection.
- [x] 3.3 Ensure collection opening and first render are not blocked by RSS refresh.
- [x] 3.4 Keep manual RSS refresh immediate and independent from the collection-open stale interval.
- [x] 3.5 Do not add app-wide startup/resume refresh, global foreground timers, platform background scheduling, background permission flows, exact alarms, or new background scheduler dependencies.

## 4. Tests and Guardrails

- [x] 4.1 Add tests for stale-feed selection and interval behavior.
- [x] 4.2 Add tests for single-flight refresh behavior.
- [x] 4.3 Add tests for partial failure behavior.
- [x] 4.4 Add tests for collection-open delayed refresh trigger behavior.
- [x] 4.5 Add or tighten guardrails to keep RSS parsing/fetch loops out of collection widgets, keep app composition roots free of RSS refresh scheduling, and prevent platform background scheduler or permission leakage.

## 5. Verification

- [x] 5.1 Run `dart format` on changed Dart files in `memos_flutter_app`.
- [x] 5.2 Run focused RSS collection-open refresh coordinator tests.
- [x] 5.3 Run relevant architecture guardrail tests.
- [x] 5.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.5 Run `flutter test` from `memos_flutter_app`.
