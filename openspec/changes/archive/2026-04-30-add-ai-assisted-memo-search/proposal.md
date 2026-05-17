## Why

当前 memo search 只覆盖 literal substring matching。用户搜索模糊意图时，例如“吃什么”，期待能找到“大盘鸡”“早餐”“做饭”等语义相关内容，但默认关键词搜索无法召回这些结果。

This change adds an explicit AI-assisted semantic search fallback while preserving keyword search as the default, so users can opt into broader retrieval only when keyword results are empty or unsatisfactory.

## What Changes

- Add an AI-assisted memo search mode that can retrieve semantically related local memos for a plain query.
- Keep default search behavior as keyword/literal search; AI search MUST be user-triggered, not automatic.
- Surface AI search entry points when keyword results are empty and as an optional action when results are present but may be unsatisfactory.
- Reuse existing AI provider settings, embedding route, memo AI policy, and local memo cache where possible.
- Preserve existing state, tag, date range, advanced filter, quick search, shortcut, visibility, and result-limit constraints for AI-assisted results where applicable.
- Add user-visible states for missing AI configuration, loading, errors, empty semantic results, and AI-result labeling.
- During `evolve_modularity`, extract shared AI retrieval/search logic behind a stable service/provider seam instead of embedding it in UI widgets or duplicating private analysis-service logic.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `memo-search`: Extend memo search requirements with explicit AI-assisted semantic retrieval, user-triggered fallback behavior, result labeling, privacy/policy constraints, and modularity guardrails for the new search path.

## Impact

- Affected app areas:
  - `memos_flutter_app/lib/features/memos/...` search UI and empty-state affordances.
  - `memos_flutter_app/lib/features/memos/memos_list_screen_view_state.dart` search source selection.
  - `memos_flutter_app/lib/state/memos/...` memo search providers/coordinator boundaries.
  - `memos_flutter_app/lib/data/ai/...` reusable AI embedding/index/search services or repository seams.
  - `memos_flutter_app/lib/data/db/...` only if reusable query/index helpers are needed; no server API route changes are intended.
- Affected tests:
  - Search provider/widget tests for AI search entry points and source switching.
  - AI search service/repository tests for semantic ranking, policy filtering, and configuration failure states.
  - Architecture guardrail tests to prevent UI-specific AI search logic from moving into lower layers or new `state -> features` reverse dependencies.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched:
  - `1.` Avoid new `state -> features` reverse dependencies while adding state providers for AI search.
  - `4.` Prevent shared AI retrieval/domain logic from being hidden inside screen or widget files.
  - `8.` Add or tighten guardrails for the new AI search seam.
  - `10.` Leave touched search/AI areas equal or better structured than before.
