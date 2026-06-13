## MODIFIED Requirements

### Requirement: Settings UI SHALL use semantic settings components

The platform adaptive UI system SHALL provide a settings-owned semantic UI seam so settings screens express settings intent instead of directly owning colors, button styles, platform controls, and repeated card geometry.

#### Scenario: Settings page chrome is rendered

- **WHEN** a migrated settings page renders a title, leading action, body, background, safe area, or desktop width constraint
- **THEN** it SHALL use `SettingsPage`, `PlatformPage`, or an approved settings page seam
- **AND** page-local `Scaffold` and app bar construction SHALL NOT be introduced unless the page is explicitly allowlisted during migration

#### Scenario: Settings rows are rendered

- **WHEN** a migrated settings page renders a navigation row, value row, selectable row, toggle row, or destructive row
- **THEN** it SHALL use a settings semantic row such as `SettingsNavigationRow`, `SettingsValueRow`, `SettingsToggleRow`, or an equivalent seam
- **AND** platform-specific row, grouped-list, and switch behavior SHALL be delegated to shared settings/platform components

#### Scenario: Settings subpage controls are migrated

- **WHEN** a migrated settings subpage renders chips, segmented choices, single-choice rows, multi-choice rows, checkboxes, radios, dropdown-like controls, buttons, progress, validation feedback, or transient choices
- **THEN** those controls SHALL use settings/platform semantic seams
- **AND** migrated files SHALL NOT reintroduce page-local Material-only controls in Apple mobile grouped-list content without an explicit documented exception

#### Scenario: Settings actions are rendered

- **WHEN** a migrated settings page renders save, confirm, continue, cancel, reset, destructive, or secondary actions
- **THEN** it SHALL express the semantic action variant instead of hardcoding button foreground/background colors in the screen

#### Scenario: Settings visual tokens are resolved

- **WHEN** a migrated settings screen needs background, section, card, row, divider, text, icon, active, disabled, primary, secondary, or danger styling
- **THEN** those values SHALL be resolved through the settings UI seam, `ThemeData`, `ColorScheme`, platform widgets, or approved design tokens
- **AND** the feature screen SHOULD NOT directly select raw palette colors except for genuinely page-specific preview/editing UI such as a color picker.
