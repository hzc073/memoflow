## ADDED Requirements

### Requirement: RSS articles can fetch full content without becoming memos
The system SHALL support optional full-content fetching for RSS articles while preserving RSS articles as independent collection reading content.

#### Scenario: User fetches full content for an article
- **GIVEN** an RSS article has an original link
- **WHEN** the user requests full-content fetch for that article
- **THEN** the system SHALL fetch and extract readable content from the original link when possible
- **AND** the extracted content SHALL be stored in RSS-owned article state
- **AND** the system SHALL NOT create a memo automatically

#### Scenario: Feed has full-content fetching enabled
- **GIVEN** a subscribed RSS feed has full-content fetching enabled
- **WHEN** articles from that feed are refreshed
- **THEN** the system MAY fetch full content for eligible new or stale articles
- **AND** fetched content SHALL remain RSS article content unless the user explicitly saves the article as a memo

### Requirement: Full-content reader display preserves fallback content
The RSS reader SHALL prefer fetched full content when available and SHALL preserve feed-provided content as fallback.

#### Scenario: Full content exists
- **GIVEN** an RSS article has sanitized fetched full content
- **WHEN** the article is opened in the collection reader
- **THEN** the reader SHALL display the fetched full content as the primary body

#### Scenario: Full-content fetch fails
- **GIVEN** an RSS article has feed-provided content or summary
- **WHEN** full-content fetch fails
- **THEN** the reader SHALL continue to show the feed-provided content or summary
- **AND** the article SHALL remain readable
- **AND** the failure SHALL be recoverable by retrying or opening the original link

### Requirement: Full-content fetching is bounded and safe
The system SHALL constrain full-content fetching to avoid unbounded network, storage, and rendering risk.

#### Scenario: Fetched page is unsupported or unsafe
- **GIVEN** an RSS article original link returns unsupported, oversized, unsafe, or non-readable content
- **WHEN** full-content fetch runs
- **THEN** the system SHALL skip or fail that article's full-content fetch with recorded status
- **AND** it SHALL NOT store unsafe rendered content as trusted article body
- **AND** it SHALL NOT fail collection reading or feed refresh for other articles

#### Scenario: Multiple full-content fetches are requested
- **GIVEN** multiple RSS articles are eligible for full-content fetch
- **WHEN** full-content fetching runs
- **THEN** the system SHALL use bounded concurrency
- **AND** one article failure SHALL NOT prevent other eligible articles from completing

### Requirement: Full-content extraction preserves architecture boundaries
The full-content extraction change SHALL keep reusable extraction and sanitization logic outside UI widgets and lower layers free of feature UI dependencies.

#### Scenario: Extraction logic is shared
- **WHEN** existing web clipping or article extraction logic is reused
- **THEN** reusable logic SHALL live in a stable service layer
- **AND** data, application, or state layers SHALL NOT import collection widgets or share-capture UI

#### Scenario: Save as memo uses fetched content
- **GIVEN** an RSS article has fetched full content
- **WHEN** the user explicitly chooses to save the article as a memo
- **THEN** memo creation SHALL flow through the approved memo creation seam
- **AND** the RSS article SHALL record saved memo linkage
- **AND** no Memos server API compatibility files SHALL be changed unless separately approved
