## 1. Localization Resources

- [x] 1.1 Add `ptBr` / `pt_br` language labels to every existing `strings*.i18n.yaml` file under `languages`, `languagesNative`, and `legacy.app_language`.
- [x] 1.2 Create `memos_flutter_app/lib/i18n/strings_pt-BR.i18n.yaml` from `strings.i18n.yaml` using AI-assisted Brazilian Portuguese translation.
- [x] 1.3 Review the Portuguese YAML for preserved keys, indentation, placeholders, interpolation variables, and technical identifiers such as `Memos`, `WebDAV`, `API`, `PAT`, `Markdown`, and `AI`.

## 2. Locale Wiring

- [x] 2.1 Add `AppLanguage.ptBr` with the correct legacy label key in `app_preferences.dart`.
- [x] 2.2 Update `app_localization.dart` so `pt` device locales map to Brazilian Portuguese and `AppLanguage.ptBr` maps to `AppLocale.ptBr`.
- [x] 2.3 Update all exhaustive `AppLanguage` switches found by analyzer or search, including onboarding, desktop settings window locale mapping, sync feedback copy, and image editor i18n.
- [x] 2.4 Add Brazilian Portuguese to the onboarding language list and label/subtitle switches while keeping settings language selection driven by `AppLanguage.values`.
- [x] 2.5 Add a Brazilian Portuguese image editor i18n map for the existing plugin labels.

## 3. Generated Localization

- [x] 3.1 Run `dart run slang` from `memos_flutter_app` to regenerate `lib/i18n/strings.g.dart`.
- [x] 3.2 Verify generated `AppLocaleUtils.supportedLocales` includes `pt-BR` and the generated key count is consistent across locales.

## 4. Guardrails and Tests

- [x] 4.1 Add focused i18n tests for representative Brazilian Portuguese common, onboarding, and language-selection labels.
- [x] 4.2 Add or extend locale mapping tests to cover `pt-BR`, another `pt-*` locale fallback to `pt-BR`, and existing non-Portuguese mappings.
- [x] 4.3 Ensure the tests do not introduce new `state -> features`, `application -> features`, or `core -> higher layer` dependencies.

## 5. Verification

- [x] 5.1 Run focused localization tests, such as `flutter test test/i18n`.
- [x] 5.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.3 Run `flutter test` from `memos_flutter_app`.
- [x] 5.4 Run `openspec status --change add-portuguese-brazil-locale` and confirm the change is apply-ready/complete.
