## ADDED Requirements

### Requirement: Plain search matches memo content substrings
The system SHALL treat a non-empty plain memo search query as a literal continuous substring query against memo content after trimming surrounding whitespace.

#### Scenario: CJK middle substring matches
- **GIVEN** a memo content is `在秩序中安顿`
- **WHEN** the user searches for `秩序`
- **THEN** the memo appears in the search results.

#### Scenario: CJK prefix still matches
- **GIVEN** a memo content is `在秩序中安顿`
- **WHEN** the user searches for `在` or `在秩序`
- **THEN** the memo appears in the search results.

#### Scenario: Non-matching fragment is excluded
- **GIVEN** a memo content is `在秩序中安顿`
- **WHEN** the user searches for a fragment that does not occur in the memo content
- **THEN** the memo does not appear in the search results.

#### Scenario: Query text is literal
- **GIVEN** a memo content contains characters that could have special meaning in `SQL`, `SQLite FTS`, or server filter syntax
- **WHEN** the user searches for those characters as plain text
- **THEN** the system matches them as literal query text and MUST NOT execute them as operators or wildcards.

### Requirement: Search behavior is consistent across memo search surfaces
The system SHALL apply the same plain-text memo content matching semantics to main memo search, local/offline search, shortcut search, quick search, and link-memo lookup.

#### Scenario: Same query across surfaces
- **GIVEN** a memo content matches a plain search query by substring
- **WHEN** the same query is used in main search, local/offline search, shortcut search, quick search, and link-memo lookup
- **THEN** each surface includes the memo when all non-text filters for that surface also match.

#### Scenario: Shortcut and quick filters remain additional constraints
- **GIVEN** a memo content matches the plain search query
- **WHEN** a shortcut filter or quick-search predicate is also active
- **THEN** the memo appears only if it satisfies both the plain substring query and the active shortcut or quick-search predicate.

### Requirement: Search preserves existing non-text filters
The system SHALL preserve state, tag, creator, date range, advanced filter, pinning, ordering, and result-limit behavior when adding substring matching.

#### Scenario: State filter remains enforced
- **GIVEN** a memo content matches the plain search query
- **WHEN** the memo state does not match the active state filter
- **THEN** the memo does not appear in the search results.

#### Scenario: Tag filter remains enforced
- **GIVEN** a memo content matches the plain search query
- **WHEN** the memo tags do not match the active tag filter
- **THEN** the memo does not appear in the search results.

#### Scenario: Date range filter remains enforced
- **GIVEN** a memo content matches the plain search query
- **WHEN** the memo display/create time falls outside the active date range
- **THEN** the memo does not appear in the search results.

### Requirement: Remote search differences are normalized for visible results
The system SHALL NOT rely on server token-prefix behavior as the sole source of truth for app-visible plain search results when local cached memo content is available.

#### Scenario: Server misses a cached substring match
- **GIVEN** a cached memo content contains the plain search substring
- **WHEN** the server search path does not return that memo because of token-prefix or version-specific search semantics
- **THEN** the app includes the cached memo in visible results if all other active filters match.

#### Scenario: Server returns a non-matching candidate
- **GIVEN** the server search path returns a memo candidate
- **WHEN** the memo content does not contain the plain search substring
- **THEN** the app excludes that memo from visible results unless another supported searchable field is explicitly part of the search contract.

#### Scenario: Unsynchronized remote-only memo is best effort
- **GIVEN** a memo exists only on the remote server and is not present in local cache
- **WHEN** the server APIs do not return that memo for the plain search query
- **THEN** the app is not required to display that memo.
