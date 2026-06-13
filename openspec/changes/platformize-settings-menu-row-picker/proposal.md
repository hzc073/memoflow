## Why

iPhone/iPadOS 设置页当前通过 `SettingsMenuRow<T>` 在 `CupertinoListTile` 内容中直接渲染 Material `DropdownButton<T>`，进入图片压缩等设置页时会触发 `No Material widget found`，并可能连带产生布局 overflow。此前 onboarding 语言选择已经暴露同类问题，本次应把设置页 enum/single-option selection 收敛到现有 platform picker seam，而不是继续依赖偶然存在的 `Material` ancestor。

当前架构阶段是 `evolve_modularity`，本变更触及 `settings` 这个 coupled area。修复必须让 touched area equal or better structured：把通用设置选择行为收敛到 `SettingsMenuRow` / `showPlatformPicker` seam，减少设置页局部 Material/Cupertino 假设。

## What Changes

- 将 `SettingsMenuRow<T>` 从内嵌 `DropdownButton<T>` 改为语义化的设置选择行：显示当前值、disabled 状态和进入选择的 affordance。
- 点击 `SettingsMenuRow<T>` 后通过现有 `showPlatformPicker` 呈现选项，iPhone/iPadOS 使用平台 popup，Android 使用既有 bottom sheet，macOS/Windows/Linux 使用 bounded dialog。
- 保持调用方 API 尽量稳定：现有 `label`、`value`、`values`、`labelFor`、`onChanged`、`enabled` 语义不变。
- 覆盖图片压缩设置、位置设置、AI 代理设置等复用 `SettingsMenuRow<T>` 的页面，避免每个页面重复局部补丁。
- 增加 iOS widget tests，验证 `ImageCompressionSettingsScreen` 或 `SettingsMenuRow<T>` 在 `TargetPlatform.iOS` 下渲染无 Flutter framework exception，并能打开 picker 和选择新值。
- 不修改 Memos API、请求/响应模型、版本兼容逻辑、数据库 schema、WebDAV 协议、private hooks 或任何商业能力边界。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 明确设置页 enum/single-option 选择应通过设置语义行和平台 picker seam 表达，而不是在 Cupertino/Apple page 内容中直接嵌入 Material-only dropdown。
- `apple-platform-ui-adaptation`: 明确 Apple mobile 设置页中的 `SettingsMenuRow<T>` 必须避免依赖隐式 `Material` ancestor，并通过平台 picker abstraction 呈现选项。

## Impact

- 预计修改 `memos_flutter_app/lib/features/settings/settings_ui.dart`。
- 可能复用或轻度调整 `memos_flutter_app/lib/platform/widgets/platform_picker.dart` 和 `memos_flutter_app/lib/platform/widgets/platform_popover_or_sheet.dart`，但不得让 `platform/` 导入 `features/*`、`state/*`、`application/*` 或 `data/*`。
- 预计补充或调整：
  - `memos_flutter_app/test/features/settings/settings_ui_semantic_components_test.dart`
  - `memos_flutter_app/test/features/settings/image_compression_settings_screen_test.dart`
- 不新增第三方依赖。
- 本变更不触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
