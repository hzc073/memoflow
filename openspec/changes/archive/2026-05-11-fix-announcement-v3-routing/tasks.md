## 1. Startup Surface Routing

- [x] 1.1 Add focused coverage in `memos_flutter_app/test/application/updates/announcement_delivery_policy_test.dart` for `release_highlight` notice candidates being excluded from formal startup selection.
- [x] 1.2 Update `AnnouncementDeliveryPolicy` so `_isNoticeEligible` rejects notice candidates whose `display.surface` is not `AnnouncementDisplaySurface.startupDialog`.
- [x] 1.3 Confirm existing startup-dialog notice candidates remain eligible when status, schedule, audience, content, and dismissal rules pass.

## 2. Debug V3 Notice Preview

- [x] 2.1 Add focused coverage for Debug preview resolving a schema v3 config that has `notices[]` but no legacy `notice`.
- [x] 2.2 Implement v3 notice preview selection for preview/custom/local JSON sources without reusing formal startup eligibility that rejects `preview` status.
- [x] 2.3 Reuse or extract candidate-to-`UpdateNotice` resolution so Debug preview and startup presentation use consistent locale/fallback behavior.
- [x] 2.4 Confirm Debug preview does not write `seenNoticeRevisions`, `lastSeenNoticeHash`, or other formal dismissal state.

## 3. Channel Routing and Modularity Guardrails

- [x] 3.1 Ensure Android Play startup still suppresses full APK update prompts while ordinary startup notices remain independently eligible.
- [x] 3.2 Verify the change does not reintroduce direct imports from `application/updates` to `features/updates` dialogs.
- [x] 3.3 If a shared helper is introduced, keep it in an appropriate feature/presenter seam and avoid placing reusable domain logic directly inside a screen method.

## 4. Verification

- [x] 4.1 Run `flutter test test/application/updates/announcement_delivery_policy_test.dart`.
- [x] 4.2 Run the focused Debug preview test added for this change.
- [x] 4.3 Run `flutter test test/application/startup/startup_coordinator_decision_test.dart` if channel-routing expectations are touched.
- [x] 4.4 Run `flutter analyze` after implementation.
- [x] 4.5 Run `openspec status --change "fix-announcement-v3-routing"` and confirm the change remains apply-ready.
