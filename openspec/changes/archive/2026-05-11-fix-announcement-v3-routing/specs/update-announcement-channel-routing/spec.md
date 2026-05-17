## MODIFIED Requirements

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
