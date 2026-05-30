## ADDED Requirements

### Requirement: Platform adaptive UI SHALL choose task surfaces by platform and flow type

平台适配 UI SHALL choose presentation based on both platform and flow type. Task-like flows may use desktop dialogs or panels on macOS, Windows, and Linux, while phone and tablet layouts may keep full-page routes, bottom sheets, or platform-appropriate navigation.

#### Scenario: Task-like flow runs on desktop
- **WHEN** a migrated create, edit, configure, import, reorder, or manage-items flow runs on macOS, Windows, or Linux
- **THEN** the adaptive UI layer SHALL be able to present it as a bounded desktop task surface
- **AND** the feature SHALL NOT need separate Windows-only and macOS-only page trees for the same task content

#### Scenario: Same task-like flow runs on mobile
- **WHEN** the same migrated task-like flow runs on iOS, Android, or narrow mobile layouts
- **THEN** it SHALL keep platform-appropriate mobile presentation such as a page route or sheet
- **AND** desktop task-surface constraints SHALL NOT introduce extra desktop titlebar spacing into mobile layouts

#### Scenario: Feature content stays shared
- **WHEN** a task-like flow receives platform-specific presentation
- **THEN** validation, providers, repositories, models, and task business state SHALL remain shared
- **AND** platform differences SHALL be expressed through adaptive UI seams or feature-owned composition boundaries
