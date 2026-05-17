## Why

MemoFlow already supports several selectable app languages, but Korean-speaking users currently fall back to English even when the device locale is Korean. Adding full Korean support improves onboarding, settings, core workflows, and generated locale behavior without changing server APIs or data formats.

## What Changes

- Add Korean as a selectable app locale identified by `ko`.
- Add Korean coverage for the main Slang localization resources, including common, onboarding, settings, legacy labels, and parameterized strings.
- Map Korean device/system locales to the Korean app locale when users choose `Follow System`.
- Expose Korean consistently in onboarding and settings language selection surfaces with localized and native labels.
- Extend app-level language behavior beyond the main generated strings so complete-version paths such as image editor labels, sync feedback, widget locale tags, and AI language guidance do not silently fall back to unrelated Chinese/English behavior.
- Add focused localization guardrails for Korean resource coverage, locale mapping, labels, and representative runtime placeholders.
- Preserve the current public/community build boundaries; no subscription, entitlement, billing, or private-extension behavior is introduced.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `app-localization`: Adds Korean locale support, Korean language selection, Korean system-locale mapping, Korean copy correctness, and Korean localization guardrails.

## Impact

- Affected app runtime areas:
  - `memos_flutter_app/lib/i18n/*.i18n.yaml`
  - `memos_flutter_app/lib/i18n/strings.g.dart`
  - `memos_flutter_app/lib/data/models/app_preferences.dart`
  - `memos_flutter_app/lib/core/app_localization.dart`
  - `memos_flutter_app/lib/features/onboarding/language_selection_screen.dart`
  - `memos_flutter_app/lib/features/settings/preferences_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`
  - `memos_flutter_app/lib/features/image_editor/i18n.dart`
  - `memos_flutter_app/lib/core/sync_feedback.dart`
  - `memos_flutter_app/lib/application/widgets/*`
  - representative AI/import flows that currently rely on binary Chinese/English helper behavior
- Affected tests:
  - `memos_flutter_app/test/i18n/chinese_localization_test.dart` or a new focused localization test file
  - targeted tests for language mapping and generated locale coverage
- Tooling:
  - Run `dart run slang` from `memos_flutter_app` after adding `strings_ko.i18n.yaml`.
  - Run focused localization tests, then `flutter analyze` and `flutter test` before PR.
- Architecture phase:
  - Active phase is `evolve_modularity`.
  - This change touches checklist item `10.` because localized behavior crosses UI, core helpers, generated resources, and application widget formatting paths.
  - It should not introduce new `state -> features`, `application -> features`, or `core -> higher-layer` dependencies.
  - As a scoped modularity improvement, duplicated language metadata such as locale tags and week-start behavior SHOULD be centralized behind a stable localization helper instead of adding more per-feature switches.
