## Context

Current tag flow:

```text
memo content
  -> extractTags(content) in core/tags.dart
  -> memo write path
  -> TagDbPersistence.resolvePath
  -> tags + memo_tags + memos.tags + FTS/stats cache
  -> tagStatsProvider + tag UI
```

The weak point is the first step. `extractTags` scans lines with regex and protects some inline URL/link ranges, but it does not have Markdown block or inline context. This explains false positives from fenced code and inline code.

The local storage model is already more mature than the extractor. `tags` owns metadata and hierarchy, `memo_tags` owns memo/tag relationships, and `memos.tags` is a redundant text representation used by search, sync, and compatibility paths.

Architecture phase is `evolve_modularity`. This change touches shared domain parsing and memo write paths, so it must improve ownership rather than spread tag rules into feature widgets.

## Goals / Non-Goals

**Goals:**

- Make extraction Markdown-aware while preserving existing supported tag characters.
- Keep a single shared tag grammar/normalization seam.
- Introduce or formalize a tag reconciliation seam used by memo create/edit/import/sync paths.
- Keep `memo_tags`, `memos.tags`, search, and tag stats synchronized after memo writes and tag maintenance.
- Provide a maintenance path to recompute stored tags for existing memos.
- Add tests at the lowest stable layer plus focused integration coverage for persistence consistency.

**Non-Goals:**

- Do not rewrite the tag management UI.
- Do not remove alias, color, pinned, or hierarchy behavior.
- Do not migrate away from SQLite tables already in use.
- Do not use UI rendering as the source of tag truth.

## Rules

### Rule 1: Tag extraction is Markdown-aware

`extractTags(content)` MUST NOT recognize tags inside:

- fenced code blocks using backticks or tildes;
- indented code blocks when parsed as Markdown code;
- inline code spans;
- Markdown link destinations and URL fragments;
- raw HTML/code contexts that the Markdown parser exposes as code or protected nodes.

It MUST continue recognizing valid tags in ordinary paragraph text, headings where the hash is not heading syntax, list items, task list item text, blockquotes, and table text where the Markdown AST represents user-visible prose.

### Rule 2: Existing tag grammar remains compatible

The extractor and normalizer MUST continue preserving supported tag characters documented by `memos-tag-compatibility`: Unicode letters, numbers, symbols, marks, `_`, `-`, `/`, `&`, and ZWJ sequences, with the existing maximum length behavior.

### Rule 3: One shared lower-layer seam owns tag grammar

Feature screens, widgets, and display helpers MUST NOT implement independent tag parsers. They may consume:

- extracted/canonical tag lists;
- `normalizeTagPath`;
- tag stats providers;
- tag color/canonical lookup helpers.

Any new parser or reconciler must live in a stable lower layer such as `core`, `data`, or a clearly owned application/service layer that does not depend on `features`.

### Rule 4: Tag reconciliation owns write-path consistency

Memo create/edit/import/sync paths SHOULD call a shared reconciliation operation that:

1. extracts or accepts raw tags;
2. normalizes and de-duplicates paths;
3. resolves aliases and canonical tag rows;
4. updates `memo_tags`;
5. writes `memos.tags`;
6. refreshes FTS/search and stats cache as needed.

Call sites SHOULD NOT manually repeat these steps.

### Rule 5: Storage source-of-truth is explicit

`memo_tags` SHALL be the relationship/statistics source of truth. `memos.tags` SHALL remain a synchronized redundant representation for compatibility, search indexing, and sync payloads. After any memo tag write, both representations MUST agree on canonical paths.

### Rule 6: Historical false positives can be repaired

The system SHOULD provide a controlled maintenance operation to recompute memo tags from memo content using the current extractor. It MUST update all dependent representations together and SHOULD be safe to run incrementally.

## Design Direction

Preferred implementation shape:

```text
core/tags.dart
  TagExtractor / extractTags
  normalizeTagPath

data/application seam
  TagReconciler
    raw content or raw tags
    -> canonical tag paths and ids

AppDatabaseWriteDao
  memo write path delegates tag consistency work

TagDbPersistence
  low-level row operations only
```

The exact class names may vary, but the dependency direction should remain:

```text
features -> state/application -> data -> core
```

No new `state -> features`, `application -> features`, or `core -> state|application|features` dependency should be introduced.

## Risks / Trade-offs

- Markdown parser behavior may differ slightly from Memos backend Goldmark. The app should target user-visible Markdown contexts and cover known false positives with tests.
- Recomputing historical tags may remove tags users intentionally stored only in `memos.tags` but not in content. The maintenance operation should be explicit and documented, not a silent destructive migration unless a later proposal narrows the policy.
- Existing write paths are numerous. A phased implementation should first centralize new behavior in shared helpers, then migrate call sites in focused batches.

## Open Questions

- Should the maintenance rebuild be automatic on app upgrade, user-triggered, or limited to affected memos after edits?
- Should backend-provided `Memo.tags` remain authoritative during remote sync, or should content-derived Markdown-aware extraction be allowed to remove backend tags that are absent from content?
- Should alias resolution affect the rendered label in memo content, or only stored canonical paths and tag chips?
