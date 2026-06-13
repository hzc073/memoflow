## ADDED Requirements

### Requirement: Settings enum selection SHALL use platform picker seams

迁移后的设置页在呈现 enum、single-option 或小集合配置选择时 SHALL 通过 settings semantic row 和 platform picker seam 表达选择意图，而不是在设置行内直接嵌入对所有平台都相同的 Material-only dropdown。

#### Scenario: Settings menu row renders on Apple mobile

- **WHEN** `SettingsMenuRow<T>` 在 iPhone 或 iPadOS 的设置页面中渲染
- **THEN** row SHALL render without `No Material widget found` or equivalent Flutter framework errors
- **AND** row SHALL NOT require an accidental `Material` ancestor inside `CupertinoListTile` content to build successfully

#### Scenario: Settings menu row opens platform picker

- **WHEN** 用户点击 enabled `SettingsMenuRow<T>`
- **THEN** 系统 SHALL present available values through `showPlatformPicker` or an equivalent platform picker seam
- **AND** selecting an option SHALL invoke the existing `onChanged` path with the selected value
- **AND** the displayed selected label SHALL be derived from the existing `labelFor` mapping

#### Scenario: Disabled settings menu row remains inert

- **WHEN** `SettingsMenuRow<T>` is disabled
- **THEN** it SHALL keep the disabled visual treatment
- **AND** tapping it SHALL NOT open the picker or call `onChanged`

#### Scenario: Settings selection remains boundary-safe

- **WHEN** settings enum picker behavior is implemented
- **THEN** `platform/` picker files MUST NOT import `features/*`, `state/*`, `application/*`, or `data/*`
- **AND** the implementation MUST NOT introduce subscription, billing, entitlement, receipt, paywall, StoreKit, private overlay, or paid-feature branching logic
