## ADDED Requirements

### Requirement: Platform adaptive settings pages SHALL separate shared desktop intent from platform-specific rows
The platform adaptive UI system SHALL require migrated settings pages to express shared desktop intent and platform-specific rows through adaptive settings seams rather than Windows-only page trees or scattered platform branches.

#### Scenario: Migrated settings page contains shared and platform-specific desktop rows
- **WHEN** a migrated settings page contains settings that apply to multiple desktop platforms and settings that apply to only one desktop platform
- **THEN** the page SHALL present the shared settings through a shared desktop section
- **AND** the page SHALL present platform-specific settings through platform-specific sections or an equivalent capability-gated composition
- **AND** the page SHALL NOT name the entire settings surface after a single platform unless all rows are exclusive to that platform

#### Scenario: Desktop settings platform support is capability-gated
- **WHEN** a desktop settings row is rendered for Windows, macOS, or Linux
- **THEN** row visibility SHALL be based on the platform target and the row's supported capability
- **AND** unsupported platforms SHALL receive an explicit fallback or no entry rather than a misleading platform-specific control

#### Scenario: Settings migration keeps adaptive UI seam ownership
- **WHEN** a settings page is migrated as part of platform adaptive UI work
- **THEN** scaffold, list/form row presentation, switch styling, desktop width, and platform visual behavior SHALL be provided by `settings_ui.dart`, `platform/` widgets, `DesktopShellHost`, or equivalent adaptive seams
- **AND** the migrated page SHALL NOT duplicate a complete platform-specific settings page tree

#### Scenario: Settings hotspot improvement is guarded during evolve_modularity
- **GIVEN** the architecture phase is `evolve_modularity`
- **WHEN** settings platform adaptive work touches a migrated settings page
- **THEN** the change SHALL include a touched-area improvement such as reducing page-local platform branching, moving standard row visuals into settings seams, or tightening a settings UI guardrail
