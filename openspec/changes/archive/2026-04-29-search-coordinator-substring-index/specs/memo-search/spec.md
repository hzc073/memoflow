## ADDED Requirements

### Requirement: SearchCoordinator unifies non-empty memo search execution
The system MUST route every non-empty memo search request through a shared `SearchCoordinator` that applies the same query normalization, local candidate lookup, remote merge policy, and final local verification for main memo search, local/offline search, shortcut search, quick search, and link-memo lookup.

#### Scenario: Same query uses the same matching contract across surfaces
- **WHEN** the same non-empty query and equivalent filters are executed against the same local memo corpus from two supported memo-search surfaces
- **THEN** both searches MUST use the same literal substring matching contract and MUST NOT diverge solely because they come from different provider or controller paths

### Requirement: Memo search matches literal substrings in the canonical search document
The system MUST match a memo when the normalized query appears as a continuous literal substring in that memo's canonical search document. The canonical search document MUST include memo content and the searchable metadata already exposed to local memo search, including supported tags and clip-card search fields. The system MUST NOT require token-prefix, word-boundary, or tokenizer-dependent alignment for a match.

#### Scenario: CJK middle substring matches
- **WHEN** a memo canonical search document contains the text `在秩序中安顿` and the query is `秩序`
- **THEN** the memo MUST be returned as a search result

#### Scenario: Searchable metadata remains discoverable
- **WHEN** a memo's canonical search document includes searchable clip-card metadata or tags containing the normalized query as a continuous substring
- **THEN** the memo MUST be eligible to appear in results even if the memo body itself does not contain that substring

### Requirement: Indexed memo search preserves existing filter semantics
The system MUST apply the same state, tag, creator-scope, date-range, advanced-filter, and shortcut-predicate constraints to indexed, fallback, and remote-normalized candidates before they become visible results.

#### Scenario: Substring hit still respects tag and date filters
- **WHEN** a memo contains the query as a continuous substring but does not satisfy the active tag or date-range constraints
- **THEN** the memo MUST be excluded from visible search results

#### Scenario: Advanced filters apply after candidate lookup
- **WHEN** the substring index returns a candidate memo that fails the active advanced filters
- **THEN** the system MUST discard that memo before returning visible results

### Requirement: Search index invalidation is memo-scoped and incremental
The system MUST invalidate and rebuild search index state only for memos whose canonical search document changed or whose searchable rows were removed. The system MUST NOT require a global full-index rebuild to surface a single memo edit, clip-card update, tag change, or deletion.

#### Scenario: Edited memo becomes searchable without full rebuild
- **WHEN** a memo is updated so that its canonical search document now contains a new literal substring query
- **THEN** the system MUST rebuild search index state for that memo and MUST be able to return it for the new query without requiring a full-corpus backfill

#### Scenario: Deleted memo stops contributing old postings
- **WHEN** a memo is deleted or no longer eligible for search results after invalidation processing
- **THEN** its prior index entries MUST stop contributing matches to future searches

### Requirement: Visible results stay correct during partial reindex and remote normalization
The system MUST continue returning correct app-visible results while dirty index entries remain pending, and it MUST locally normalize remote candidates before showing them to the user.

#### Scenario: Dirty memo is still discoverable before rebuild completes
- **WHEN** a memo has been marked dirty after a local searchable-text change and its fresh substring postings have not yet been fully rebuilt
- **THEN** a matching query MUST still be able to return that memo through coordinator-managed fallback or exact verification

#### Scenario: Remote false positives are filtered out locally
- **WHEN** remote search returns a memo whose canonical search document does not contain the normalized literal query and the memo is not already confirmed as a local match
- **THEN** the system MUST exclude that memo from visible results

#### Scenario: Local indexed matches supplement remote misses
- **WHEN** remote search misses a memo that exists in the local cache and that memo satisfies the same filters plus the literal substring contract
- **THEN** the system MUST still include the local memo in visible results
