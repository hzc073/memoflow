## Context

Current AI-assisted memo search is explicit and user-triggered, but the start path moves directly from `MemosListScreen._startAiSearch()` to `aiSearchMemosProvider`, which calls `AiSemanticMemoSearchService.search`. Inside `search`, `_ensureIndexesForSearchScope` may enqueue stale memo index jobs and call the configured embedding route before any semantic results are shown.

This is safe from an architecture perspective because indexing already lives in `data/ai`, but it is not transparent enough for users of remote embedding providers: the first AI search over an unindexed scope can consume a large number of embedding tokens and send eligible memo chunks to the configured provider. The user request is a preflight confirmation model: no required indexing means search starts directly; required indexing means the app estimates token use and asks whether to continue.

Dependency direction before this change:

```text
features/memos -> state/memos -> data/ai semantic search service -> data/db
features/memos renders AI search actions and switches source state
data/ai owns chunking, freshness, embedding, and ranking
```

Dependency direction after this change:

```text
features/memos -> state/memos preflight provider -> data/ai preflight service -> data/db
features/memos -> state/memos AI search provider -> data/ai search service -> data/db
```

No `state -> features`, `application -> features`, or `core -> higher-layer` dependency is needed. The modularity improvement is to make token/index estimation a reusable `data/ai` service capability instead of letting screen code infer indexing cost.

## Goals / Non-Goals

**Goals:**

- Estimate whether the current AI search scope needs fresh embedding index work before starting AI search.
- Show a localized confirmation dialog with an estimated indexing token count when fresh embeddings are required.
- Start AI search immediately when no index work is needed.
- Ensure canceling the dialog leaves keyword search active and performs no index writes or embedding calls.
- Keep token estimation, memo eligibility, chunking, and freshness checks behind reusable data/state seams.
- Cover all supported locales: English, German, Japanese, Simplified Chinese, and Traditional Chinese Taiwan.

**Non-Goals:**

- Do not change AI search ranking, chunking thresholds, result limits, memo policy semantics, or provider routing.
- Do not add paid-feature, subscription, entitlement, or private/commercial state.
- Do not add pricing calculations, provider-specific cost estimates, or account billing integration.
- Do not change server API routes or files under `lib/data/api` or `test/data/api`.
- Do not persist a “never show again” preference in this change unless the implementation discovers an existing local-only warning preference seam that can be used without model churn.

## Decisions

### Decision 1: Add a read-only AI search preflight service result

Add a preflight method near `AiSemanticMemoSearchService`, for example `estimateIndexWorkForSearchScope`, returning a value such as:

```text
AiSemanticMemoSearchPreflight
  needsIndexing: bool
  estimatedTokenCount: int
  memoCount: int
  chunkCount: int
  profileKey/baseUrl/model/backendKind
```

The method should resolve the active embedding profile using the same logic as search, list eligible memo rows for the requested scope, reuse `AiMemoIndexing.memoRowAllowed`, `computeMemoContentHash`, `chunkMemo`, and repository freshness checks, and report only the work that would require new embeddings.

Alternative considered: estimate in `MemosListScreen` by counting current visible memos. This is rejected because UI-visible results do not equal the eligible indexing corpus, and it would duplicate policy/freshness/chunking rules in a widget hotspot.

### Decision 2: Preflight must not write or embed

The preflight path MUST NOT call `enqueueIndexJob`, `updateIndexJobStatus`, `invalidateActiveChunksForMemo`, `insertActiveChunks`, `insertEmbeddingRecord`, or `runtime.embed`. It may read memo rows and existing chunk/embedding status, and it may run deterministic in-memory chunking to estimate token count.

Alternative considered: call existing `_ensureIndexesForSearchScope` in a dry-run mode. This is risky because the current method performs writes and policy cleanup; separating read-only estimation makes cancellation behavior testable.

### Decision 3: Confirm only when required indexing tokens are estimated

If preflight returns `needsIndexing == false` or `estimatedTokenCount <= 0`, `_startAiSearch` should behave like today: add search history and activate AI search. If preflight says indexing is required, show a confirmation dialog before activating AI search.

The dialog should communicate:

- AI search needs to build/update a local semantic index first.
- Estimated indexing token count.
- Eligible memo chunks may be sent to the configured embedding model.
- For remote providers, this may consume provider quota or incur cost.
- For local providers, tokens still represent local processing work, but usually not remote billing.

Alternative considered: always warn before AI search because query embedding also consumes a small number of tokens. This is rejected because the requested interaction is specifically “no indexing means direct search, otherwise confirm,” and warning for every semantic query would make AI search feel noisy.

### Decision 4: Keep confirmation state in the feature shell, not lower layers

`MemosListScreen` can own the dialog presentation because it already owns the user action. State/data layers should expose only preflight facts. Lower layers should not depend on localization or `BuildContext`.

If `MemosListScreenBody.onStartAiSearch` needs async confirmation, update the callback type from `VoidCallback` to `Future<void> Function()` or a local typedef. The body widget still renders an action and invokes the callback; it must not estimate tokens or decide index eligibility.

Alternative considered: make `aiSearchMemosProvider` pause and emit a special “needs consent” state. This would couple provider state to dialog presentation and complicate the current `AsyncValue<List<LocalMemo>>` contract.

### Decision 5: Localize all new copy and guard it

Add new keys under the existing `strings.legacy` namespace in every `strings*.i18n.yaml` file, then regenerate `strings.g.dart` using the project’s existing localization tooling. Extend the hard-coded AI search UI copy guardrail to include the new English phrases.

Alternative considered: use existing generic `msg_confirm`, `msg_continue`, and `msg_cancel_2` only. Generic buttons can be reused, but the warning title/body/token message need dedicated localized keys because the cost/privacy context is AI-search-specific.

## Risks / Trade-offs

- Preflight may be expensive on very large memo libraries because it needs to inspect eligible rows and freshness. → Keep the logic in `data/ai`, add focused tests, and prefer repository helpers that can batch or short-circuit where practical.
- Token estimates are approximate because `AiMemoIndexing` uses bytes divided by four, not provider-specific tokenizers. → Label the value as estimated/about and avoid provider-specific billing claims.
- Existing search processes pending index jobs in bounded batches. → Align the estimate with the indexing work this search can actually trigger, or clearly treat the number as an upper-bound estimate for the current unindexed scope.
- Missing embedding configuration could be intercepted by preflight before the existing AI error UI appears. → Preserve current behavior by skipping token confirmation and allowing the existing configuration-required state to render, or map preflight configuration errors to the same user-facing state.
- Localization generation can cause large generated-file diffs. → Keep source YAML edits scoped and regenerate only through existing tooling.

## Migration Plan

1. Add the read-only preflight result and service/repository methods without changing existing search behavior.
2. Add provider wiring in `state/memos` so feature code can request preflight facts without importing data/db directly.
3. Update the AI search start action to run preflight and show the confirmation only when indexing is required.
4. Add localized strings for all supported locales and regenerate localization accessors.
5. Add focused service, widget/screen, localization, and guardrail tests.
6. Rollback strategy: remove the preflight call and dialog wiring; the existing AI search provider path remains intact.

## Open Questions

- None. This change intentionally uses a per-search preflight confirmation without adding a persistent “do not ask again” preference.
