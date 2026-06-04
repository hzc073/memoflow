## ADDED Requirements

### Requirement: Home engagement refreshes from Memos live events
The system SHALL refresh visible home memo engagement state from Memos `0.27.1+` `/api/v1/sse` live refresh events when the active server supports SSE and the engagement preference is enabled.

#### Scenario: Reaction upsert refreshes visible home engagement
- **WHEN** the app receives a `reaction.upserted` SSE event whose `name` identifies a memo currently visible on the home memo list
- **THEN** the system SHALL refresh that memo's reaction engagement state from the server
- **AND** the home memo card SHALL update the visible like state, like count, liker avatars, and other reaction summaries from the refreshed data

#### Scenario: Reaction delete refreshes visible home engagement
- **WHEN** the app receives a `reaction.deleted` SSE event whose `name` identifies a memo currently visible on the home memo list
- **THEN** the system SHALL refresh that memo's reaction engagement state from the server
- **AND** the home memo card SHALL update the visible like state, like count, liker avatars, and other reaction summaries from the refreshed data

#### Scenario: Comment creation refreshes visible home engagement
- **WHEN** the app receives a `memo.comment.created` SSE event whose `name` identifies a memo currently visible on the home memo list
- **THEN** the system SHALL refresh that memo's comment engagement state from the server
- **AND** the home memo card SHALL update the visible comment count and recent comment preview from the refreshed data

#### Scenario: Engagement preference disabled suppresses home live engagement rendering
- **WHEN** the engagement preference is disabled
- **AND** the app receives a reaction or comment SSE event for a memo on the home memo list
- **THEN** the home memo card SHALL continue to hide engagement UI
- **AND** the hidden UI SHALL NOT become visible solely because a live event was received

### Requirement: Live engagement refresh degrades safely when SSE is unavailable
The system SHALL treat Memos live refresh as an optional capability and preserve existing engagement behavior when `/api/v1/sse` is unavailable, unsupported, disconnected, or unauthenticated.

#### Scenario: Older server does not support SSE
- **WHEN** the active server version is older than Memos `0.27.1` or the SSE endpoint is unavailable
- **THEN** the system SHALL NOT require a live SSE connection for home memo cards to render
- **AND** existing engagement loading, manual refresh, navigation reload, and local optimistic like/comment behavior SHALL remain available

#### Scenario: SSE reconnect compensates for missed engagement events
- **WHEN** an SSE connection disconnects and later reconnects successfully
- **THEN** the system SHALL refresh active or visible engagement state that may have missed reaction or comment events
- **AND** the refreshed state SHALL come from the server rather than from cached SSE event payloads

#### Scenario: SSE payload is an invalidation hint
- **WHEN** the app receives a well-formed reaction or comment SSE event
- **THEN** the system SHALL treat the event as an invalidation hint for the affected memo
- **AND** the system SHALL NOT derive final like counts, comment previews, or creator lists solely from the SSE event payload

### Requirement: Live engagement refresh preserves architecture boundaries
The system SHALL implement live engagement refresh through stable data/state seams without adding reverse dependencies or moving shared SSE logic into memo widgets.

#### Scenario: SSE parsing stays outside memo widgets
- **WHEN** the app parses `/api/v1/sse` stream data, heartbeat comments, or live refresh event JSON
- **THEN** that parsing SHALL live in the Memos API/data layer or an equivalent non-widget service seam
- **AND** `MemoEngagementSurface`, home memo card widgets, and `MemoDetailScreen` SHALL NOT own SSE stream parsing or reconnection policy

#### Scenario: Engagement invalidation stays in provider or state owner
- **WHEN** a live refresh event needs to refresh reactions or comments for a memo
- **THEN** the mapping from live event type to engagement refresh SHALL live in a provider, controller, coordinator, or state-layer owner
- **AND** the implementation SHALL NOT introduce new imports from `state`, `application`, or `core` into `features/memos/**`

#### Scenario: No new lower-layer dependency on memo feature UI
- **WHEN** live engagement refresh is implemented during `evolve_modularity`
- **THEN** the change MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` imports
- **AND** reusable live refresh logic SHALL NOT be hidden inside screen or widget files
