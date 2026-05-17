## 1. Korean Resource Coverage

- [x] 1.1 Add `ko` language labels to the base and existing locale resources, including `languages`, `languagesNative`, and `legacy.app_language`.
- [x] 1.2 Create `memos_flutter_app/lib/i18n/strings_ko.i18n.yaml` with the same key coverage as `strings.i18n.yaml`.
- [x] 1.3 Translate Korean resource values while preserving placeholders, function parameters, emoji, product names, and technical identifiers.
- [x] 1.4 Run `dart run slang` from `memos_flutter_app` and verify `strings.g.dart` includes `AppLocale.ko`.

## 2. Runtime Locale Integration

- [x] 2.1 Add `AppLanguage.ko` with stable persisted value `ko` and label key `legacy.app_language.ko`.
- [x] 2.2 Map `Locale('ko')` to `AppLanguage.ko` and `AppLocale.ko` in core localization helpers.
- [x] 2.3 Update desktop settings window locale mapping so Korean works outside the main app shell.
- [x] 2.4 Add a stable language metadata helper for locale tag and week-start behavior, then use it from home widget snapshot/update paths.
- [x] 2.5 Ensure onboarding language options include Korean with localized and native labels.

## 3. Complete-Version Localization Paths

- [x] 3.1 Add Korean image editor translations and select them from `ImageEditorI18n.apply()`.
- [x] 3.2 Add Korean sync feedback messages for success, failure, auto-sync progress, and auto-sync result states.
- [x] 3.3 Review representative `trByLanguage()` and `prefersEnglishFor()` call sites used by AI/import guidance and ensure Korean requests Korean output instead of English or Chinese.
- [x] 3.4 Keep public/private split boundaries unchanged and avoid adding commercial or private-extension branching.

## 4. Tests and Guardrails

- [x] 4.1 Add focused Korean localization tests for generated locale support, `supportedLocalesRaw`, and Flutter locale exposure.
- [x] 4.2 Add Korean mapping tests for direct `ko`, `Follow System`, and existing locale mapping regressions.
- [x] 4.3 Add Korean label and placeholder tests covering common, onboarding/settings, language selection, and at least one parameterized string.
- [x] 4.4 Add a representative manual-path test for a non-Slang Korean behavior such as sync feedback or image editor labels.
- [x] 4.5 Add or run an architecture/dependency guardrail check confirming no new `state -> features`, `application -> features`, or `core -> higher-layer` dependency was introduced.

## 5. Validation

- [x] 5.1 Run focused localization tests from `memos_flutter_app`.
- [ ] 5.2 Run `flutter analyze` from `memos_flutter_app`.
- [ ] 5.3 Run `flutter test` from `memos_flutter_app`.
- [x] 5.4 Review generated/resource diffs for UTF-8 integrity and Korean text mojibake before handoff.
