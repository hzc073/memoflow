## Context

`add-ai-assisted-memo-search` added the first AI search UI path, but several user-visible labels are currently hard-coded in `MemosListScreenBody`, such as AI search CTAs, AI result labels, configuration-required copy, and keyword-search recovery actions. The app already uses `slang` YAML resources under `memos_flutter_app/lib/i18n/` and generated accessors in `strings.g.dart`, so the correct seam for this copy is the existing localization layer rather than widget literals.

Current dependency shape:

```text
features/memos/widgets/MemosListScreenBody
  ├─ renders memo search UI
  ├─ reads existing localized strings through context.t
  └─ also owns new hard-coded AI search English copy
```

Target dependency shape:

```text
features/memos/widgets/MemosListScreenBody
  └─ context.t.strings.legacy.<ai_search_key>
       └─ generated from lib/i18n/*.i18n.yaml
```

No state, `data/ai`, repository, database, or API route behavior should change. This is a UI localization and guardrail change during `evolve_modularity`; it should leave the touched UI area better structured by moving reusable user-facing copy into the existing localization seam and adding tests that prevent regression.

## Goals / Non-Goals

**Goals:**

- Localize all AI-assisted memo search user-visible copy introduced by the AI search UI.
- Cover every supported locale file currently present: base English, German, Japanese, Simplified Chinese, and Traditional Chinese for Taiwan.
- Regenerate `strings.g.dart` from the YAML resources instead of manually hand-editing generated accessors.
- Update widget tests to assert localized strings through the generated localization API.
- Add or tighten a lightweight guardrail that catches hard-coded AI search UI copy in memo list widgets.

**Non-Goals:**

- Do not change AI search semantics, ranking, embedding configuration, `ai_memo_policy`, indexing, or result filtering.
- Do not add server API routes or remote semantic-search support.
- Do not introduce new localization frameworks or external dependencies.
- Do not add private/commercial hooks or paid feature state.
- Do not make generated `AccessDecision.source` or any diagnostic metadata drive UI visibility.

## Decisions

### Decision 1: Use existing `legacy` localization namespace

Add AI search strings under the existing `strings.legacy` namespace because `MemosListScreenBody` already uses `context.t.strings.legacy` for adjacent memo-list empty/loading/search copy.

Alternatives considered:

- **Create a new `memo_search` namespace**: cleaner long-term grouping, but it increases generated API churn and is unnecessary for this scoped fix.
- **Keep constants in Dart**: simpler, but fails the multilingual requirement and keeps copy hidden inside widgets.

Rationale: Reusing the current namespace minimizes code churn and keeps this change focused on localization rather than restructuring the i18n tree.

### Decision 2: Source YAML is canonical; generated Dart is regenerated

Implementation should update `strings.i18n.yaml`, `strings_de.i18n.yaml`, `strings_ja.i18n.yaml`, `strings_zh-Hans.i18n.yaml`, and `strings_zh-Hant-TW.i18n.yaml`, then run the configured `slang` generation from `memos_flutter_app`.

Alternatives considered:

- **Manually edit `strings.g.dart` only**: fast but brittle and likely to be overwritten by the next generation run.
- **Update only English and fallback to base locale**: technically works due to fallback, but still displays English in non-English locales.

Rationale: The YAML resources should remain the source of truth, and all supported locales should provide first-class UI copy.

### Decision 3: Tests should assert localization behavior, not raw hard-coded text in widgets

Widget tests can still assert visible labels, but they should obtain expected strings from `t.strings.legacy` or locale-specific app setup instead of duplicating English literals when possible. A guardrail should scan the memo-list body for known AI search English phrases and fail if they reappear outside localization resources.

Alternatives considered:

- **Only snapshot current English UI text**: catches accidental removal but not localization regressions.
- **Rely on analyzer only**: analyzer cannot detect user-visible hard-coded strings.

Rationale: The bug is specifically localization leakage, so tests should prove the copy flows through the localization seam.

## Risks / Trade-offs

- **Risk: Generated file drift** → Run `dart run slang` or the project’s configured localization generation command and include `strings.g.dart` with the YAML changes.
- **Risk: Translation wording may need product review** → Use concise, neutral translations and keep terms such as “AI” recognizable across locales.
- **Risk: Hard-coded string guardrail becomes too broad** → Target only the known AI search phrases introduced by the feature, not every English word in memo UI.
- **Risk: OpenSpec change depends on unarchived AI search work** → Treat this as a follow-up to the active `add-ai-assisted-memo-search` implementation; implementation should only touch localization and tests for that UI.

## Migration Plan

1. Add AI search localization keys to every supported YAML locale file.
2. Regenerate `strings.g.dart` from `memos_flutter_app`.
3. Replace hard-coded AI search UI literals in `MemosListScreenBody` with generated localization accessors.
4. Update focused widget tests and guardrails.
5. Run focused tests and `flutter analyze`; note any pre-existing full-suite blockers separately.

Rollback is straightforward: revert the YAML/generated-string/widget/test changes. No persisted data, database schema, server API, or AI index migration is involved.

## Open Questions

- Exact translation wording can be adjusted during implementation if the existing app terminology suggests better phrasing for each locale.
- If future memo-search copy grows beyond this small set, a later cleanup may introduce a dedicated `memo_search` localization namespace.
