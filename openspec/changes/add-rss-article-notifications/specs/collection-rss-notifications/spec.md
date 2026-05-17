## ADDED Requirements

### Requirement: RSS article notifications are opt-in
The system SHALL notify users about new RSS articles only for feeds or collection RSS sources where notifications are explicitly enabled.

#### Scenario: Notification-enabled feed receives new article
- **GIVEN** a subscribed RSS feed has notifications enabled
- **AND** RSS refresh inserts a new article for that feed
- **WHEN** notification permission is available
- **THEN** the system SHALL schedule a local notification for the new article or a bundled summary containing it
- **AND** the article SHALL record notification delivery state

#### Scenario: Notification-disabled feed receives new article
- **GIVEN** a subscribed RSS feed has notifications disabled
- **WHEN** RSS refresh inserts a new article for that feed
- **THEN** the system SHALL NOT schedule an RSS notification for that article
- **AND** the article SHALL remain available in the collection

### Requirement: RSS notification delivery is deduplicated
The system SHALL prevent duplicate notifications for the same RSS article across refresh retries and repeated scheduler runs.

#### Scenario: Refresh repeats the same article
- **GIVEN** an RSS article has already been notified
- **WHEN** a later refresh sees the same article again
- **THEN** the system SHALL NOT schedule another notification for that same article

#### Scenario: Notification scheduling fails
- **GIVEN** notification scheduling fails because permission is missing or the platform rejects scheduling
- **WHEN** refresh completes
- **THEN** RSS article ingestion SHALL still succeed
- **AND** the failure SHALL be recoverable without converting the article into a memo

### Requirement: RSS notification taps open the article context
The system SHALL route RSS notification taps to the relevant RSS article reading context.

#### Scenario: User taps RSS article notification
- **GIVEN** a notification payload references an existing RSS article
- **WHEN** the user taps the notification
- **THEN** the app SHALL open the RSS article in an appropriate collection or article detail context
- **AND** the article MAY be marked read according to the same read behavior used when opening it from the collection

#### Scenario: Notification context is missing
- **GIVEN** a notification payload references a feed, article, or collection that no longer exists
- **WHEN** the user taps the notification
- **THEN** the app SHALL show a recoverable missing-content state or route to the nearest available RSS collection context
- **AND** the app SHALL NOT crash

### Requirement: RSS notifications preserve memo boundaries
The RSS notification change SHALL NOT create memos or alter memo sync state as a side effect of notifying new articles.

#### Scenario: New RSS article notification is delivered
- **GIVEN** a new RSS article is eligible for notification
- **WHEN** the notification is scheduled or tapped
- **THEN** no memo SHALL be created automatically
- **AND** no Memos server API file SHALL be changed for notification behavior

#### Scenario: Notification planning is implemented
- **WHEN** RSS notification eligibility or delivery planning is added
- **THEN** reusable notification planning logic SHALL live outside collection screen widgets
- **AND** lower layers SHALL NOT import collection UI modules to deliver notifications
