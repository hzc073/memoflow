## ADDED Requirements

### Requirement: Toolbar location settings prompt SHALL route through migrated settings surface

当用户从 memo compose 工具栏触发定位且定位 provider 未 ready 时，系统 SHALL 通过 settings/navigation seam 打开已迁移的定位设置 surface，而不是从 location picker 直接构造旧承载路由。

#### Scenario: Mobile toolbar prompt opens migrated location settings page

- **WHEN** 用户从 note input、memo editor 或 inline compose 工具栏点击定位
- **AND** location provider requirements 校验失败
- **AND** 用户在提示弹窗中选择打开设置
- **THEN** 系统 SHALL 使用 platform route 或 equivalent settings navigation seam 打开 `LocationSettingsScreen`
- **AND** `LocationSettingsScreen` SHALL 继续通过 `SettingsPage`、`SettingsSection`、`SettingsToggleRow`、`SettingsMenuRow`、`SettingsInputRow` 或 equivalent settings seams 渲染
- **AND** 系统 MUST NOT 使用 location picker 内部硬编码的裸 `MaterialPageRoute` 作为该入口的主路径

#### Scenario: Location picker delegates settings navigation

- **WHEN** `showLocationPickerSheetOrDialog()` 发现 location provider requirements 不 ready
- **THEN** 它 SHALL 显示现有 provider readiness prompt
- **AND** prompt 的打开设置动作 SHALL 调用传入的 opener callback、typedef 或 equivalent navigation seam
- **AND** `features/location_picker/show_location_picker.dart` MUST NOT import `features/settings/location_settings_screen.dart`
- **AND** location provider validation、settings reload、picker sheet/dialog presentation、map controller lifecycle 和 selected `MemoLocation` return behavior SHALL remain unchanged

#### Scenario: Toolbar location entry remains shared across compose surfaces

- **WHEN** note input、memo editor、inline compose 或 desktop quick input 复用 `showLocationPickerSheetOrDialog()`
- **THEN** 每个 runtime call site SHALL provide the same location settings opener behavior or an equivalent shared seam
- **AND** no compose surface SHALL reintroduce its own direct duplicate `LocationSettingsScreen` route construction for the provider-not-ready prompt

### Requirement: Toolbar location settings routing SHALL preserve architecture boundaries

工具栏定位设置路由 SHALL 在 `evolve_modularity` phase 下减少 picker 与 settings UI 的直接耦合，并 MUST NOT 引入新的 `state -> features`、`application -> features` 或 `core -> state|application|features` 依赖。

#### Scenario: Picker no longer owns settings widget construction

- **WHEN** toolbar location settings routing is implemented
- **THEN** location picker code SHALL depend on a stable opener contract rather than constructing settings widgets directly
- **AND** settings target/fallback widget construction SHALL remain in settings UI composition, caller composition, or an approved navigation seam
- **AND** implementation SHALL include focused tests or guardrails that fail if the picker reintroduces direct settings screen imports

#### Scenario: Public/private boundary remains unchanged

- **WHEN** toolbar location settings routing is implemented
- **THEN** public runtime code SHALL NOT add subscription、billing、entitlement、paywall、StoreKit 或 other commercial behavior
- **AND** `LocationSettings`, location repositories/providers/adapters, API files, WebDAV config transfer, private hooks, and public shell paid-feature state SHALL remain unchanged
