# memos-tag-compatibility Specification

## Purpose
Preserve v0.27-compatible tags while keeping Markdown-aware extraction, tag reconciliation, and persisted tag maintenance consistent across sync, search, and local storage.
## Requirements
### Requirement: Memos v0.27 tag grammar compatibility
The app MUST recognize and preserve tag names that are valid under the Memos `0.27.x` backend tag grammar, including Unicode letters, Unicode numbers, Unicode symbols, Unicode marks, `_`, `-`, `/`, `&`, and zero-width joiner sequences, up to the supported tag length.

#### Scenario: Backend-compatible ampersand tag is preserved
- **WHEN** a v0.27 memo contains or returns the tag `science&tech`
- **THEN** the local memo, tag registry, and tag statistics MUST preserve the tag as `science&tech`

#### Scenario: Backend-compatible emoji sequence tag is preserved
- **WHEN** a v0.27 memo contains or returns a tag with a valid emoji variation selector or ZWJ sequence
- **THEN** the local memo, tag registry, and tag statistics MUST preserve the full tag sequence without stripping valid Unicode marks or joiners

#### Scenario: Hierarchical tag remains hierarchical
- **WHEN** a v0.27 memo contains or returns a hierarchical tag such as `work/project-2026`
- **THEN** the app MUST preserve the slash-separated hierarchy as a single tag path

### Requirement: V0.27 memo tag payload handling
The app MUST parse non-empty `tags` arrays from Memos `0.27.x` `ListMemos` responses and carry those values through remote sync into local storage and tag display data.

#### Scenario: Modern v0.27 list response includes non-empty tags
- **WHEN** `GET /api/v1/memos` returns a v0.27 memo JSON object with `tags: ["science&tech"]`
- **THEN** `Memo.fromJson` and the v0.27 API facade MUST expose `memo.tags` containing `science&tech`

#### Scenario: Remote sync receives v0.27 tags
- **WHEN** remote sync processes a v0.27 memo with non-empty backend `Memo.tags`
- **THEN** the local `memos.tags`, `tags`, `memo_tags`, and `tag_stats_cache` data MUST contain the backend-compatible tag path

### Requirement: Content fallback extraction covers full memo content
When backend tag payloads are absent, empty, stale, or when local-only memo content is saved, the app MUST extract valid inline tags from all relevant user-visible Markdown prose rather than using raw line scanning that ignores Markdown context.

#### Scenario: Tag appears in the middle of a multi-line memo
- **WHEN** a memo content body has no backend `tags` payload and contains `#middle-tag` on a middle non-empty line
- **THEN** remote sync fallback extraction MUST include `middle-tag` in the local memo tags and tag statistics

#### Scenario: Protected URL and Markdown fragments are not tags
- **WHEN** memo content contains Markdown links or URL fragments such as `https://example.com/page#section` or `[jump](#details)`
- **THEN** fallback extraction MUST NOT create tags from those protected fragments

#### Scenario: Fenced code block hashes are not tags
- **WHEN** memo content contains a fenced code block with code such as `#include <stdio.h>`
- **THEN** fallback extraction MUST NOT create `include` or other tags from inside the fenced code block
- **AND** valid tags outside the fenced code block MUST still be extracted

#### Scenario: Inline code hashes are not tags
- **WHEN** memo content contains inline code such as `` `#include` `` or `` `#not-a-tag` ``
- **THEN** fallback extraction MUST NOT create tags from the inline code span
- **AND** valid prose tags in the same memo MUST still be extracted

#### Scenario: User-visible prose tags remain supported
- **WHEN** memo content contains valid tags in ordinary paragraph text, list item text, blockquote text, or table cell text
- **THEN** fallback extraction MUST preserve those tags according to the documented tag grammar

### Requirement: Tag grammar remains a shared lower-layer seam
Tag parsing, Markdown-aware extraction, normalization, and write-path reconciliation behavior MUST remain centralized in stable lower-layer code and MUST NOT be duplicated in feature screens, widgets, or UI-only helpers.

#### Scenario: Feature UI renders tag data
- **WHEN** a feature screen, drawer, editor, or widget needs tag display or suggestions
- **THEN** it MUST consume shared tag data or shared tag helpers instead of implementing its own v0.27-specific parser

#### Scenario: Sync and search normalize tags
- **WHEN** state or data code normalizes tags for sync, search, or persistence
- **THEN** it MUST use the shared tag grammar seam so behavior remains consistent across API, sync, local DB, and UI surfaces

#### Scenario: Memo write paths reconcile tags
- **WHEN** memo create, edit, import, or sync code persists memo content and tag state
- **THEN** it SHOULD use a shared tag reconciliation seam that updates canonical tag paths, tag rows, `memo_tags`, redundant `memos.tags`, search, and statistics consistently
- **AND** call sites SHOULD NOT duplicate the low-level reconciliation sequence

### Requirement: Persisted memo tag representations remain consistent
The app SHALL treat `memo_tags` as the relationship and statistics source of truth while keeping `memos.tags` synchronized as a compatibility, search, and sync representation.

#### Scenario: Memo write stores canonical tags
- **WHEN** a memo is created or updated with extracted or provided tags
- **THEN** the app MUST resolve canonical tag paths
- **AND** it MUST update `memo_tags` with the matching tag ids
- **AND** it MUST write `memos.tags` with the same canonical paths
- **AND** search/statistics data MUST reflect the same canonical paths

#### Scenario: Tag hierarchy changes affect memo tags
- **WHEN** a tag is renamed, moved, or deleted in a way that changes canonical paths
- **THEN** affected memo tag relationships and redundant text/search/statistics representations MUST remain consistent with the resulting canonical paths

### Requirement: Stored tags can be recomputed under current extraction rules
The app SHALL provide a controlled maintenance operation that can recompute persisted memo tags from memo content using the current Markdown-aware extraction and reconciliation rules.

#### Scenario: Historical code-context false positive is repaired
- **GIVEN** an existing memo has a persisted false tag that only appears inside a code context
- **WHEN** the maintenance operation recomputes tags for that memo
- **THEN** the false tag MUST be removed from `memo_tags`, `memos.tags`, search, and tag statistics
- **AND** valid tags outside code contexts MUST remain persisted

#### Scenario: Maintenance avoids silent policy loss
- **WHEN** a recompute operation could remove stored tags that are not present in memo content
- **THEN** the operation MUST be explicit, documented, or otherwise scoped so users are not surprised by silent tag removal
