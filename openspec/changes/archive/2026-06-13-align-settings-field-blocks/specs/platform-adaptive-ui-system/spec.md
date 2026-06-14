## ADDED Requirements

### Requirement: Settings form field blocks SHALL align with settings section geometry

The platform adaptive UI system SHALL provide settings-owned full-width form field blocks whose label、input surface、helper text、error text 和 suffix action 在同一视觉网格内对齐。完整文本、密码、密钥、URL、路径和多行输入 SHALL NOT depend on a grouped-list row subtitle as the primary layout surface when that causes filled input backgrounds to drift from the section geometry.

#### Scenario: Full-width field renders as aligned block

- **WHEN** a migrated settings page renders a URL、路径、password、API Key、Security Key、access token 或其他长/敏感文本字段
- **THEN** the field SHALL render through `SettingsFormFieldRow`, `SettingsFieldBlock`, `SettingsMultilineFieldRow`, or an equivalent settings-owned field block seam
- **AND** label、filled input surface、helper text 和 error text SHALL share consistent horizontal padding inside the settings section
- **AND** the filled input background SHALL NOT visually touch or overflow the section border because of nested list row subtitle padding

#### Scenario: Multiline field uses same field block grid

- **WHEN** a migrated settings page renders AI 个人资料、反馈备注、通知正文或其他多行文本
- **THEN** the multiline input SHALL use the same settings-owned field block geometry
- **AND** minLines、maxLines、hint、helper text、error text、enabled state 和 callbacks SHALL remain expressible through the seam

#### Scenario: Inline fallback uses aligned full-width field

- **WHEN** an inline text or numeric settings field switches to a stacked fallback because of narrow width、large text scale 或 long label
- **THEN** the fallback SHALL use the aligned full-width field block seam
- **AND** it SHALL preserve the original controller、keyboardType、inputFormatters、onChanged、onSubmitted 和 onEditingComplete behavior

### Requirement: Settings field blocks SHALL use existing theme and settings tokens

Settings field block visuals SHALL use existing settings tokens, `ThemeData`, `ColorScheme`, platform widgets, or approved design tokens for fill、border、focused border、label、hint、helper、error、icon 和 disabled state. They SHALL NOT introduce a new color system or require global theme changes.

#### Scenario: Field block colors are theme-derived

- **WHEN** a field block renders in light mode or dark mode
- **THEN** field fill、border、focused border、hint text、label text、helper text、error text 和 icon colors SHALL come from existing theme/settings/platform seams
- **AND** the field block SHALL NOT hard-code new hex colors for ordinary settings field surfaces

#### Scenario: Focus and disabled states remain platform-safe

- **WHEN** a field block is focused, disabled, or has a suffix action
- **THEN** focus border、opacity、icon color 和 input behavior SHALL be expressed through the field seam and platform text field
- **AND** feature pages SHALL NOT need local Material/Cupertino wrappers to make the field render safely

### Requirement: Settings field block migration SHALL be guarded

The settings UI migration SHALL include guardrails that prevent migrated settings files from reintroducing page-local field surfaces or subtitle-based full-width form inputs for ordinary settings fields.

#### Scenario: Drift guardrail catches local field wrappers

- **WHEN** `settings_ui_drift_guardrail_test.dart` or equivalent architecture/style guardrail runs
- **THEN** migrated target files SHALL fail or require an explicit documented exception if they add page-local `PlatformTextField` + `InputBorder.none`, raw `TextField`, page-local field card wrappers, or direct raw palette field surface styling for ordinary settings forms
- **AND** shared reusable field presentation SHALL stay in `settings_ui.dart` or an approved platform/settings seam

#### Scenario: Boundary direction is preserved

- **WHEN** settings field block seam code is added or changed
- **THEN** `platform/widgets/*`, `state`, `application`, `core`, and `data` layers SHALL NOT import `features/settings` or other feature UI files
- **AND** feature pages SHALL continue to pass only presentation inputs such as label、controller、hint、suffix action 和 callbacks into the settings seam
