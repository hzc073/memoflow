## 1. 边界确认

- [x] 1.1 阅读 `proposal.md`、`design.md`、两份 delta specs 和本 `tasks.md`，确认本 change 只覆盖 settings 布局/文字层级/row-field geometry 统一。
- [x] 1.2 复查 `memos_flutter_app/lib/features/settings/settings_ui.dart` 中 `SettingsPage`、`SettingsSection`、`SettingsSectionHeader`、`SettingsRowTitle`、`SettingsRowDescription`、`SettingsNavigationRow`、`SettingsValueRow`、`SettingsToggleRow`、`SettingsMenuRow`、`SettingsInfoRow`、`SettingsFieldBlock`、`_SettingsTextField` 的当前职责。
- [x] 1.3 复查 `memos_flutter_app/lib/platform/widgets/platform_list_section.dart` 和 `memos_flutter_app/lib/platform/widgets/platform_controls.dart` 中平台行为与默认几何的边界。
- [x] 1.4 扫描代表性 settings 页面使用点：WebDAV、AI proxy、image bed、location settings、custom notification、server settings、shortcut editor、desktop settings。
- [x] 1.5 确认不编辑 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、WebDAV service/repository/model、数据库 schema、持久化 key、private hooks、商业/paid-feature 逻辑。
- [x] 1.6 确认不修改全局 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或全局主题 token 文件。

## 2. Settings typography 与 layout token

- [x] 2.1 在 `settings_ui.dart` 中定义 settings-owned typography/layout 常量或 helper，覆盖 section header、row title、row value、field value、placeholder、description 的相对层级。
- [x] 2.2 调整 `SettingsSectionHeader`，使分组标题保持次级 group label 层级，不抢页面标题或行标题。
- [x] 2.3 调整 `SettingsRowTitle`，使普通行标题/字段标题在 Android 与 iPhone 上都强于右侧选项和说明文字。
- [x] 2.4 调整 `_SettingsRowValueText` 与 `_SettingsMenuValueLabel`，使右侧值/选项不比左侧 title 更抢眼，并保留截断、最大宽度和对齐逻辑。
- [x] 2.5 调整 `SettingsRowDescription`、helper/error 文本层级和行高，使说明文字低于标题和值，同时保留 error 的 `ColorScheme.error` 语义。
- [x] 2.6 确认所有颜色继续来自 `settingsPageTokens(context)`、`Theme.of(context).colorScheme` 或现有 token，不新增硬编码主题色。

## 3. Settings row shell 与 section geometry

- [x] 3.1 在 `settings_ui.dart` 中引入 `_SettingsRowShell`、`SettingsRowShell` 或等价 settings-owned row shell，统一 row padding、min height、title/value/description/trailing slots、enabled opacity 和 tap behavior。
- [x] 3.2 让 `SettingsNavigationRow` 复用 row shell，保留 value、description、leading、trailingIcon、enabled、onTap 语义。
- [x] 3.3 让 `SettingsValueRow` / `SettingsLongValueRow` 复用 row shell 或等价布局，保留 value width、description、trailing icon、onTap 语义。
- [x] 3.4 让 `SettingsToggleRow` / `SettingsToggleCard` 复用 row shell，保留 `PlatformSwitch`、onChanged、onTap、description 语义和 adaptive switch behavior。
- [x] 3.5 让 `SettingsMenuRow` 复用 row shell 或等价布局，保留 `showSettingsSingleChoicePicker`、value label、chevron、enabled 和 onChanged 语义。
- [x] 3.6 让 `SettingsInfoRow`、selectable/status/action-adjacent rows 在适合范围内跟随统一文字/row geometry，不破坏特殊语义颜色或真正 button 样式。
- [x] 3.7 调整 `SettingsSection` 或其底层 section seam，使 section margin、card/border/radius/divider 在 iPhone 与 Android 上由 settings seam 控制，而非平台默认 list geometry 主导。
- [x] 3.8 保留 desktop dense/work-focused 表现；如需要，为 row shell 保留 desktop density 参数，但不让 desktop 回退到页面私有布局。

## 4. Settings field block 与输入框几何

- [x] 4.1 调整 `SettingsFieldBlock` label、field、helper/error 的 vertical spacing 和 horizontal grid，保持与 row shell / section geometry 对齐。
- [x] 4.2 调整 `_SettingsTextField` value、hint、suffix icon、contentPadding、min height 或 border radius，使 Material `TextField` 与 `CupertinoTextField` 可感知高度和 padding 更一致。
- [x] 4.3 确认 `SettingsFormFieldRow` 仍保留 public constructor 和 focus ownership，并继续委托到 `SettingsFieldBlock`。
- [x] 4.4 确认 `SettingsMultilineFieldRow` 保留 minLines、maxLines、maxLength、helperText、errorText、enabled 和 callbacks。
- [x] 4.5 确认 `SettingsInlineTextFieldRow` / `SettingsNumericInlineFieldRow` 的短字段 inline 语义保留，fallback 继续走统一 full-width field geometry。

## 5. 代表页面确认

- [x] 5.1 确认 WebDAV“服务器连接”页继承统一 section/row/field/文字层级，保留“保存设置”、测试连接、auth mode、TLS switch、root path、controller callbacks。
- [x] 5.2 确认 AI proxy password/test URL、host/port/username、test/save 行为保持不变。
- [x] 5.3 确认 Image bed API URL/password/email/strategy/retry/provider 写入逻辑保持不变。
- [x] 5.4 确认 Location provider key、provider selection、precision selection、dirty state 和 notifier writes 保持不变。
- [x] 5.5 确认 Custom notification、AI user profile、Export logs 多行字段、preview/save/maxLength/controller callbacks 保持不变。
- [x] 5.6 确认 server settings、shortcut editor、desktop settings 等代表性 inline/numeric/toggle/navigation rows 没有明显文字截断、重叠或平台异常。

## 6. 测试与守护

- [x] 6.1 更新 `memos_flutter_app/test/features/settings/settings_ui_semantic_components_test.dart`，覆盖 settings typography hierarchy：row title > row value/input value > description，section header 为次级 group label。
- [x] 6.2 增加或更新 iPhone 与 Android focused widget tests，覆盖 row shell padding/min height/divider、section geometry、field block padding/input height 和 adaptive control presence。
- [x] 6.3 更新代表页面 focused tests，至少覆盖 WebDAV、AI proxy、image bed、location settings、custom notification 中的字段仍可输入/保存/显示。
- [x] 6.4 更新 `memos_flutter_app/test/architecture/settings_ui_drift_guardrail_test.dart`，防止 migrated settings files 回流到 page-local row shell、field block、raw TextField、raw Switch、direct platform list geometry 或 unapproved local surface styling。
- [x] 6.5 如修改 `platform/` seam，确认或补充 guardrail 防止 `platform -> features|state|application|data` 新依赖。

## 7. 验证

- [x] 7.1 运行 `openspec validate unify-settings-layout-while-keeping-platform-behavior --strict`。
- [x] 7.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 7.3 从 `memos_flutter_app` 运行 settings UI focused tests 和代表页面 focused tests。
- [x] 7.4 运行 `flutter test test/architecture/settings_ui_drift_guardrail_test.dart --reporter expanded`。
- [x] 7.5 运行 `flutter test test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded`。
- [x] 7.6 如 row/section seam 影响面较大，运行 full `flutter test`。
- [x] 7.7 检查最终 diff，确认未修改全局主题文件、API/data 文件、业务 service/repository/model、Provider 结构、private hooks、商业/paid-feature 逻辑或新增主题色系统。
- [x] 7.8 记录验证结果和剩余风险，确认该 change 只统一 settings presentation geometry，不改变业务状态和持久化语义。

## 8. 具体验收标准

- [x] 8.1 验收 typography：分组标题字号 < 行标题字号，并由 focused widget test、golden/screenshot 检查或代码断言覆盖。
- [x] 8.2 验收 description：说明文字字号 <= 12，且视觉层级弱于标题和值；error text 保留 `ColorScheme.error` 语义。
- [x] 8.3 验收 value：右侧 value / selected option 不比左侧 label 更醒目，至少在 fontSize、fontWeight、color emphasis 或 opacity 之一上低于或等于 label。
- [x] 8.4 验收 full-width input：full-width 输入框在 iOS / Android 都通过同一 `SettingsFieldBlock` / `SettingsFormFieldRow` / `SettingsMultilineFieldRow` seam 渲染，不新增页面私有 field block。
- [x] 8.5 验收 touch target：普通 settings row 的最小点击高度满足移动端触控要求，不能因统一排版导致 toggle/navigation/value row 点击区域过小。
- [x] 8.6 验收 adaptive behavior：`Switch`、picker/dialog、route/back、文本输入行为仍通过 platform/settings adaptive seam 工作，不能为了统一排版改成单一平台控件行为。
