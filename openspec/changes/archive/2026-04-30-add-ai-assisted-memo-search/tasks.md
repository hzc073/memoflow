## 1. Shared AI Search Seam

- [x] 1.1 Extract reusable memo chunking/index freshness helpers from `AiAnalysisService` into a `data/ai` service or helper seam.
- [x] 1.2 Add an AI semantic memo search service that validates embedding configuration, embeds the query, scores ready chunks, groups results by memo, and returns ranked diagnostics.
- [x] 1.3 Add repository/query helpers for AI search candidate chunks, memo hydration, `ai_memo_policy` filtering, and generated AI-summary exclusion without adding feature-layer imports.
- [x] 1.4 Add unit tests with fake AI runtime/repository coverage for semantic ranking, missing embedding configuration, provider errors, and no-match results.

## 2. Memo Search State Integration

- [x] 2.1 Add AI search query/result models to the memo search state boundary, including loading, configuration-required, error, empty, and result states.
- [x] 2.2 Extend memo list source selection with an AI-assisted source kind while preserving keyword search as the default source for non-empty queries.
- [x] 2.3 Add a Riverpod provider that adapts memo search filters into the AI semantic search service and applies final result-limit/filter verification.
- [x] 2.4 Update query keys, pagination reset behavior, and diagnostics so switching keyword ↔ AI search cannot reuse stale list state.

## 3. Search UI Experience

- [x] 3.1 Add a no-results AI search CTA for non-empty keyword searches.
- [x] 3.2 Add at least one visible AI search affordance when keyword results exist, such as a bottom action, top action, or search dropdown entry.
- [x] 3.3 Render AI search loading, configuration-required, provider-error, and AI-empty states while keeping keyword search recoverable.
- [x] 3.4 Label AI-assisted results clearly so users can distinguish semantic matches from literal keyword results.

## 4. Modularity Guardrails

- [x] 4.1 Add or tighten architecture tests to ensure new AI search state providers do not import `features/*`.
- [x] 4.2 Add or tighten architecture tests to ensure memo list screens/widgets do not own embedding, chunking, ranking, or AI policy logic.
- [x] 4.3 Verify the shared `data/ai` seam can be reused by AI analysis and AI search without duplicating retrieval/domain logic in `features/memos` or `state/memos`.

## 5. Verification

- [x] 5.1 Add or update widget/provider tests for AI search CTA visibility, explicit user-trigger behavior, and keyword-default behavior.
- [x] 5.2 Add or update tests proving state, tag, date, advanced filters, result limits, and `ai_memo_policy` exclude ineligible AI search results.
- [x] 5.3 Run focused tests for changed AI/search modules in `memos_flutter_app`.
- [x] 5.4 Run `flutter analyze` from `memos_flutter_app`.
- [x] 5.5 Run `flutter test` from `memos_flutter_app`.
