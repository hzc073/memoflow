## Context

Current memo search is keyword-first. `buildMemosListScreenQueryState` routes non-empty queries to keyword search, `MemoSearchCoordinator` normalizes local/remote literal substring behavior, and empty results render a simple no-results state. This is correct for exact text but weak for intent queries such as “吃什么”, where users expect semantically related memos like “大盘鸡”, “早餐”, or cooking notes.

The app already has AI infrastructure: provider settings, `AiTaskRuntime`, embedding-capable adapters, `ai_memo_policy`, `ai_chunks`, `ai_embeddings`, and analysis-time retrieval logic. However, much of the chunking/indexing/scoring behavior currently lives inside `AiAnalysisService`, so adding AI search directly in the UI or `state/memos` would duplicate shared domain logic and worsen coupling.

Architecture phase is `evolve_modularity`. This change touches `features/memos`, `state/memos`, and `data/ai`, so it must keep the touched area equal or better structured, especially checklist items `1`, `4`, `8`, and `10`.

Dependency direction before the change:

```text
features/memos ──▶ state/memos ──▶ data/db + data/api
features/review ─▶ state/review ─▶ data/ai
data/ai/AiAnalysisService owns private chunk/index/retrieval helpers
```

Dependency direction after the change:

```text
features/memos ──▶ state/memos ──▶ data/ai semantic-search seam
                                └▶ data/db search coordinator
features/review ─▶ state/review ─▶ data/ai shared retrieval/index seam
data/ai owns reusable AI memo index/search logic
```

No new `state -> features`, `application -> features`, or `core -> higher-layer` dependency is planned.

## Goals / Non-Goals

**Goals:**

- Preserve keyword search as the default for every plain query.
- Add a user-triggered AI-assisted semantic search mode for non-empty queries.
- Show AI search as a fallback in no-results states and as an optional “not satisfied” action when keyword results exist.
- Use embeddings for corpus-aware semantic retrieval against local memo content.
- Respect existing memo filters and `ai_memo_policy` before showing results.
- Extract or expose reusable AI memo retrieval/index logic from `AiAnalysisService` into a stable `data/ai` seam.
- Add guardrail coverage so AI search logic does not leak into UI widgets or create reverse dependencies.

**Non-Goals:**

- Do not replace literal substring search or change its matching contract.
- Do not automatically send every typed query to an AI provider.
- Do not add server API routes or depend on remote Memos server semantic search.
- Do not implement chat-only query expansion as the primary search path.
- Do not add commercial/private hooks, subscription logic, or paid-feature state.
- Do not change `modularity-governance` phase or checklist semantics.

## Decisions

### Decision 1: AI search is explicit, not automatic

AI search starts only when the user selects an AI action. The UI may present the action in the empty state, at the top/bottom of keyword results, or in a search menu/dropdown, but the default result stream remains keyword search.

Alternatives considered:

- **Auto-run AI when keyword search has no results**: convenient, but it sends user queries and possibly memo chunks to the configured provider without a clear action.
- **Always show AI results mixed into keyword results**: blurs exact matches and semantic matches, making search less predictable.

Rationale: explicit opt-in matches the product intent and reduces privacy surprise.

### Decision 2: Embedding-based retrieval is the MVP semantic path

AI search embeds the query, scores it against memo chunk embeddings, groups/ranks by memo, then hydrates visible `LocalMemo` results. This is the path that can retrieve “大盘鸡” for “吃什么” because it compares meaning rather than literal text.

Alternatives considered:

- **Chat model generates related keywords, then runs keyword search**: easier, but model hallucinations and synonym gaps can make results unstable.
- **Use server search filters**: current server APIs are keyword-oriented and version-dependent.

Rationale: existing AI settings and embedding adapters already support this capability, and embeddings provide corpus-aware ranking.

### Decision 3: Extract a reusable AI memo retrieval/index seam

Create or expose a `data/ai` service boundary for memo semantic search and shared indexing primitives. The service should own:

- AI configuration validation for embedding search.
- Memo eligibility checks, including `ai_memo_policy` and generated AI-summary exclusion.
- Chunk creation/index freshness checks.
- Query embedding, cosine scoring, memo grouping, and result diagnostics.
- Repository calls needed to hydrate or map ranked chunks back to memos.

`state/memos` should only adapt UI query state into provider calls and expose `AsyncValue`/result state. `features/memos` should only render actions, loading/error states, labels, and result lists.

Alternatives considered:

- **Implement AI scoring in `memos_list_screen.dart`**: fastest but violates checklist item `4`.
- **Implement AI scoring inside `state/memos` providers**: avoids UI duplication but still hides reusable domain logic in state glue.
- **Call private `AiAnalysisService` methods directly**: not possible cleanly and would keep retrieval logic analysis-specific.

Rationale: this improves the touched hotspot by extracting shared domain logic into a stable lower-layer seam.

### Decision 4: Preserve filters through coarse candidate scoping plus final verification

The AI search service should apply cheap candidate filters before scoring when possible, then apply final visibility/filter checks before results are shown. State, date range, tag, advanced filters, quick search/shortcut constraints, and result limit must not be weakened by semantic search.

Alternatives considered:

- **Score the entire corpus then filter after ranking only**: simpler but may return too few useful results after filters discard top semantic hits.
- **Duplicate every UI filter in SQL before scoring**: more precise but risks duplicating advanced-search logic and increasing coupling.

Rationale: a two-stage approach balances correctness with maintainability. Final visible results remain authoritative.

### Decision 5: AI results are visually labeled and separately keyed

When AI mode is active, visible results should communicate that they are semantic matches, not literal matches. Pagination/list signatures must include the search source so switching keyword ↔ AI mode resets list animation/pagination correctly.

Alternatives considered:

- **Reuse the same query key as keyword search**: risks stale animated list state and unclear diagnostics.
- **Blend AI and keyword results under one source kind**: makes debugging and user mental model harder.

Rationale: source-specific state improves correctness and clarity.

## Risks / Trade-offs

- **Indexing latency on first AI search** → Show a loading/progress state, cap candidate work, and reuse fresh embeddings for later searches.
- **Missing or invalid embedding configuration** → Return a configuration-required state with an action to open AI settings instead of failing silently.
- **Cloud AI privacy surprise** → Require explicit user action, respect `ai_memo_policy`, and avoid automatic query/index requests.
- **Poor semantic ranking for short queries** → Show semantic labels and allow users to return to keyword search; keep exact keyword results unchanged.
- **Duplicated AI retrieval logic** → Make seam extraction part of the implementation tasks, and add tests/guardrails around dependency direction.
- **Filter drift between keyword and AI search** → Add provider/service tests that verify state/tag/date/advanced filters still exclude ineligible memos.

## Migration Plan

1. Add the reusable `data/ai` semantic memo search seam and tests without changing the default search UI behavior.
2. Add `state/memos` provider/query models for AI search mode and source-specific diagnostics.
3. Add feature UI affordances for explicit AI search actions and labeled AI results.
4. Tighten architecture guardrails for the new seam.
5. Rollback strategy: hide/remove the UI entry points and source-kind routing while leaving reusable AI indexing code unused; keyword search remains unchanged.

No database migration is expected unless implementation discovers missing indexes or repository helpers. Existing `ai_chunks`, `ai_embeddings`, and `ai_memo_policy` tables should be reused.

## Open Questions

- Should the first implementation show the AI action both in the no-results state and in a search dropdown, or should the dropdown be deferred after the empty/bottom CTA ships?
- Should AI search include protected/private visibility categories exactly like AI analysis settings, or should memo search use the same visibility scope as normal memo listing and only rely on `ai_memo_policy`?
- Should AI search history be stored separately from keyword search history, or should it only reuse the query text without recording the search mode?
