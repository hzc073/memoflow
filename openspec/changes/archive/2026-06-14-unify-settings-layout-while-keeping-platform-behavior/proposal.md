## Why

当前 settings 页面在 iPhone 与 Android 上显示差异较大，主要原因是内容排版仍由 `CupertinoListSection`、`CupertinoListTile`、Material `ListTile` 和各自输入框默认样式共同决定。用户希望保留平台原生交互，但让设置页的文字层级、输入框、section 间距和卡片/分割线层级形成一套自家统一排版。

本项目当前处于 `evolve_modularity` 阶段。这个 change 触及 `features/settings/settings_ui.dart` 共享设置 UI seam，目标是继续把页面视觉规则收敛到共享 seam 中，并通过测试与 guardrail 防止页面私有布局回流。

## What Changes

- 保留 adaptive 行为：`Switch`、返回行为、弹窗 / Picker、输入法与平台文本编辑行为继续由平台控件或现有 platform seam 负责。
- 统一 settings 自家排版：分组标题字号、行标题字号、说明文字字号、右侧选项/值字号、输入框高度、输入框 padding、section 外边距、卡片圆角和分割线层级。
- 将 settings row 的主要布局从平台默认 list row 排版逐步收敛到 settings-owned row shell；平台组件只作为 trailing、picker、switch、text input behavior 的 slot。
- 保留现有 App 主题颜色体系：颜色继续来自 `settingsPageTokens(context)`、`Theme.of(context).colorScheme`、现有 platform/settings token，不新增颜色系统，不修改全局主题配置。
- 保留业务语义：不改变 Provider 状态结构、controller 绑定、保存逻辑、校验、WebDAV 同步/连接、API adapter、持久化 key 或数据库 schema。
- 更新 focused widget tests 与 architecture guardrail，覆盖 Android/iPhone 下 settings typography、row geometry、field block geometry 和 adaptive 控件保留。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 明确 settings 页面可以保留平台行为 adaptive，但文字层级、section/row geometry、输入框视觉应由 settings-owned seam 统一控制。
- `settings-subpage-platformization`: 明确已迁移 settings subpages 不应依赖平台默认 list row 排版造成跨平台视觉不一致，且不得引入页面私有 row/input/card surface。

## Impact

- 主要影响：
  - `memos_flutter_app/lib/features/settings/settings_ui.dart`
  - `memos_flutter_app/lib/platform/widgets/platform_list_section.dart`
  - `memos_flutter_app/lib/platform/widgets/platform_controls.dart`
- 可能影响使用 settings seam 的设置页，包括 WebDAV、AI proxy、image bed、location settings、custom notification、server settings、desktop settings 等已迁移页面。
- 测试影响：
  - 更新 `memos_flutter_app/test/features/settings/settings_ui_semantic_components_test.dart`
  - 更新 `memos_flutter_app/test/architecture/settings_ui_drift_guardrail_test.dart`
  - 根据实现范围补充 Android/iPhone focused widget tests
  - 运行 `flutter analyze`、相关 focused tests、settings UI drift guardrail、modularity guardrail，必要时运行 full `flutter test`
- 不修改：
  - `memos_flutter_app/lib/data/api`
  - `memos_flutter_app/test/data/api`
  - 全局 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或主题 token 文件
  - private hooks、商业/paid-feature 逻辑、subscription/billing/entitlement/paywall/StoreKit 相关代码
