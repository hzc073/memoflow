## MODIFIED Requirements

### Requirement: Play startup update announcements are suppressed
The system SHALL NOT show full APK startup update prompts for `AppChannel.play` builds on Android. When update and notice delivery share a remote config source, this suppression SHALL be applied to update prompt eligibility without blocking ordinary non-update notice candidates.

#### Scenario: Play startup filters remote APK update candidates
- **WHEN** a Play-channel Android build finishes loading device preferences and schedules startup announcement delivery
- **THEN** the app does not surface a full APK update prompt from the remote update config path
- **AND** APK-style update candidates are treated as ineligible for startup update presentation

#### Scenario: Play startup does not show full APK update prompt
- **WHEN** a Play-channel Android build is older than the remote Android `latest_version`
- **THEN** startup announcement scheduling does not show an update dialog that opens the remote Android APK URL

#### Scenario: Play startup can still evaluate ordinary notices
- **WHEN** a Play-channel Android build evaluates remote announcement delivery config that contains ordinary non-update notices
- **THEN** the update prompt suppression policy does not by itself make those ordinary notice candidates ineligible

### Requirement: Non-startup update content remains available
The system SHALL limit channel routing to startup update prompt routing unless a future spec explicitly changes manual update content surfaces or ordinary notice delivery surfaces.

#### Scenario: Manual release notes are not blocked by startup routing
- **WHEN** a user opens a manual release-notes surface
- **THEN** startup channel routing does not by itself block that surface from loading update config content

#### Scenario: Ordinary notice delivery is not blocked by update prompt routing
- **WHEN** a build is subject to startup update prompt suppression
- **THEN** the suppression rule does not by itself block ordinary non-update notice candidates that satisfy announcement delivery eligibility rules

### Requirement: Channel routing remains testable without UI coupling
The system SHALL implement update announcement channel routing through a stable non-UI seam that can be tested without constructing update dialog widgets.

#### Scenario: Routing policy is tested independently
- **WHEN** tests evaluate the routing behavior for `AppChannel.play` and `AppChannel.full`
- **THEN** the expected update prompt eligibility decision is verified without importing `features/updates` UI into the policy test target
