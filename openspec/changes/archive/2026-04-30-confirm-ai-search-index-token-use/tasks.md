## 1. Preflight Service Seam

- [x] 1.1 Add an immutable AI search index preflight result model in `data/ai` with `needsIndexing`, estimated token count, memo/chunk counts, and embedding profile/backend metadata.
- [x] 1.2 Add read-only repository helpers or service logic to identify stale/missing semantic index work for the active search scope without enqueueing jobs, invalidating chunks, inserting embeddings, or calling providers.
- [x] 1.3 Reuse `AiMemoIndexing` eligibility, content hash, chunking, and token estimate behavior when calculating required index work.
- [x] 1.4 Add focused `data/ai` tests for no-index-needed, first-index-needed, stale-index-needed, policy/visibility exclusions, missing configuration, and read-only preflight behavior.

## 2. State Provider Wiring

- [x] 2.1 Add a `state/memos` provider or service entry point that exposes AI search index preflight facts to feature code without introducing `state -> features` imports.
- [x] 2.2 Ensure preflight provider parameters match `AiSearchMemosQuery` scope fields so tag/date/filter/page context stays aligned with AI search.
- [x] 2.3 Add provider-level tests or existing provider coverage for successful preflight and configuration-error passthrough.

## 3. Memo List Confirmation Flow

- [x] 3.1 Update the AI search start callback path so `MemosListScreen` runs preflight before activating AI search.
- [x] 3.2 Start AI search immediately when preflight reports no required indexing tokens.
- [x] 3.3 Show a confirmation dialog when preflight reports required indexing tokens, including estimated token count and provider/backend-aware explanatory copy.
- [x] 3.4 Keep keyword search active and perform no indexing or embedding work when the user cancels the confirmation.
- [x] 3.5 Start the existing AI search provider flow when the user confirms, preserving existing loading, error, empty, result-label, and keyword recovery UI states.

## 4. Localization

- [x] 4.1 Add new AI search index confirmation keys to `strings.i18n.yaml`.
- [x] 4.2 Add equivalent German, Japanese, Simplified Chinese, and Traditional Chinese Taiwan translations.
- [x] 4.3 Regenerate localization accessors using the project’s existing Slang/i18n generation workflow.
- [x] 4.4 Extend hard-coded AI search UI copy guardrails to include the new confirmation phrases.

## 5. Verification

- [x] 5.1 Add or update memo list widget/screen tests for direct start, prompt-and-cancel, prompt-and-continue, and missing embedding configuration behavior.
- [x] 5.2 Add or tighten architecture guardrails proving token/index estimation stays out of memo list widgets and no new `state -> features` reverse dependency is introduced.
- [x] 5.3 Run focused tests covering `data/ai` preflight, memo list AI search confirmation UI, localization guardrails, and architecture guardrails.
- [ ] 5.4 Run `flutter analyze` and `flutter test` from `memos_flutter_app` before completing implementation.
- [x] 5.5 Confirm no `lib/data/api`, `test/data/api`, private/commercial hook, paid-feature state, or existing AI ranking behavior changed.
