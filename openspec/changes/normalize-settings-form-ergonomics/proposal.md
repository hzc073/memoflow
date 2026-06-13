## Why

`platformize-settings-subpages` 已经解决了设置子页面在 Apple mobile 上直接使用 Material-only 控件导致崩溃的问题，但人工复核发现部分页面仍然“看起来正常、用起来奇怪”：WebDAV 用户名输入触区很小、根路径长值溢出、提醒页卡片和按钮像另一套 UI、系统日期/时间 picker 与设置页不协调。

当前项目处于 `evolve_modularity` 阶段，本 change 触碰 `features/settings` 和从设置入口进入的 `features/reminders` 视觉热点，应通过新增 settings-owned form ergonomics seam 和 guardrail，让字段排版、输入触区、长值展示、picker presentation 收敛到共享设置语义，而不是继续在页面内复制局部布局。

## What Changes

- 新增 settings form ergonomics 规则，把字段按语义分为短文本右侧输入、短数字右侧输入、长文本完整输入、密钥/密码输入、多行文本、长值展示、日期/时间 picker。
- 在 settings UI seam 中补齐或扩展表单控件能力，例如 `SettingsInlineTextFieldRow`、`SettingsNumericInlineFieldRow`、`SettingsFormFieldRow`、`SettingsMultilineFieldRow`、settings date/time picker seam，具体命名可在实现时按现有风格微调。
- 将 WebDAV 连接和备份设置纳入第一批修正：用户名适合右侧 inline 输入，服务器地址/密码/根路径使用完整输入，保留版本数使用短数字输入，长路径和 URL 必须限宽省略。
- 将 AI proxy、image bed、location key、Memoflow Bridge、shortcut/server 数字输入等设置场景纳入后续字段排版整理。
- 将从设置入口进入的 reminder 设置、memo reminder editor、自定义通知页面纳入 settings-adjacent ergonomics，收敛自定义 22px 阴影卡片、裸按钮、raw date/time picker 和无边框小触区输入。
- 增加 focused widget tests 和 guardrail，防止目标页面重新出现裸 `PlatformTextField` + `InputBorder.none` 小触区、未约束长值、raw `showDatePicker` / `showTimePicker`、页面级 Material button styling 或不一致的自定义设置卡片。
- 不改变 WebDAV protocol、sync/backup semantics、reminder scheduling semantics、AI proxy behavior、image bed behavior、API adapters、database schema 或商业/private boundary。

## Capabilities

### New Capabilities

- `settings-form-ergonomics`: 定义设置页和设置入口子页面的字段排版、输入触区、长值展示、picker presentation、提醒配置表面一致性要求。

### Modified Capabilities

本 change 不直接修改既有 capability requirements；`settings-form-ergonomics` 作为独立 capability 补充“平台安全之后的表单可用性标准”。实现应复用并扩展现有 settings/platform semantic seams。

## Impact

- 主要影响 `memos_flutter_app/lib/features/settings/settings_ui.dart` 中的 settings semantic controls。
- 可能影响 `memos_flutter_app/lib/platform/widgets/platform_controls.dart`、`platform_picker.dart` 或相关 platform picker/dialog seam，但不得引入 `features/*`、`state/*`、`application/*`、`data/*` 反向依赖。
- 首批页面建议覆盖：
  - `memos_flutter_app/lib/features/settings/webdav_sync_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_proxy_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/image_bed_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/location_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/memoflow_bridge_screen.dart`
  - `memos_flutter_app/lib/features/settings/shortcut_editor_screen.dart`
  - `memos_flutter_app/lib/features/settings/server_settings_screen.dart`
  - `memos_flutter_app/lib/features/reminders/reminder_settings_screen.dart`
  - `memos_flutter_app/lib/features/reminders/memo_reminder_editor_screen.dart`
  - `memos_flutter_app/lib/features/reminders/custom_notification_screen.dart`
- 测试影响集中在 settings UI semantic component tests、targeted page smoke tests、architecture/settings UI drift guardrail。
