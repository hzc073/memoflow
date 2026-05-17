## ADDED Requirements

### Requirement: Memo search persistence extraction preserves visible search semantics
The system MUST preserve existing memo search result behavior while moving canonical search-document construction and SQLite search-index persistence out of the monolithic `AppDatabase` implementation.

#### Scenario: Literal substring behavior remains unchanged
- **WHEN** a non-empty memo search query is executed after the persistence extraction
- **THEN** the system MUST continue to match canonical search-document literal substrings, including CJK middle substrings and literal characters that have special meaning in `SQL`, `LIKE`, or `SQLite FTS`.

#### Scenario: Searchable metadata remains part of the canonical document
- **WHEN** memo body text does not contain the query but supported tags or clip-card metadata do contain the query
- **THEN** the memo MUST remain eligible to appear in search results according to the existing canonical search-document contract.

#### Scenario: Existing filters and ordering remain constraints
- **WHEN** indexed, dirty, fallback, or remote-normalized search candidates are merged
- **THEN** the system MUST continue to enforce active state, tag, date-range, advanced-filter, ordering, pinning, and result-limit behavior before returning visible results.

### Requirement: Memo search index persistence is owned by a data-layer seam
The system MUST own memo search SQLite table creation, index maintenance, dirty-entry draining, and legacy `memos_fts` recovery through focused data-layer persistence code rather than embedding those responsibilities directly in `AppDatabase`.

#### Scenario: AppDatabase remains a facade and lifecycle owner
- **WHEN** local search tables, `memos_fts`, `memo_search_documents`, `memo_search_substrings`, or `memo_search_dirty` are created, rebuilt, drained, or queried
- **THEN** `AppDatabase` MUST delegate the search-specific SQLite work to a focused data-layer owner while retaining database open, migration ordering, public facade, and notification responsibilities.

#### Scenario: Search index invalidation remains memo-scoped
- **WHEN** a memo, tag mapping, clip-card row, or searchable row is updated or deleted
- **THEN** the extracted persistence path MUST preserve memo-scoped dirty marking, index replacement, or index deletion without requiring a full search-index rebuild for every change.

#### Scenario: Partial reindex remains correct
- **WHEN** dirty search-index entries remain pending after a local searchable-text change
- **THEN** search results MUST continue to include matching dirty memos through the existing fallback or exact-verification behavior.

### Requirement: Memo search document rules are reusable without AppDatabase
The system MUST expose canonical memo search-document construction through a reusable lower-level seam that does not require importing or instantiating `AppDatabase`.

#### Scenario: State search code uses the pure search-document seam
- **WHEN** state-layer search coordination normalizes remote candidates or performs in-memory exact verification
- **THEN** it MUST use the reusable search-document helper rather than calling `AppDatabase` static helpers for pure text construction.

#### Scenario: Database search and state search share one canonical rule
- **WHEN** the database search path builds indexed documents and state search code verifies remote candidates
- **THEN** both paths MUST use the same canonical search-document construction semantics.

### Requirement: Memo search persistence preserves modular boundaries
The system MUST keep extracted memo search persistence code independent of higher app layers and MUST guard against reintroducing search persistence ownership into feature, state, or application code.

#### Scenario: Persistence seam has no upward imports
- **WHEN** memo search DB persistence files are added or changed
- **THEN** automated architecture checks MUST fail if those files import `features/`, `state/`, or `application/`.

#### Scenario: Guardrails cover AppDatabase search utility leakage
- **WHEN** state-layer search code is added or changed
- **THEN** automated architecture checks MUST fail if pure canonical search-document construction is accessed through `AppDatabase` instead of the reusable search-document seam.

#### Scenario: No new reverse dependencies are introduced
- **WHEN** memo search persistence extraction is implemented during `evolve_modularity`
- **THEN** it MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` imports.
