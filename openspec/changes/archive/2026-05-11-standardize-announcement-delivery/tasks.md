## 1. Phase A - Safe Preview Workflow

- [x] 1.1 Map current production update config fetch paths, Debug notice preview behavior, and startup announcement scheduling entry points.
- [x] 1.2 Add an announcement config source model for production, preview, custom URL, and local JSON where supported.
- [x] 1.3 Update the config service/provider seam so formal startup always uses production sources while Debug tools can request preview sources explicitly.
- [x] 1.4 Update Debug announcement preview UI to select and preview non-production config without writing formal dismissal state.
- [x] 1.5 Add focused tests for production source isolation, preview source loading, preview parse failures, and no dismissal-state mutation during preview.

## 2. Phase B - Schema V3 Contract and Compatibility

- [x] 2.1 Add schema v3 data models/enums for announcement item status, notice/update candidates, audience targeting, display policy, severity/priority, and dismissal policy.
- [x] 2.2 Extend `UpdateAnnouncementConfig` parsing to normalize v3 `notices`, `updates`, and `release_notes` into delivery candidates.
- [x] 2.3 Preserve legacy parsing for `version_info`, `announcement`, `notice_enabled`, `notice`, `debug_announcement`, and `release_notes`.
- [x] 2.4 Add id/revision-aware dismissal state for v3 notices without introducing commercial or entitlement state into public models.
- [x] 2.5 Add parser and model tests for v3 notices, v3 updates, legacy fallback, mixed v3/legacy config, locale fallback, and malformed optional fields.

## 3. Phase C - Eligibility and Startup Queue

- [x] 3.1 Add an application-layer announcement evaluation context containing platform, channel, app version, current time, language, and dismissal state.
- [x] 3.2 Implement eligibility checks for `status`, `publish_at`, `expire_at`, platform/channel targeting, min/max app version, and dismissal policy.
- [x] 3.3 Refine update channel policy so Android Play builds suppress full APK update prompts without blocking ordinary notice candidates.
- [x] 3.4 Implement startup delivery queue ordering for forced updates, critical blocking notices, optional update prompts, release highlights, and ordinary notices.
- [x] 3.5 Route startup announcement scheduling through the evaluator and queue while preserving legacy behavior when v3 candidates are absent.
- [x] 3.6 Add tests for eligibility combinations, Play-channel update suppression, ordinary notice eligibility on Play, queue priority, and at-most-one non-forced startup dialog selection.

## 4. Phase D - Presentation Boundary and Modularity Guardrail

- [x] 4.1 Define application-level announcement presentation request/result models that do not import `features/updates`.
- [x] 4.2 Add a presenter boundary that lets `application/updates` request UI presentation without directly constructing feature dialogs.
- [x] 4.3 Move `NoticeDialog` and `UpdateAnnouncementDialog` invocation behind a `features/updates` presenter implementation.
- [x] 4.4 Wire the presenter through app composition/provider seams without spreading private or commercial hooks.
- [x] 4.5 Remove direct `application/updates/update_announcement_runner.dart -> features/updates` dialog imports.
- [x] 4.6 Tighten `modularity_dependency_guardrail_test.dart` by removing the two `application/updates -> features/updates` allowlist entries and adding any needed boundary-specific assertion.
- [x] 4.7 Add application-layer tests that verify announcement policy and routing without widget dialog construction.

## 5. Phase E - Validation, Examples, and Release Governance

- [x] 5.1 Add production config validation for JSON parse errors, duplicate ids, invalid schedule bounds, missing public content, invalid forced update URLs, and `draft` items in production.
- [x] 5.2 Add warning diagnostics for suspicious but reviewable config such as long expiry windows, missing English content, unresolved release note links, and ambiguous testing wording.
- [x] 5.3 Add example production and preview config files or documented snippets covering v3 notices, updates, release notes, and legacy-safe fallback fields.
- [x] 5.4 Document the preview -> validate -> publish -> rollback announcement release workflow.
- [x] 5.5 Add validation tests for blocker diagnostics, warning diagnostics, and safe example config.

## 6. Verification

- [x] 6.1 Run focused update config parser tests.
- [x] 6.2 Run focused announcement eligibility, queue, and channel policy tests.
- [x] 6.3 Run focused Debug preview tests where supported.
- [x] 6.4 Run focused architecture guardrail tests, including `modularity_dependency_guardrail_test.dart`.
- [x] 6.5 Run `flutter analyze` from `memos_flutter_app`.
- [x] 6.6 Run `flutter test` from `memos_flutter_app`.
- [x] 6.7 Run `openspec status --change "standardize-announcement-delivery"` and confirm the change remains apply-ready.
