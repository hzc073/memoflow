# memos-tag-compatibility Specification

## Purpose
TBD - created by archiving change align-v027-tag-grammar. Update Purpose after archive.
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
When backend tag payloads are absent, empty, or stale, the app MUST extract valid inline tags from all relevant memo content lines rather than only the first and last non-empty lines.

#### Scenario: Tag appears in the middle of a multi-line memo
- **WHEN** a memo content body has no backend `tags` payload and contains `#middle-tag` on a middle non-empty line
- **THEN** remote sync fallback extraction MUST include `middle-tag` in the local memo tags and tag statistics

#### Scenario: Protected URL and Markdown fragments are not tags
- **WHEN** memo content contains Markdown links or URL fragments such as `https://example.com/page#section` or `[jump](#details)`
- **THEN** fallback extraction MUST NOT create tags from those protected fragments

### Requirement: Tag grammar remains a shared lower-layer seam
Tag parsing and normalization behavior MUST remain centralized in a stable lower layer and MUST NOT be duplicated in feature screens, widgets, or UI-only helpers.

#### Scenario: Feature UI renders tag data
- **WHEN** a feature screen, drawer, editor, or widget needs tag display or suggestions
- **THEN** it MUST consume shared tag data or shared tag helpers instead of implementing its own v0.27-specific parser

#### Scenario: Sync and search normalize tags
- **WHEN** state or data code normalizes tags for sync, search, or persistence
- **THEN** it MUST use the shared tag grammar seam so behavior remains consistent across API, sync, local DB, and UI surfaces

