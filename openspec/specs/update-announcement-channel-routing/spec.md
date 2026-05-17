## Purpose

Define startup update announcement routing by app distribution channel so Google Play builds avoid full APK update prompts while full and desktop builds preserve the existing remote announcement flow.
## Requirements
### Requirement: Play startup update announcements are suppressed
The system SHALL suppress full APK startup update prompts for `AppChannel.play` builds on Android while still allowing shared announcement config to be fetched for ordinary notice delivery.

#### Scenario: Play startup may fetch shared announcement config
- **WHEN** a Play-channel Android build finishes loading device preferences and schedules startup announcement delivery
- **THEN** the app may call the remote production announcement config fetch path
- **AND** the fetch decision does not by itself make full APK update prompts eligible

#### Scenario: Play startup does not show full APK update prompt
- **WHEN** a Play-channel Android build is older than the remote Android `latest_version` or a schema v3 full APK update candidate
- **THEN** startup announcement scheduling does not show an update dialog that opens the remote Android APK URL

#### Scenario: Play startup can show ordinary notices
- **WHEN** a Play-channel Android build receives a public ordinary notice candidate that satisfies status, schedule, audience, surface, and dismissal rules
- **THEN** startup announcement scheduling can show that notice without enabling a full APK update prompt

### Requirement: Full startup update announcements are preserved

The system SHALL keep the existing startup update announcement fetch and prompt behavior for `AppChannel.full` builds and non-Android platforms.

#### Scenario: Full startup fetches remote update config

- **WHEN** a full-channel Android build finishes loading device preferences and schedules startup update announcements
- **THEN** the app fetches the remote update config through the existing update config service path

#### Scenario: Full startup can show newer version prompt

- **WHEN** a full-channel Android build has a local version lower than the published remote Android `latest_version`
- **THEN** startup announcement scheduling can show the update dialog using the remote Android download URL

#### Scenario: Desktop startup fetches remain enabled

- **WHEN** a desktop build finishes loading device preferences and schedules startup update announcements
- **THEN** the app fetches the remote update config through the existing update config service path

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

