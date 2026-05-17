## 1. Localization Resources

- [x] 1.1 Inventory every user-visible AI-assisted search string in `MemosListScreenBody` and map each string to a stable localization key.
- [x] 1.2 Add base English AI search keys under the existing `strings.legacy` localization namespace.
- [x] 1.3 Add German, Japanese, Simplified Chinese, and Traditional Chinese Taiwan translations for the new AI search keys.
- [x] 1.4 Regenerate `strings.g.dart` using the existing `slang` configuration.

## 2. UI Integration

- [x] 2.1 Replace hard-coded AI search entry-point and source-label copy with generated localization accessors.
- [x] 2.2 Replace hard-coded AI search configuration, loading, error, empty-state, and keyword recovery copy with generated localization accessors.
- [x] 2.3 Verify the UI still keeps keyword search as the default and AI search as an explicit user-triggered action only.

## 3. Tests and Guardrails

- [x] 3.1 Update affected memo search widget/view-state tests to assert localized AI search labels through the generated localization API.
- [x] 3.2 Add or tighten a guardrail test that fails when known AI-assisted search English UI phrases are hard-coded in memo list widgets.
- [x] 3.3 Verify the guardrail does not scan generated localization output or translated resource files as violations.

## 4. Verification

- [x] 4.1 Run focused tests covering memo search localization and the hard-coded-string guardrail.
- [x] 4.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 4.3 Confirm no `lib/data/api`, `test/data/api`, AI ranking, embedding, memo policy, private hook, or commercial-state behavior changed.
