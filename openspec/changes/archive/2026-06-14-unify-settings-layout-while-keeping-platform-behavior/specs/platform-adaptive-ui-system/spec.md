## ADDED Requirements

### Requirement: Settings layout SHALL preserve adaptive behavior while unifying presentation geometry

平台适配 UI 系统 SHALL allow settings pages to keep platform-adaptive behavior while moving reusable settings presentation geometry into settings-owned seams. `Switch`、picker/dialog、route/back behavior 和 text input behavior SHALL remain adaptive, while section spacing、row padding、typography、field block geometry、divider 和 card hierarchy SHALL be controlled by settings UI seams rather than platform default list row geometry.

#### Scenario: Adaptive behavior remains platform-owned

- **WHEN** a migrated settings page renders a toggle、choice picker、confirmation dialog、navigation route、back action 或 editable text field
- **THEN** the behavior SHALL continue to use `PlatformSwitch`, platform picker/dialog/route seams, `PlatformTextField`, or an approved adaptive seam
- **AND** the page SHALL NOT duplicate platform-specific business state or complete platform-specific page trees

#### Scenario: Presentation geometry is settings-owned

- **WHEN** a migrated settings page renders section cards、row titles、row values、descriptions、full-width fields、inline fields 或 dividers
- **THEN** reusable geometry SHALL come from `settings_ui.dart`, settings-owned layout constants, `SettingsSection`, settings row seams, `SettingsFieldBlock`, or an approved settings seam
- **AND** `CupertinoListTile`, Material `ListTile`, or equivalent platform default row geometry SHALL NOT be the primary owner of ordinary settings typography and padding

#### Scenario: Platform visual differences stay below the seam

- **WHEN** the same migrated settings page runs on iPhone and Android
- **THEN** platform-specific controls MAY keep platform-appropriate behavior and interaction details
- **AND** ordinary settings text hierarchy、row spacing、field padding、section inset 和 divider treatment SHALL remain recognizably consistent across both platforms

### Requirement: Settings typography SHALL express a stable hierarchy

The platform adaptive UI system SHALL provide settings-owned typography hierarchy for settings screens so section headings、row labels、values、input values、placeholders 和 descriptions have stable relative priority across supported platforms.

#### Scenario: Settings text hierarchy is consistent

- **WHEN** a migrated settings page renders section header、row title、right-side selected value、input value、placeholder 和 description text
- **THEN** row title text SHALL be visually stronger than right-side selected values and descriptions
- **AND** description text SHALL be visually weaker than row title and selected/input values
- **AND** section header text SHALL be secondary to page title and suitable as a group label rather than a primary heading

#### Scenario: Typography uses existing theme colors

- **WHEN** settings typography renders in light mode or dark mode
- **THEN** foreground colors SHALL resolve from settings tokens, `ThemeData`, `ColorScheme`, or approved design tokens
- **AND** the hierarchy SHALL NOT require new hard-coded hex colors, a new color system, or global theme changes

### Requirement: Settings field geometry SHALL be platform-safe but visually unified

Settings field seams SHALL provide unified input height、content padding、label/helper/error spacing、hint/value styling 和 suffix icon treatment while preserving platform text input behavior.

#### Scenario: Full-width field geometry is unified

- **WHEN** a migrated settings page renders URL、password、API key、path、notes 或 other full-width input through `SettingsFieldBlock`, `SettingsFormFieldRow`, `SettingsMultilineFieldRow`, or an approved seam
- **THEN** label、input surface、helper/error text 和 suffix action SHALL align to the same settings-owned grid
- **AND** input height and padding SHALL be defined by the settings seam rather than page-local widgets

#### Scenario: Inline fallback uses unified field geometry

- **WHEN** an inline settings field falls back to stacked layout due to narrow width、large text scale 或 long label
- **THEN** it SHALL use the same settings-owned field geometry as other full-width fields
- **AND** controller、focusNode、keyboardType、inputFormatters、enabled state 和 callbacks SHALL be preserved

#### Scenario: Platform text input behavior remains available

- **WHEN** a settings field runs on iPhone, Android, desktop, or web
- **THEN** editing behavior, keyboard behavior, focus behavior, obscured input behavior, and platform-safe rendering SHALL continue through `PlatformTextField` or an approved platform input seam
- **AND** unified geometry SHALL NOT force a separate iOS-only or Android-only settings page tree
