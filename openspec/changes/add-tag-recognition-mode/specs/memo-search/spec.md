## ADDED Requirements

### Requirement: Tag-filtered search follows tag recognition policy
Memo search SHALL apply tag filters against app-visible tags derived under the active `TagRecognitionPolicy`, so search results match the tag list and memo rendering semantics.

#### Scenario: Strict policy excludes inline-only tag
- **WHEN** active policy is `memoflowStrict`
- **AND** a memo contains `今天记录 #生活` only as ordinary body prose
- **AND** the user filters search results by tag `生活`
- **THEN** that memo MUST NOT appear solely because of the inline body hashtag

#### Scenario: Compatible policy includes inline tag
- **WHEN** active policy is `memosCompatible`
- **AND** a memo contains `今天记录 #生活`
- **AND** the user filters search results by tag `生活`
- **THEN** that memo SHALL be eligible to appear when all other active filters match

#### Scenario: Searchable tag metadata follows policy
- **WHEN** local search builds or verifies a canonical search document containing searchable tag metadata
- **THEN** the tag metadata MUST be derived from app-visible tags for the active recognition policy
- **AND** switching policies followed by user-confirmed recompute SHALL update search results to the new tag semantics

#### Scenario: Custom policy controls tag filter eligibility
- **WHEN** active policy is `custom`
- **AND** the policy disables ordinary inline body tags
- **AND** a memo contains `今天记录 #生活` only as ordinary body prose
- **AND** the user filters search results by tag `生活`
- **THEN** that memo MUST NOT appear solely because of the inline body hashtag

### Requirement: AI-assisted search tag constraints follow tag recognition policy
AI-assisted memo search SHALL enforce active tag filters using the same app-visible tag recognition policy as keyword search.

#### Scenario: Semantic candidate fails strict tag filter
- **WHEN** active policy is `memoflowStrict`
- **AND** AI-assisted search finds a semantically related memo whose only `#生活` occurrence is body prose outside strict tag zones
- **AND** the active tag filter is `生活`
- **THEN** the memo MUST be excluded from visible AI-assisted results
