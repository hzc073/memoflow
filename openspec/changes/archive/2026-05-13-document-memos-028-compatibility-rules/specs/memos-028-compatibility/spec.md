## ADDED Requirements

### Requirement: Memos 0.28 is a first-class API version
The system SHALL represent Memos `0.28.x` as an explicit supported API version rather than silently mapping it to `0.27.0`.

#### Scenario: Manual server version accepts 0.28
- **WHEN** the user or stored account configuration selects server version `0.28` or `0.28.x`
- **THEN** the system SHALL normalize it to a `0.28.x` API version

#### Scenario: Version selector exposes 0.28
- **WHEN** the login or version probe UI lists supported Memos server versions
- **THEN** the list SHALL include `0.28.0`

#### Scenario: 0.28 API facade is routed explicitly
- **WHEN** an authenticated, unauthenticated, session-authenticated, or password sign-in API client is created for `0.28.x`
- **THEN** the system SHALL route through the explicit `0.28.x` compatibility profile

### Requirement: Memos 0.28 list requests use supported order fields
The system SHALL NOT send `display_time` as a `ListMemos.order_by` field when the active server version is Memos `0.28.x`.

#### Scenario: Explore list avoids display_time
- **WHEN** Explore loads memos from a Memos `0.28.x` server
- **THEN** the request SHALL use only order fields supported by Memos `0.28.x`
- **AND** the request SHALL NOT include `display_time desc`

#### Scenario: Explore random review avoids display_time
- **WHEN** random review samples Explore memos from a Memos `0.28.x` server
- **THEN** the request SHALL use only order fields supported by Memos `0.28.x`
- **AND** the request SHALL NOT include `display_time desc`

#### Scenario: Remote search fallback avoids display_time
- **WHEN** remote memo search fallback lists memos from a Memos `0.28.x` server
- **THEN** the request SHALL use only order fields supported by Memos `0.28.x`
- **AND** the request SHALL NOT include `display_time desc`

### Requirement: Memos 0.28 timestamp requests avoid removed display fields
The system SHALL NOT send removed display-time fields to Memos `0.28.x` create or update memo APIs.

#### Scenario: Create memo omits displayTime
- **WHEN** the app creates a memo on a Memos `0.28.x` server with local display-time metadata available
- **THEN** the remote create request SHALL NOT include a `displayTime` body field

#### Scenario: Update memo omits display_time update mask
- **WHEN** the app updates a memo timestamp on a Memos `0.28.x` server
- **THEN** the remote update request SHALL NOT include `display_time` in `updateMask`
- **AND** the remote update body SHALL NOT include a `displayTime` field

#### Scenario: Local display time remains local
- **WHEN** a local memo has adjusted display-time metadata while syncing with a Memos `0.28.x` server
- **THEN** the system SHALL preserve the local display-time metadata without requiring a removed remote `display_time` field

### Requirement: 0.28 compatibility is version-scoped
The system MUST preserve existing request shapes for Memos `0.21` through `0.27` unless a request is independently changed by a documented compatibility rule.

#### Scenario: Existing compatibility tests still pass
- **WHEN** API compatibility tests run for Memos `0.21` through `0.27`
- **THEN** their expected routes, query parameters, and payload fields MUST remain valid

#### Scenario: 0.28 tests cover removed fields
- **WHEN** API compatibility tests run for Memos `0.28.x`
- **THEN** they MUST fail if a list, create, or update memo request sends removed `display_time` or `displayTime` fields

### Requirement: 0.28 compatibility preserves module boundaries
The system MUST implement Memos `0.28.x` compatibility through data-layer API seams and provider boundaries without adding new reverse dependencies.

#### Scenario: API compatibility logic stays in data layer
- **WHEN** the implementation maps Memos versions to request fields, route behavior, or supported order fields
- **THEN** that mapping MUST live under the Memos API/data layer or an existing lower-layer compatibility seam

#### Scenario: Feature and state layers do not own version rules
- **WHEN** Explore, random review, or remote search needs Memos `0.28.x` compatibility behavior
- **THEN** those call sites MUST consume compatibility decisions from the API/provider seam rather than duplicating raw version checks in widgets

#### Scenario: No new reverse dependencies are introduced
- **WHEN** Memos `0.28.x` compatibility is implemented during `evolve_modularity`
- **THEN** the change MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` imports
