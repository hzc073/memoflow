## 1. Settings menu row 平台化

- [x] 1.1 在 `SettingsMenuRow<T>` 中移除内嵌 `DropdownButton<T>` / `DropdownButtonHideUnderline`。
- [x] 1.2 让 `SettingsMenuRow<T>` 渲染当前选项 label、disabled opacity 和进入选择的 chevron/affordance。
- [x] 1.3 点击 enabled row 时调用 `showPlatformPicker<T>` 或等价 picker seam 展示 `values`。
- [x] 1.4 picker option 复用 `labelFor`，当前选项显示 selected/radio 状态，选择后关闭 picker 并调用 `onChanged(next)`。
- [x] 1.5 保持 `SettingsMenuRow<T>` 现有构造参数和调用方行为稳定，避免让各设置页复制 `_selectEnum` 逻辑。

## 2. 平台边界与结构保护

- [x] 2.1 确认 `platform/widgets/platform_picker.dart` 和相关 platform seam 不导入 `features/*`、`state/*`、`application/*` 或 `data/*`。
- [x] 2.2 确认 `settings` 页面只表达 label/value/onChanged 语义，不新增页面级 iOS dropdown wrapper。
- [x] 2.3 确认本变更不引入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。

## 3. 测试覆盖

- [x] 3.1 更新 `settings_ui_semantic_components_test.dart`，从断言 `DropdownButton` 改为断言 `SettingsMenuRow<T>` value display 和 picker selection 行为。
- [x] 3.2 为 iPhone/iPadOS 平台分支增加 widget test：设置 `debugPlatformTargetOverride = TargetPlatform.iOS`，pump `SettingsMenuRow<T>` 或 `ImageCompressionSettingsScreen`，断言没有 `No Material widget found`。
- [x] 3.3 增加点击 menu row 打开 picker 并选择新值的测试，覆盖 `onChanged` 和显示更新。
- [x] 3.4 保留图片压缩设置页现有核心控件测试，避免 settings screen composition 回退。

## 4. 验证

- [x] 4.1 从 `memos_flutter_app` 运行 focused settings tests。
- [x] 4.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [ ] 4.3 按需要运行 `flutter test`。
- [x] 4.4 检查 diff，确认未触碰 API compatibility 文件、WebDAV 协议、数据库 schema、private hooks 或任何商业/paid-feature 逻辑。
