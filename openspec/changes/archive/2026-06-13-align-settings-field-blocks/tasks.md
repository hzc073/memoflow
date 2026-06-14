## 1. 边界确认

- [x] 1.1 阅读 `proposal.md`、`design.md`、`specs/platform-adaptive-ui-system/spec.md` 和 `specs/settings-subpage-platformization/spec.md`，确认本 change 只覆盖 settings field block 对齐和相关守护。
- [x] 1.2 复查 `memos_flutter_app/lib/features/settings/settings_ui.dart` 中 `SettingsFormFieldRow`、`SettingsMultilineFieldRow`、`SettingsInlineTextFieldRow`、`SettingsNumericInlineFieldRow`、`SettingsFieldBlock` 和 `_SettingsTextField` 的当前参数覆盖。
- [x] 1.3 扫描目标页面中 `SettingsFormFieldRow`、`SettingsMultilineFieldRow`、`SettingsInlineTextFieldRow` 的使用点，确认高感知字段范围包括 AI proxy、image bed、location provider key、AI user profile、export logs、custom notification。
- [x] 1.4 确认不编辑 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、WebDAV service/repository/model、数据库 schema、持久化 key、private hooks、商业/paid-feature 逻辑。
- [x] 1.5 确认不修改全局 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或主题 token 文件。

## 2. Settings field seam

- [x] 2.1 在 `settings_ui.dart` 中让完整宽度字段统一走 `SettingsFieldBlock` 或等价 field block 实现，保留 `SettingsFormFieldRow` 的 public constructor 和现有参数语义。
- [x] 2.2 让 `SettingsMultilineFieldRow` 复用同一 field block 网格，并保留 `minLines`、`maxLines`、`maxLength`、`hint`、`helperText`、`errorText`、`enabled` 和 callbacks。
- [x] 2.3 让 `SettingsInlineTextFieldRow` 在窄屏、大字体或长 label fallback 到上下布局时使用对齐后的完整 field block，而不是 subtitle-based form row。
- [x] 2.4 确认 `_SettingsTextField` 的 fill、border、focused border、hint、label、helper/error 和 suffix icon 颜色继续来自 `settingsPageTokens(context)` / `Theme.of(context).colorScheme`。
- [x] 2.5 根据 desktop/mobile 表现调整 field block padding、最小高度或密度，但不新增硬编码主题色或全局主题配置。

## 3. 页面迁移

- [x] 3.1 迁移或确认 `AiProxySettingsScreen` 的 password 和 test URL 使用统一 full-width field block，保留 protocol、host、port、username、test/save 行为。
- [x] 3.2 迁移或确认 `ImageBedSettingsScreen` 的 API URL 和 password 使用统一 full-width field block，保留 base URL normalization、email、strategy ID 和 provider 写入逻辑。
- [x] 3.3 迁移或确认 `LocationSettingsScreen` 的 AMap/Baidu/Google provider key 字段使用统一 full-width field block，保留 provider selection、dirty state 和 notifier writes。
- [x] 3.4 迁移或确认 `AiUserProfileScreen`、`ExportLogsScreen` 和 `CustomNotificationScreen` 的多行字段使用统一 multiline field block，保留 maxLength、preview、save 和 controller callbacks。
- [x] 3.5 保留 Host、Port、Pair code、短名称、strategy ID 等短字段的 inline/numeric 语义，不把所有字段强制改成 full-width。

## 4. 测试与守护

- [x] 4.1 更新 `memos_flutter_app/test/architecture/settings_ui_drift_guardrail_test.dart`，要求目标 settings files 继续使用 settings field seams，并防止 page-local field wrapper、裸 `PlatformTextField`、`InputBorder.none`、raw `TextField` 或 page-local field surface 回流。
- [x] 4.2 增加或更新 settings UI focused widget tests，覆盖 `SettingsFormFieldRow`、`SettingsMultilineFieldRow` 和 `SettingsInlineTextFieldRow` fallback 的 field block 对齐与参数传递。
- [x] 4.3 增加或更新相关页面 focused tests，至少覆盖 AI proxy、image bed、location key 或 custom notification 中的代表性字段仍可输入/保存/显示。
- [x] 4.4 运行 `flutter test test/architecture/settings_ui_drift_guardrail_test.dart --reporter expanded`。
- [x] 4.5 运行 `flutter test test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded`，确认依赖方向未恶化。

## 5. 最终验证

- [x] 5.1 运行 `openspec validate align-settings-field-blocks --strict`。
- [x] 5.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.3 从 `memos_flutter_app` 运行相关 focused tests；如变更影响面较大，运行 `flutter test`。
- [x] 5.4 检查最终 diff，确认未修改全局主题文件、API compatibility 文件、业务 service/repository/model、Provider 结构、private hooks、商业/paid-feature 逻辑或新增主题色系统。
- [x] 5.5 记录验证结果和剩余风险，确认该 change 只统一 settings field block 视觉对齐，不改变业务状态和持久化语义。
