## 1. 前置与排版语义

- [x] 1.1 复核 `SettingsInputRow`、`SettingsDialogTextField`、`SettingsMenuRow`、`SettingsValueRow`、`SettingsNavigationRow`、`PlatformTextField` 当前行为，确认不会直接大改高复用 row 导致大范围视觉回归。
- [x] 1.2 在 `settings_ui.dart` 或相邻 settings seam 中建立字段排版语义，覆盖短文本 inline、短数字 inline、完整表单输入、多行输入、长值展示。
- [x] 1.3 为 inline 输入定义窄屏、长 label、大字体 fallback 规则，确保可降级为上下布局。
- [x] 1.4 确认本 change 不触碰 API adapters、WebDAV protocol、database schema、sync/backup archive format、reminder scheduling semantics、private hooks 或商业逻辑。

## 2. Shared Form Seams

- [x] 2.1 新增或扩展短文本 inline 输入 seam，用于用户名、Host、Pair code、快捷方式名称等字段。
- [x] 2.2 新增或扩展短数字 inline 输入 seam，用于 Port、保留版本数、过去天数、策略 ID、数字单位等字段。
- [x] 2.3 新增或扩展完整表单输入 seam，用于 URL、路径、password、API Key、Security Key 等长文本或敏感字段。
- [x] 2.4 新增或扩展多行输入 seam，用于 AI 个人资料、反馈备注、通知正文等字段。
- [x] 2.5 新增或扩展长值展示 seam，确保 trailing value 有 maxWidth、ellipsis，并可与 chevron/copy/delete action 共存。
- [x] 2.6 新增或封装 settings date/time picker seam，避免目标页面直接使用 raw `showDatePicker` / `showTimePicker`。
- [x] 2.7 为上述 seams 添加 focused widget tests，覆盖 Apple mobile 分支、触区/padding、长值约束和基本交互回调。

## 3. WebDAV 字段排版迁移

- [x] 3.1 将 `WebDavSyncScreen` 服务器地址迁移到完整长文本输入排版，保留 URL keyboard 和 editing complete normalization。
- [x] 3.2 将 WebDAV 用户名迁移到右侧 inline 短文本输入，保留 credential mismatch validation 行为。
- [x] 3.3 将 WebDAV 密码迁移到 secure/full-width 输入排版，保留显示/隐藏 action 和密码变更回调。
- [x] 3.4 将 WebDAV 认证方式、备份方式、备份计划等选择项确认走 settings value/picker seam。
- [x] 3.5 将 WebDAV 根路径迁移到完整长文本输入排版，保留 `normalizeWebDavRootPath` 行为。
- [x] 3.6 将 WebDAV 保留版本数迁移到短数字 inline 输入排版。
- [x] 3.7 替换 WebDAV 未约束 `_SelectRow` 长值展示，确保路径、URL、状态值不会撑破容器。
- [x] 3.8 运行 WebDAV focused tests，确认 auth、root path、backup schedule、encryption、restore/sync/backup UI 行为未回归。

## 4. 其它设置字段排版迁移

- [x] 4.1 迁移 `AiProxySettingsScreen`：protocol 走 picker row，Host/username 走 inline text，Port 走 numeric inline，password/test URL 走完整输入。
- [x] 4.2 迁移 `ImageBedSettingsScreen`：API URL 走完整输入，email 走 inline text，password 走 secure/full-width，strategy ID 走 numeric inline。
- [x] 4.3 迁移 `LocationSettingsScreen` provider key 字段，API Key / Security Key / AK 使用完整 key/secret 输入排版。
- [x] 4.4 迁移 `MemoflowBridgeScreen` Host、Port、Pair code 字段到对应 inline text / numeric inline 排版。
- [x] 4.5 迁移 `ShortcutEditorScreen` 名称、过去天数字段，并确认日期范围 action 与 settings picker/action seam 一致。
- [x] 4.6 迁移 `ServerSettingsScreen` 数字单位字段到 numeric inline 排版。
- [x] 4.7 复核 `AiUserProfileScreen`、`ExportLogsScreen` 等多行输入，改用多行表单 seam 或记录明确例外。

## 5. Reminder Settings-Adjacent 迁移

- [x] 5.1 将 `ReminderSettingsScreen` 的 `_Group` / `_SelectRow` / `_ActionRow` / `_ToggleRow` 收敛到 settings row/action/toggle seam。
- [x] 5.2 将 `ReminderSettingsScreen` 通知标题、通知正文、铃声、测试提醒、勿扰时间等字段改为合适的 value row、description preview、settings action 或 picker seam。
- [x] 5.3 将 `MemoReminderEditorScreen` raw `showDatePicker` / `showTimePicker` 迁移到 settings/platform date/time picker seam。
- [x] 5.4 将 `MemoReminderEditorScreen` 的添加时间、时间列表、删除时间动作迁移到 settings action/value row 语义，保留 reminder mode 和 validation。
- [x] 5.5 将 `CustomNotificationScreen` 标题输入、正文输入迁移到 settings form/multiline field，保留保存返回值语义。
- [x] 5.6 收敛 `CustomNotificationScreen` preview card 的 radius、shadow、typography 到 settings tokens，保留通知预览领域语义。

## 6. Guardrails 与测试

- [x] 6.1 扩展 `settings_ui_drift_guardrail_test.dart`，覆盖目标文件中的裸 `PlatformTextField` + `InputBorder.none`、未约束 trailing 长值、raw `showDatePicker`、raw `showTimePicker`、页面级 `OutlinedButton.styleFrom` 和私有 22px shadow settings cards。
- [x] 6.2 为 WebDAV 表单字段添加或更新 iOS focused tests，覆盖用户名 inline、根路径完整输入、密码 suffix action、长值不溢出。
- [x] 6.3 为 reminder settings-adjacent 页面添加或更新 focused tests，覆盖 date/time picker seam、通知字段、测试提醒 action。
- [x] 6.4 为 AI proxy、image bed、Memoflow Bridge、shortcut/server 数字字段添加必要的 smoke/focused tests 或更新既有测试断言。
- [x] 6.5 确认 `platform/widgets/*`、`state`、`application`、`core` 没有新增到 `features/settings` 或 `features/reminders` 的反向依赖。

## 7. 验证与 Diff 检查

- [x] 7.1 从 `memos_flutter_app` 运行相关 focused tests，例如 settings semantic components、WebDAV、reminder、AI proxy/image bed/shortcut/server 相关测试。
- [x] 7.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 7.3 按风险运行 `flutter test` 或用户认可的测试子集。
- [x] 7.4 运行 `git diff --check`。
- [x] 7.5 检查 diff，确认未触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api` 或 WebDAV protocol/service behavior。
- [x] 7.6 检查 diff，确认未加入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
- [x] 7.7 更新本 change 的 design/spec/tasks 备注，记录完成、延期和明确例外项。

## 完成备注

- 已新增 settings form ergonomics seam，并迁移 WebDAV、AI proxy、image bed、location key、Memoflow Bridge、shortcut、server、AI profile、export logs 和 reminder settings-adjacent 页面。
- Reminder 相关页面保留原 provider/mutation/scheduler 语义，仅替换设置入口的表单、列表、动作和 picker 呈现。
- 验证已覆盖 focused tests、WebDAV flow、`flutter analyze`、完整 `flutter test`、`git diff --check`、API/商业逻辑 diff 检查。
