## Why

The newly added AI-assisted memo search UI currently contains hard-coded English strings, so users running the app in Chinese or other supported locales see mixed-language search states. This change localizes the AI search entry points, labels, loading/error/empty states, and tests so the feature matches the app's existing multilingual behavior.

## What Changes

- Move user-visible AI-assisted search copy out of `features/memos` widgets and into the existing app localization system.
- Add localized strings for AI search actions, labels, configuration-required state, loading copy, provider-error title, AI-empty state, and keyword-search recovery actions.
- Update memo search UI to render localized copy through `context.t` rather than hard-coded English literals.
- Update widget/state tests to assert localization behavior without weakening keyword-default or explicit user-trigger semantics.
- Add or tighten a guardrail/test so future AI search UI copy is not reintroduced as hard-coded English in memo list widgets.
- No changes to AI search retrieval, embedding, ranking, `ai_memo_policy`, server API routes, or commercial/private extension hooks are intended.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `memo-search`: AI-assisted search UI requirements now include localized user-visible copy for supported app locales.

## Impact

- Affected app areas:
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart` AI search UI copy.
  - Existing localization resources and generated localization accessors under `memos_flutter_app/lib/i18n/...`.
  - Memo search widget/view-state tests that currently assert English AI search labels.
- Affected tests:
  - Widget tests for AI search CTA, results label, configuration-required state, and recoverable keyword fallback.
  - Localization/guardrail tests preventing hard-coded AI search UI strings in memo list widgets.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `4.` Prevent reusable or user-visible feature policy from being hidden inside widgets as hard-coded strings.
  - `8.` Add or tighten guardrails for localized AI search UI copy.
  - `10.` Leave touched memo-search UI equal or better structured by routing copy through the existing localization seam.
