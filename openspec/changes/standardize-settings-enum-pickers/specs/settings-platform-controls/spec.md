## ADDED Requirements

### Requirement: Preferences enum pickers SHALL use unified settings single-choice presentation

`PreferencesSettingsScreen` 中枚举型单选设置 SHALL 使用 settings/platform single-choice seam，例如 `showSettingsSingleChoicePicker` 或等价封装；页面 SHALL NOT 继续使用私有 `_selectEnum` 式 `showPlatformPicker + SettingsSection(header: Text(title))` 结构来展示语言、字体大小、行高、启动动作、主题模式等选项。

#### Scenario: Legacy enum setting opens unified picker

- **WHEN** 用户在 Preferences 中打开语言、字体大小、行高、启动动作或主题模式任一枚举设置
- **THEN** 应用 SHALL 展示统一 settings single-choice picker
- **AND** 标题 SHALL 作为 picker 内容标题呈现，而不是作为 `SettingsSection.header` 漂浮在选项 section 外部
- **AND** 选项 SHALL 使用 settings single-choice row/selection mark 语义呈现

#### Scenario: Enum selection preserves preference mutation

- **WHEN** 用户在迁移后的枚举 picker 中选择一个不同选项
- **THEN** 应用 SHALL 调用该设置原有的 preference mutation callback
- **AND** 当前值展示 SHALL 更新为该选项现有 `labelFor(...)` 文案
- **AND** 取消 picker SHALL NOT 写入新值

#### Scenario: Launch action filtering is preserved

- **WHEN** 用户打开启动动作 picker
- **THEN** 可选项 SHALL 保持现有过滤规则，不展示 `LaunchAction.sync`
- **AND** 选择 `LaunchAction.none`、`LaunchAction.quickInput`、`LaunchAction.dailyReview` 或 `LaunchAction.explore` 的现有行为 SHALL 不变

#### Scenario: Settings seam owns presentation only

- **WHEN** Preferences 枚举 picker 迁移完成
- **THEN** `settings_ui.dart` 或 settings/platform picker seam SHALL 只接收 labels、values、options 和 callbacks
- **AND** 它 SHALL NOT 读取 `DevicePreferences` provider、写入 repositories、修改启动动作业务语义或引入 API/数据库依赖
