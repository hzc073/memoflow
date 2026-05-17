## ADDED Requirements

### Requirement: AI-assisted memo search is explicit and user-triggered
The system SHALL keep literal keyword search as the default behavior for non-empty memo search queries and SHALL start AI-assisted semantic search only after an explicit user action for the current query.

#### Scenario: Keyword search remains default
- **WHEN** the user enters a non-empty memo search query
- **THEN** the system SHALL first execute the existing literal keyword search path and SHALL NOT automatically execute AI-assisted semantic search.

#### Scenario: Empty keyword results offer AI search
- **WHEN** keyword search for a non-empty query returns no visible memo results
- **THEN** the system SHALL present a user-triggered AI-assisted search action for that same query.

#### Scenario: Non-empty keyword results can still offer AI search
- **WHEN** keyword search for a non-empty query returns visible memo results
- **THEN** the system SHALL provide at least one user-triggered affordance that lets the user run AI-assisted search for the same query without replacing the default keyword behavior.

### Requirement: AI-assisted memo search retrieves semantic local matches
The system SHALL use configured embedding capability to retrieve local memos whose content is semantically related to the user query, even when the memo does not contain the query as a literal substring.

#### Scenario: Semantic food query finds related memo
- **GIVEN** a locally cached eligible memo discusses `大盘鸡`
- **WHEN** the user searches for `吃什么` and explicitly runs AI-assisted search
- **THEN** the memo SHALL be eligible to appear in AI-assisted results even if its canonical search document does not contain `吃什么` as a literal substring.

#### Scenario: AI search uses local corpus semantics
- **WHEN** AI-assisted search runs for a non-empty query
- **THEN** the system SHALL rank results by semantic relevance to eligible locally available memo content rather than by server keyword search behavior.

#### Scenario: AI search labels semantic results
- **WHEN** AI-assisted search results are displayed
- **THEN** the system SHALL indicate that the visible results come from AI-assisted semantic search rather than literal keyword matching.

### Requirement: AI-assisted memo search preserves filters and eligibility
The system SHALL preserve active memo search constraints and AI eligibility rules before showing AI-assisted results.

#### Scenario: State and date filters remain enforced
- **WHEN** AI-assisted search finds a semantically related memo outside the active state or date-range constraints
- **THEN** the system SHALL exclude that memo from visible AI-assisted results.

#### Scenario: Tag and advanced filters remain enforced
- **WHEN** AI-assisted search finds a semantically related memo that does not satisfy the active tag or advanced filters
- **THEN** the system SHALL exclude that memo from visible AI-assisted results.

#### Scenario: AI policy is respected
- **WHEN** a semantically related memo is marked as not allowed for AI processing
- **THEN** the system SHALL exclude that memo from AI-assisted indexing and visible AI-assisted results.

#### Scenario: Result limits remain bounded
- **WHEN** AI-assisted search produces more candidate memos than the active result limit
- **THEN** the system SHALL return no more visible AI-assisted results than the active limit allows.

### Requirement: AI-assisted memo search handles configuration and failure states
The system SHALL expose recoverable user-visible states when AI-assisted search cannot run or returns no semantic matches.

#### Scenario: Missing embedding configuration
- **WHEN** the user triggers AI-assisted search without a configured embedding route
- **THEN** the system SHALL show a configuration-required state and SHALL NOT silently fall back to unrelated keyword behavior.

#### Scenario: AI search is loading
- **WHEN** AI-assisted search is indexing, embedding, or ranking results for the current query
- **THEN** the system SHALL show a loading state associated with AI-assisted search.

#### Scenario: AI search fails
- **WHEN** AI-assisted search fails because the configured provider or local indexing operation returns an error
- **THEN** the system SHALL show an error state that keeps keyword search available.

#### Scenario: AI search has no matches
- **WHEN** AI-assisted search completes successfully but finds no eligible semantic matches
- **THEN** the system SHALL show an AI-specific empty state distinct from the default keyword no-results state.

### Requirement: AI-assisted memo search preserves modular boundaries
The system MUST implement AI-assisted search through reusable service, repository, and provider seams without placing semantic retrieval or ranking logic in memo list screens or widgets.

#### Scenario: UI renders AI search state only
- **WHEN** memo list UI code is updated for AI-assisted search
- **THEN** it MUST only render actions, labels, loading/error states, and result lists and MUST NOT own embedding, chunking, ranking, or AI policy logic.

#### Scenario: State providers do not depend on feature widgets
- **WHEN** state providers are added or changed for AI-assisted search
- **THEN** they MUST NOT introduce new `state -> features` imports.

#### Scenario: Shared AI retrieval logic is reusable
- **WHEN** AI-assisted search needs chunking, indexing, embedding, scoring, or memo eligibility checks
- **THEN** that logic MUST live in a reusable `data/ai` seam or lower-level repository/service owner instead of being duplicated inside `features/memos` or `state/memos`.

#### Scenario: Guardrails cover the new seam
- **WHEN** AI-assisted search is implemented during `evolve_modularity`
- **THEN** automated architecture guardrails MUST verify that the new search path does not worsen known reverse-dependency or shared-logic hotspots.
