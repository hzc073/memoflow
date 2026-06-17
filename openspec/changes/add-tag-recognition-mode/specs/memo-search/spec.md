## ADDED Requirements

### Requirement: Tag-filtered search follows tag recognition mode
Memo search SHALL apply tag filters against app-visible tags derived under the active `TagRecognitionMode`, so search results match the tag list and memo rendering semantics.

#### Scenario: Strict mode excludes inline-only tag
- **WHEN** active mode is `memoflowStrict`
- **AND** a memo contains `今天记录 #生活` only as ordinary body prose
- **AND** the user filters search results by tag `生活`
- **THEN** that memo MUST NOT appear solely because of the inline body hashtag

#### Scenario: Compatible mode includes inline tag
- **WHEN** active mode is `memosCompatible`
- **AND** a memo contains `今天记录 #生活`
- **AND** the user filters search results by tag `生活`
- **THEN** that memo SHALL be eligible to appear when all other active filters match

#### Scenario: Searchable tag metadata follows mode
- **WHEN** local search builds or verifies a canonical search document containing searchable tag metadata
- **THEN** the tag metadata MUST be derived from app-visible tags for the active recognition mode
- **AND** switching modes followed by user-confirmed recompute SHALL update search results to the new tag semantics

### Requirement: AI-assisted search tag constraints follow tag recognition mode
AI-assisted memo search SHALL enforce active tag filters using the same app-visible tag recognition mode as keyword search.

#### Scenario: Semantic candidate fails strict tag filter
- **WHEN** active mode is `memoflowStrict`
- **AND** AI-assisted search finds a semantically related memo whose only `#生活` occurrence is body prose outside strict tag zones
- **AND** the active tag filter is `生活`
- **THEN** the memo MUST be excluded from visible AI-assisted results
