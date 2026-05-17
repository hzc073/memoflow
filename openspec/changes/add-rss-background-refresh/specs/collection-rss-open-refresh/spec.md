## ADDED Requirements

### Requirement: RSS feeds refresh when an RSS collection is opened
The system SHALL support configurable best-effort refresh for subscribed RSS feeds when the user opens an RSS collection.

#### Scenario: Collection-open refresh is enabled
- **GIVEN** RSS collection-open refresh is enabled
- **AND** one or more feeds attached to the opened RSS collection are stale according to the configured interval
- **WHEN** the user opens that RSS collection
- **THEN** the system SHALL trigger a delayed stale-feed refresh after the collection surface is usable
- **AND** it SHALL refresh stale feeds using the same ingestion rules as manual refresh
- **AND** new articles SHALL be stored as RSS articles
- **AND** RSS articles SHALL NOT be converted into memos automatically

#### Scenario: Collection opens before refresh completes
- **GIVEN** RSS collection-open refresh is enabled
- **WHEN** the user opens an RSS collection
- **THEN** navigation and initial collection rendering SHALL NOT wait for RSS network refresh
- **AND** existing locally stored articles SHALL remain readable while refresh runs

#### Scenario: App starts or resumes without opening an RSS collection
- **GIVEN** RSS collection-open refresh is enabled
- **WHEN** the app starts, resumes, or remains open without the user opening an RSS collection
- **THEN** the system SHALL NOT run app-wide RSS refresh
- **AND** stale feeds SHALL wait until the user opens an RSS collection or manually refreshes RSS sources

### Requirement: RSS collection-open refresh is single-flight and bounded
The system SHALL prevent overlapping collection-open refresh runs from duplicating network and database work.

#### Scenario: Multiple collection-open refresh triggers overlap
- **GIVEN** an RSS collection-open refresh run is already active for a feed set
- **WHEN** another collection-open trigger requests refresh for overlapping feeds
- **THEN** the system SHALL not start duplicate refresh work for the same feeds
- **AND** it MAY coalesce the request into the active or next eligible run

#### Scenario: Many feeds in the opened collection are stale
- **GIVEN** many feeds attached to the opened RSS collection are stale
- **WHEN** collection-open refresh runs
- **THEN** the system SHALL refresh feeds with bounded concurrency
- **AND** one feed failure SHALL NOT prevent other feeds from refreshing

### Requirement: RSS collection-open refresh records recoverable status
The system SHALL record collection-open refresh results without blocking existing collection reading.

#### Scenario: Feed refresh succeeds
- **GIVEN** a subscribed feed refreshes successfully
- **WHEN** the refresh run completes
- **THEN** the feed SHALL record latest fetch and success timestamps
- **AND** previous refresh error metadata SHALL be cleared or superseded

#### Scenario: Feed refresh fails
- **GIVEN** a subscribed feed fails during collection-open refresh
- **WHEN** the refresh run completes
- **THEN** the feed SHALL record failure metadata
- **AND** existing articles SHALL remain readable
- **AND** other feeds in the run SHALL continue independently

### Requirement: RSS collection-open refresh avoids app-wide and platform background scheduling
The RSS collection-open refresh change SHALL NOT add app-wide RSS scheduling, OS-level background scheduling behavior, or permission requirements.

#### Scenario: Collection-open refresh is implemented
- **WHEN** RSS collection-open refresh is implemented
- **THEN** the app SHALL NOT refresh RSS globally on app start or app resume
- **AND** it SHALL NOT run a global foreground RSS refresh timer
- **AND** it SHALL NOT register platform background jobs for RSS refresh
- **AND** it SHALL NOT request background execution, exact alarm, battery optimization, or notification permissions for RSS refresh
- **AND** it SHALL NOT add new background scheduler dependencies such as `workmanager` or `background_fetch`

### Requirement: RSS collection-open refresh preserves architecture boundaries
The RSS collection-open refresh change SHALL keep refresh orchestration outside UI-owned fetch loops and persistence details outside app composition roots.

#### Scenario: Collection-open trigger is wired
- **WHEN** an RSS collection opening hook is connected
- **THEN** collection UI SHALL delegate to an RSS refresh coordinator or equivalent owned service
- **AND** collection UI SHALL NOT contain feed parsing loops or RSS SQLite primitives
- **AND** app composition roots SHALL NOT own RSS refresh scheduling

#### Scenario: Collection-open refresh is implemented
- **WHEN** RSS collection-open refresh writes feed or article state
- **THEN** writes SHALL flow through RSS-owned repository or persistence seams
- **AND** no Memos server API files SHALL be changed
