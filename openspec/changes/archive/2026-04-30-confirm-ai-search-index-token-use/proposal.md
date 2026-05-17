## Why

AI-assisted memo search may build or refresh local embedding indexes before it can return semantic results. For remote embedding providers, this can consume provider tokens and send eligible memo chunks to the configured embedding route, so users should explicitly confirm token-consuming indexing before it starts.

## What Changes

- Add a preflight step before starting AI-assisted memo search that detects whether the current search scope needs new or refreshed embeddings.
- If no indexing is needed, AI search starts immediately without extra friction.
- If indexing is needed, show a localized confirmation dialog that includes an estimated token count and asks whether to continue.
- Keep keyword search as the current state when the user cancels the confirmation; no index jobs or embedding requests should be started by cancellation.
- Reuse the existing AI search service/repository seam for estimating index work instead of putting token estimation or freshness checks in memo list UI code.
- Localize all new user-visible copy for English, German, Japanese, Simplified Chinese, and Traditional Chinese Taiwan.
- Preserve existing AI search configuration, policy, visibility, tag/date/filter, and result-limit behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `memo-search`: Extend AI-assisted memo search requirements with preflight token-use confirmation for indexing/embedding work and localized confirmation copy.

## Impact

- Affected app areas:
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart` AI search start flow.
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart` callback wiring if the AI search action needs to become asynchronous.
  - `memos_flutter_app/lib/state/memos/...` provider seams for preflight estimation.
  - `memos_flutter_app/lib/data/ai/ai_semantic_memo_search_service.dart`, `ai_memo_indexing.dart`, and `ai_analysis_repository.dart` for reusable, UI-independent index preflight logic.
  - `memos_flutter_app/lib/i18n/strings*.i18n.yaml` and generated localization accessors for all new confirmation strings.
- Affected tests:
  - AI semantic search service tests for no-index-needed vs index-needed preflight estimates.
  - Memo list widget/screen tests for confirm, cancel, and immediate-start behavior.
  - Localization guardrails to prevent new AI search confirmation copy from being hard-coded in widgets.
  - Architecture guardrails or focused dependency tests to keep estimation logic out of UI widgets.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `1.` Avoid new `state -> features` reverse dependencies while adding preflight providers.
  - `4.` Keep reusable token/index estimation out of screen and widget files.
  - `8.` Tighten guardrails around AI search localization and service seams.
  - `10.` Leave touched AI search and memo list areas equal or better structured than before.
