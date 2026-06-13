## ADDED Requirements

### Requirement: Settings semantic controls SHALL be Apple-mobile safe

设置页通用控件 SHALL expose settings intent through semantic settings/platform seams and SHALL render inside iPhone/iPadOS `SettingsPage` and `SettingsSection` without depending on accidental `Material` ancestors.

#### Scenario: Choice-like setting renders on iPhone

- **WHEN** a setting uses a chip-like, segmented, or small option group control inside `SettingsSection`
- **THEN** the control SHALL render without `No Material widget found` or equivalent Flutter framework errors on iPhone/iPadOS
- **AND** selected state SHALL remain visible
- **AND** selecting an option SHALL invoke the existing `onChanged` path

#### Scenario: Single-choice setting uses semantic control

- **WHEN** a setting asks users to choose one value from a small or medium option set
- **THEN** the page SHALL use a settings/platform single-choice seam such as a choice row, option group, or platform picker
- **AND** the page SHOULD NOT directly embed `ChoiceChip`, `FilterChip`, `RadioListTile`, `DropdownButton`, or equivalent Material-only selection widgets in Apple mobile grouped-list content

#### Scenario: Multi-choice setting uses semantic control

- **WHEN** a setting asks users to choose multiple values
- **THEN** the page SHALL use a settings/platform multi-choice seam
- **AND** Apple mobile presentation SHALL use Cupertino-safe rows, checkmarks, action sheet, picker, or equivalent behavior rather than `CheckboxListTile` inside `CupertinoListSection`

### Requirement: Settings actions SHALL use platform-safe action seams

保存、取消、确认、删除、测试、导入、导出、继续等 settings actions SHALL be expressed through semantic action variants and SHALL render through platform-safe widgets.

#### Scenario: Primary action renders on iPhone

- **WHEN** a settings screen or settings dialog renders a primary action on iPhone/iPadOS
- **THEN** it SHALL render through `SettingsAction`, `PlatformPrimaryAction`, `showPlatformAlertDialog`, or an equivalent Apple-safe seam
- **AND** it SHALL NOT require an external `Material` ancestor to build

#### Scenario: Destructive action preserves semantics

- **WHEN** a settings flow asks users to delete, reset, clear, overwrite, or discard data
- **THEN** the action SHALL expose destructive semantics to the platform seam
- **AND** Apple mobile presentation SHALL show destructive styling or placement appropriate to the platform

### Requirement: Settings transient UI SHALL use platform seams

设置页确认弹窗、选择弹窗、action sheet、错误提示和轻量反馈 SHALL use platform dialog, picker, action sheet, or feedback seams rather than page-local Material-only transient UI.

#### Scenario: Confirmation dialog is platform-safe

- **WHEN** a settings screen asks for confirmation on iPhone/iPadOS
- **THEN** the confirmation SHALL use `showPlatformAlertDialog`, `showPlatformDialog`, or an equivalent seam
- **AND** dialog content and actions SHALL render without Material-only ancestor errors

#### Scenario: Lightweight feedback is platform-safe

- **WHEN** a settings screen shows validation, success, or failure feedback on iPhone/iPadOS
- **THEN** feedback SHALL not require a `ScaffoldMessenger` unless the current page is guaranteed to provide a `Scaffold`
- **AND** the feedback behavior SHALL be testable through a platform-safe seam or explicit inline state

### Requirement: Settings platform controls SHALL preserve architecture boundaries

Settings platform controls SHALL remain UI seams and MUST NOT own feature business state, repositories, API adapters, database schema, WebDAV protocol behavior, or private commercial capability logic.

#### Scenario: Platform/control files preserve dependency direction

- **WHEN** settings/platform controls are added or changed
- **THEN** files under `platform/` MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`
- **AND** settings-owned controls in `features/settings/settings_ui.dart` MUST receive labels, values, options, and callbacks from callers rather than reading unrelated providers directly

#### Scenario: Public repository remains commercial-free

- **WHEN** settings platform controls are implemented
- **THEN** they MUST NOT add subscription, billing, entitlement, receipt, paywall, StoreKit, product ID, price, private overlay, or `AccessDecision.source` business branching logic

#### Scenario: Focused tests cover Apple mobile controls

- **WHEN** this capability is implemented
- **THEN** focused widget tests SHALL cover core settings choice, multi-choice, action, dialog, and feedback controls in `TargetPlatform.iOS`
- **AND** those tests SHALL assert no Flutter framework exception is thrown
