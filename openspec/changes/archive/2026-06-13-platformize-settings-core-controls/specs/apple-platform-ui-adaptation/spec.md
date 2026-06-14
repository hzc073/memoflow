## MODIFIED Requirements

### Requirement: Platform grouped settings and form controls

The system SHALL provide Apple-appropriate grouped list and form controls for settings and configuration pages.

#### Scenario: Settings grouped list

- **WHEN** a migrated settings or configuration page displays groups of navigable rows, toggles, value rows, text input rows, or destructive rows
- **THEN** it MUST use `PlatformGroupedList`, `PlatformListTile`, `SettingsSection`, `PlatformListSection`, or equivalent abstractions that can render Apple inset grouped lists on Apple platforms and preserve existing style elsewhere

#### Scenario: Adaptive form controls

- **WHEN** a migrated page displays switch, checkbox, radio, slider, progress, text field, search field, segmented control, chip-like choice, single-choice list, multi-choice list, or picker-backed choice behavior
- **THEN** it MUST use platform/settings control wrappers or a documented platform adapter entry point rather than scattering direct `*.adaptive`, Material-only widgets, or platform branches through the page

#### Scenario: Apple mobile settings controls do not require accidental Material ancestors

- **WHEN** settings controls are rendered inside `CupertinoPageScaffold`, `CupertinoListSection`, `CupertinoListTile`, `SettingsPage`, or `SettingsSection` on iPhone/iPadOS
- **THEN** the controls SHALL build without `No Material widget found` or equivalent framework errors
- **AND** the implementation SHOULD NOT solve this by globally wrapping Apple grouped-list content in `Material` unless a design artifact explicitly approves the exception

#### Scenario: Settings pilot

- **WHEN** the first Apple UI migration batch is implemented
- **THEN** `SettingsScreen` and `PreferencesSettingsScreen` MUST be treated as pilot pages for grouped list, picker, dialog, switch, route, and page chrome behavior
