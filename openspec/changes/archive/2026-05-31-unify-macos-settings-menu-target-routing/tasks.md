## 1. 扫描和分类

- [x] 1.1 扫描 `app.dart`、`AppDelegate.swift`、`settings_screen.dart`、`desktop_settings_window_app.dart`、`components_settings_screen.dart`、`preferences_settings_screen.dart` 和桌面设置页中的 settings-like route 入口。
- [x] 1.2 形成候选清单，将每个 macOS menu command 分类为 `settings target`、`task surface candidate` 或 `business/tool page`。
- [x] 1.3 标记与 `generalize-desktop-settings-platform-sections` 重叠的桌面设置/快捷键入口，并决定实施顺序。
- [x] 1.4 确认本 change 不修改 API、数据库 schema、同步协议或商业/private overlay 行为。

## 2. Target Routing 扩展

- [x] 2.1 在 `DesktopSettingsWindowTarget` 或等价结构中增加批量迁移所需的 settings targets。
- [x] 2.2 支持 pane 内 nested target，例如 components/template、components/location、preferences/memoToolbar。
- [x] 2.3 让 `DesktopSettingsWindowApp` 根据 target 选择 pane 并在 pane navigator 中打开目标页面。
- [x] 2.4 保持 target-to-widget mapping 在 settings window UI composition 中，避免 `application` 或 `core` 新增 feature UI imports。

## 3. macOS 菜单迁移

- [x] 3.1 将 `macosMenuCommandAiProvider` 迁移到 settings window target 或记录为需要确认后暂缓。
- [x] 3.2 将 `macosMenuCommandShortcutSettings` 迁移到桌面设置/快捷键 target，并与桌面设置平台分段 change 保持一致。
- [x] 3.3 将 `macosMenuCommandTemplateSettings` 迁移到 components/template target。
- [x] 3.4 将 `macosMenuCommandMemoToolbarSettings` 迁移到 preferences/memoToolbar target。
- [x] 3.5 将 `macosMenuCommandLocationSettings`、`macosMenuCommandImageBedSettings`、`macosMenuCommandImageCompression` 迁移到 components nested targets。
- [x] 3.6 保持 `AI Summary`、`AI Reports`、`Quick Prompts`、`Self Repair`、`Export Diagnostics`、导入导出和迁移类命令不纳入 settings window target routing。
- [x] 3.7 为每个迁移项保留 unsupported / failed fallback 到原页面。

## 4. Guardrails And Tests

- [x] 4.1 增加 settings window target tests，覆盖至少一个顶层 pane target 和一个 pane nested target。
- [x] 4.2 增加 macOS menu focused tests 或 guardrail，确认已迁移 settings-like commands 主路径使用 target settings window。
- [x] 4.3 增加扫描清单或 implementation note，记录哪些 commands 被迁移、暂缓或保持普通 route，以及理由。
- [x] 4.4 检查 touched public files 不包含商业、订阅、付费、StoreKit、entitlement、private overlay 或 `AccessDecision.source` 业务分支。

## 5. 验证

- [x] 5.1 运行 macOS menu / settings window focused tests。
- [x] 5.2 运行相关 architecture guardrail tests。
- [x] 5.3 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.4 运行 `flutter test` 或记录环境 blocker。
- [x] 5.5 运行 `openspec validate unify-macos-settings-menu-target-routing --strict`。
- [x] 5.6 在 macOS 手动 smoke 已迁移 settings-like menu commands：窗口聚焦、pane/nested route、返回、失败 fallback。
