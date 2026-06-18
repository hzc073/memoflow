## 1. Preferences 枚举 picker 迁移

- [x] 1.1 审核 `PreferencesSettingsScreen` 中所有 `_selectEnum<T>` 调用点，确认覆盖 `AppLanguage`、`AppFontSize`、`AppLineHeight`、`LaunchAction`、`AppThemeMode`。
- [x] 1.2 将旧 `_selectEnum<T>` 实现替换为委托到 `showSettingsSingleChoicePicker<T>` 的轻量 helper，或直接在调用点使用 `showSettingsSingleChoicePicker<T>`。
- [x] 1.3 保留每个枚举设置现有 `values`、`labelFor(...)`、`selected`、`onSelect` 写入路径和取消不写入行为。
- [x] 1.4 保留启动动作现有过滤规则，确保 `LaunchAction.sync` 不出现在用户可选项中。
- [x] 1.5 移除或收敛旧 `_selectEnum<T>` 中 `showPlatformPicker + SettingsSection(header: Text(title))` 的页面私有结构。

## 2. 模块化与边界保护

- [x] 2.1 确认迁移只复用 settings-owned seam，不让 `settings_ui.dart` 读取 `DevicePreferences` provider 或拥有业务写入逻辑。
- [x] 2.2 确认 `platform/widgets/*`、`state`、`application`、`core` 未新增对 `features/settings` 或 Preferences 业务逻辑的反向依赖。
- [x] 2.3 确认本 change 未触碰 `memos_flutter_app/lib/data/api/**` 或 `memos_flutter_app/test/data/api/**`。

## 3. 测试覆盖

- [x] 3.1 在 `preferences_settings_screen_test.dart` 增加或更新 focused test，打开代表性旧枚举项（优先 `行高`）并断言展示统一 single-choice picker 标题和选项。
- [x] 3.2 测试选择一个不同枚举值后，对应 `DevicePreferences` 写入成功且当前值展示更新。
- [x] 3.3 测试启动动作 picker 仍不展示 `LaunchAction.sync`。
- [x] 3.4 如现有测试对旧 `_selectEnum` 结构有假设，更新为统一 settings picker 结构断言。

## 4. 验证

- [x] 4.1 运行 `flutter test test/features/settings/preferences_settings_screen_test.dart --reporter expanded`。
- [x] 4.2 运行 `flutter analyze`。
- [x] 4.3 运行 `openspec validate standardize-settings-enum-pickers --strict`。
