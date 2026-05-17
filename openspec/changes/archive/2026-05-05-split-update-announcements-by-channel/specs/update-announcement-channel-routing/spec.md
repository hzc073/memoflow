## ADDED Requirements

### Requirement: Play startup update announcements are suppressed

The system SHALL NOT fetch remote startup update announcement config for `AppChannel.play` builds.

#### Scenario: Play startup skips remote update config

- **WHEN** a Play-channel build finishes loading device preferences and schedules startup update announcements
- **THEN** the app does not call the remote update config fetch path for startup update announcements

#### Scenario: Play startup does not show full APK update prompt

- **WHEN** a Play-channel build is older than the remote Android `latest_version`
- **THEN** startup announcement scheduling does not show an update dialog that opens the remote Android APK URL

### Requirement: Full startup update announcements are preserved

The system SHALL keep the existing startup update announcement fetch and prompt behavior for `AppChannel.full` builds.

#### Scenario: Full startup fetches remote update config

- **WHEN** a full-channel build finishes loading device preferences and schedules startup update announcements
- **THEN** the app fetches the remote update config through the existing update config service path

#### Scenario: Full startup can show newer version prompt

- **WHEN** a full-channel build has a local version lower than the published remote Android `latest_version`
- **THEN** startup announcement scheduling can show the update dialog using the remote Android download URL

### Requirement: Non-startup update content remains available

The system SHALL limit this change to startup update announcement routing unless a future spec explicitly changes manual update content surfaces.

#### Scenario: Manual release notes are not blocked by startup routing

- **WHEN** a user opens a manual release-notes surface
- **THEN** startup channel routing does not by itself block that surface from loading update config content

### Requirement: Channel routing remains testable without UI coupling

The system SHALL implement update announcement channel routing through a stable non-UI seam that can be tested without constructing update dialog widgets.

#### Scenario: Routing policy is tested independently

- **WHEN** tests evaluate the routing behavior for `AppChannel.play` and `AppChannel.full`
- **THEN** the expected fetch decision is verified without importing `features/updates` UI into the policy test target
