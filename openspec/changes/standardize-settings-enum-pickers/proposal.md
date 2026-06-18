## Why

偏好设置中的语言、字体大小、行高、启动动作、主题模式等枚举项仍使用旧 `_selectEnum` 弹窗，导致标题、背景和选项 section 分层割裂，和已迁移的 settings single-choice picker 视觉不一致。现在标签识别等新选择器已经走统一 seam，继续保留旧枚举 picker 会让同类设置出现两套交互与视觉标准。

当前架构阶段为 `evolve_modularity`。本 change 触及 settings UI，但不触及 API、数据库协议或跨层业务逻辑；通过复用/收敛到现有 settings/platform picker seam，避免继续在页面内保留重复 transient UI 实现，支持模块化清单第 10 项“触碰区域保持不变或更好”。

## What Changes

- 将 `PreferencesSettingsScreen` 中旧 `_selectEnum` 使用点统一迁移到现有 `showSettingsSingleChoicePicker` 或等价 settings single-choice seam。
- 覆盖语言、字体大小、行高、启动动作、主题模式等当前 `_selectEnum` 枚举设置。
- 保持现有偏好写入、选项过滤、当前值显示、多语言 label 和业务行为不变。
- 删除或收敛页面私有的旧枚举 picker 实现，避免 `SettingsSection(header: Text(title))` 被直接塞进通用 dialog/sheet 造成视觉割裂。
- 增加 focused widget tests，覆盖至少一个旧问题样式代表项，并验证用户选择仍会调用原有 preference mutation path。
- 不引入新的 API、数据模型、数据库迁移、商业/付费逻辑或跨层依赖。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `settings-platform-controls`: 明确 Preferences 中枚举型单选设置 MUST 使用统一 settings/platform single-choice picker seam，避免旧 `_selectEnum` 式分层弹窗继续存在。

## Impact

- 主要影响代码：
  - `memos_flutter_app/lib/features/settings/preferences_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/settings_ui.dart`（仅当需要轻量扩展通用 single-choice seam 时）
  - `memos_flutter_app/test/features/settings/preferences_settings_screen_test.dart`
  - 可能涉及已有 settings UI component tests
- 不影响：
  - `memos_flutter_app/lib/data/api/**`
  - `memos_flutter_app/test/data/api/**`
  - 数据库 schema、同步协议、登录流程、Memos API adapter
- 验证重点：
  - 旧枚举入口不再展示割裂的 header/section 弹窗样式。
  - 选择语言、字体大小、行高、启动动作、主题模式后仍写入对应 `DevicePreferences`。
  - `flutter analyze` 和 focused settings tests 通过。
