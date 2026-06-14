## 1. 范围确认与基线

- [x] 1.1 确认本 change 只影响设置首页手机端 density，不修改入口顺序、导航目标、haptic、private extension entry、DonationDialog 或 account/local library 行为。
- [x] 1.2 记录当前 row 路径：`SettingsHomeSection` -> `SettingsNavigationRow` -> `PlatformListSectionRow` -> Material/Cupertino row，并确认 Android phone 当前单行默认高度来自 Material `ListTile` 56dp。
- [x] 1.3 确认本 change 不修改 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、数据模型、数据库、同步协议、AI provider、private hooks 或商业逻辑。

## 2. Home density tokens / seams

- [x] 2.1 在 `memos_flutter_app/lib/features/settings/settings_ui.dart` 的 `SettingsHomeHierarchyTokens` 中增加或扩展 home-only 普通功能行密度 token，目标 phone single-line row height 为 48 logical pixels。
- [x] 2.2 将 phone home hierarchy 第一版数值调整为 `shortcutTileHeight: 80`、`sectionSpacing: 12`、`profilePadding: 16`。
- [x] 2.3 让 `SettingsHomeSection` 或等价 settings-owned seam 将 compact row density 应用到首页普通 `SettingsNavigationRow`，并保持普通 `SettingsSection` 不受影响。
- [x] 2.4 如需扩展 `PlatformListSectionRow`，仅添加通用 semantic density 参数；`platform/` code MUST NOT import `features/*`、`state/*`、`application/*` 或 `data/*`。
- [x] 2.5 保持 rows with `description`、text scale 放大、或多行内容可自然增高，不因 48dp target 截断语义内容。

## 3. 设置首页接入

- [x] 3.1 确认 `SettingsScreen` 继续只表达 profile、shortcut tiles、grouped sections 和 navigation semantics，不写 page-local height/padding/radius/shadow 数值。
- [x] 3.2 保持 grouped card + row divider 模型；普通功能入口不拆成独立卡片。
- [x] 3.3 保持 desktop settings 首页和二级/三级 settings pages 的现有密度，不继承 mobile home compact treatment。

## 4. 测试与 guardrail

- [x] 4.1 更新 `settings_ui_semantic_components_test.dart`，断言 phone home tokens 包含 `shortcutTileHeight: 80`、`sectionSpacing: 12`、`profilePadding: 16` 和 ordinary row compact target。
- [x] 4.2 更新或新增 `settings_screen_test.dart`，覆盖 Android phone 设置首页普通功能行高度约束、shortcut tile height 和 grouped section 行为。
- [x] 4.3 增加二级/三级 settings page 回归测试，确认标准 `SettingsSection` 未被 home compact density 全局影响。
- [x] 4.4 如改动 `PlatformListSectionRow`，更新 `platform_ui_test.dart` 或等价测试，覆盖 semantic density 参数在 Material mobile 与 desktop dense 行上的行为。
- [x] 4.5 更新 `settings_ui_drift_guardrail_test.dart`，允许 settings seam 拥有 home density token，同时继续阻止 `settings_screen.dart` 引入 page-local background、border、divider、shadow、radius、height 或 padding 漂移。

## 5. 验证与收尾

- [x] 5.1 从 `memos_flutter_app` 运行 `dart format` 覆盖所有修改过的 Dart 文件。
- [x] 5.2 从 `memos_flutter_app` 运行 focused tests：settings UI semantic tests、settings screen tests、platform row seam tests 和 settings drift guardrail tests。
- [x] 5.3 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.4 从 `memos_flutter_app` 运行 `flutter test`；如环境或既有失败阻塞，记录具体命令、失败用例和剩余风险。已运行 `flutter test`，剩余失败位于 `test/private_hooks/app_ready_hook_test.dart`、`test/features/home/home_bottom_nav_shell_test.dart` 和 `test/features/onboarding/platform_adaptive_onboarding_test.dart`，不在本 change 的 settings density 写入范围；focused settings/platform/guardrail tests 已通过。
- [x] 5.5 在手机端 light/dark 下人工或截图检查设置首页：普通功能行、profile card、shortcut tiles、section spacing、底部滚动区域和长文本不重叠、不溢出。
