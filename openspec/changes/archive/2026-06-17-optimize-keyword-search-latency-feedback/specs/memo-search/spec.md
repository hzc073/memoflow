## ADDED Requirements

### Requirement: Search optimization preserves canonical literal substring semantics
The system MUST preserve the canonical memo keyword search contract while optimizing latency. Candidate lookup strategies MAY change, but visible results MUST continue to be based on the normalized literal substring semantics provided by `MemoSearchMatcher` and the canonical document semantics provided by `MemoSearchDocumentBuilder`.

#### Scenario: Short CJK queries remain supported
- **WHEN** a memo canonical search document contains a 1-character or 2-character CJK literal substring used as the query
- **THEN** the memo MUST remain eligible to appear in keyword search results when all active filters match

#### Scenario: Searchable metadata remains covered
- **WHEN** the query appears in supported searchable metadata such as tags, clip-card source name, clip-card author name, source URL, URL host, or host without `www.`
- **THEN** the memo MUST remain eligible to appear in keyword search results even if the memo body does not contain the query

#### Scenario: Literal special characters remain literal
- **WHEN** the query contains characters that have special meaning in `SQL LIKE`, `SQLite FTS`, server filter syntax, or regular expressions
- **THEN** the system MUST treat those characters as literal search text and MUST NOT execute them as operators or wildcards

### Requirement: Dirty search index maintenance runs outside unbounded query work
The system MUST prevent large `memo_search_dirty` backlogs from creating unbounded synchronous work during user keyword search. Query-time dirty handling MAY exist as a bounded correctness fallback, but primary dirty-index maintenance SHOULD run through write, sync, self-repair, idle maintenance, startup maintenance, or another explicit maintenance seam.

#### Scenario: Dirty backlog exceeds query fallback budget
- **GIVEN** `memo_search_dirty` contains more entries than the query-time fallback budget
- **WHEN** the user runs a non-empty keyword search
- **THEN** the search path MUST avoid unbounded scanning or rebuilding of the entire dirty backlog before returning the first result set

#### Scenario: Dirty matching memo remains discoverable
- **GIVEN** a memo is marked dirty because its canonical search document changed
- **AND** the dirty backlog has not been fully drained
- **WHEN** the user searches for a literal substring contained in that memo's fresh canonical search document
- **THEN** the memo MUST remain discoverable through bounded fallback, refreshed index data, exact verification, or an explicit freshness state when all active filters match

#### Scenario: Background maintenance preserves visible semantics
- **WHEN** dirty entries are drained outside the user query path
- **THEN** subsequent keyword searches MUST return the same visible results as the canonical literal substring contract would return before and after the maintenance work

#### Scenario: Maintenance is batched
- **WHEN** dirty-index maintenance runs outside the query path
- **THEN** it SHOULD process work in bounded batches
- **AND** it SHOULD avoid long write locks that block normal memo reads or writes

### Requirement: Search filters move toward SQLite-owned candidate reduction
The system SHALL support safe keyword-search filters in data-layer candidate lookup before constructing broad `LocalMemo` lists for Dart filtering. Equivalent SQLite constraints SHOULD be preferred when available. Dart filtering MAY remain for filters that cannot be expressed safely or equivalently in SQLite.

#### Scenario: Stable filters reduce candidates before Dart filtering
- **WHEN** state, tag, date range, location presence, attachment presence, or relation presence filters are active and can be safely expressed in SQLite
- **THEN** the data-layer search path SHOULD apply those constraints before returning candidates to Dart filtering

#### Scenario: Location text filter is pushed down only when equivalent
- **WHEN** a location placeholder substring filter is active
- **THEN** the filter SHOULD be pushed down only if SQLite normalization and matching semantics remain equivalent to the existing Dart filter

#### Scenario: Dart-only filters remain verified
- **WHEN** attachment type, attachment name, shortcut predicate, or another filter cannot yet be expressed equivalently in SQLite
- **THEN** the system MAY keep that filter in Dart
- **AND** visible results MUST remain equivalent to the canonical filter semantics

### Requirement: Joplin is a reference for strategy, not a wholesale engine replacement
The system MUST treat Joplin-style search as a reference for background indexing and SQL query construction, not as a direct replacement for MemoFlow's keyword search semantics.

#### Scenario: FTS replacement remains out of scope
- **WHEN** this change is implemented
- **THEN** it MUST NOT replace the primary keyword search path with pure `SQLite FTS`, `SQLite FTS5 trigram`, or Joplin-style nonlatin fallback behavior

#### Scenario: Future engine migration requires a separate design
- **WHEN** a future search-engine migration changes the primary keyword search index
- **THEN** it MUST include benchmark coverage for memo count, searchable bytes, dirty backlog size, CJK short queries, English queries, tag search, URL host search, advanced filters, and remote-backed search
- **AND** it MUST specify how 1-character and 2-character CJK substring queries remain supported

### Requirement: Search optimization preserves modular boundaries
The system MUST implement future keyword search maintenance and SQL pushdown improvements without worsening known architecture hotspots during `evolve_modularity`.

#### Scenario: Search persistence remains data-layer owned
- **WHEN** search index tables, dirty backlog handling, or SQL candidate lookup are added or changed
- **THEN** `data/db` search persistence code MUST NOT import `features/`, `state/`, or `application/`

#### Scenario: State layer translates filters without owning DB maintenance
- **WHEN** `AdvancedSearchFilters` are mapped into database query constraints
- **THEN** `state/memos` MAY perform the translation
- **AND** `data/db` MUST consume stable data-layer parameters rather than importing state-layer filter types

#### Scenario: State layer does not depend on feature widgets
- **WHEN** search providers or coordinators are changed
- **THEN** they MUST NOT introduce new `state -> features` imports
