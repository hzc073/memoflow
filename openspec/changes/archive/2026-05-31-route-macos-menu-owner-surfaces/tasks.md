## 1. 扫描和确认

- [x] 1.1 复查 `memos_flutter_app/lib/app.dart` 中本 change allowlist 的 macOS command cases，确认主路径仍直接 `_pushMacosMenuRoute(...)`。
- [x] 1.2 复查 `DesktopSettingsWindowApp` 的 panes 和 pane-local `Navigator`，确认 `components`、`importExport`、`feedback`、`about`、`windowsRelated` 能承接目标页面。
- [x] 1.3 写入 implementation notes，记录迁移项、暂缓项和每个暂缓项原因。
- [x] 1.4 确认本 change 不修改 API、数据库 schema、同步协议或商业/private overlay 行为。

## 2. Settings Window Target 扩展

- [x] 2.1 在 `DesktopSettingsWindowTarget` 或等价结构中增加 `webDavBackup`、`importData`、`exportMemos`、`localNetworkMigration`、`desktopShortcutsOverview`、`selfRepair`、`exportDiagnostics`、`feedback`、`releaseNotes`。
- [x] 2.2 更新 target payload serialization / deserialization / launch args parsing，保持 stable string values。
- [x] 2.3 在 `DesktopSettingsWindowApp` 中将新增 targets 映射到 owner pane 和 pane-local nested route。
- [x] 2.4 为 `desktopShortcutsOverview` target 在 settings window composition 内读取并 normalize `desktopShortcutBindings`。
- [x] 2.5 保持 target-to-widget mapping 在 settings UI composition 中，避免 `application/desktop` 或 `core` 新增 feature UI imports。

## 3. macOS Menu Routing

- [x] 3.1 将 `macosMenuCommandWebDavBackup` 主路径迁移到 WebDAV settings window target，并保留 `WebDavSyncScreen` fallback。
- [x] 3.2 将 import commands 主路径迁移到 import data settings window target，并保留 `ImportSourceScreen` fallback。
- [x] 3.3 将 `macosMenuCommandExportMemos` 主路径迁移到 export memos settings window target，并保留 `ExportMemosScreen` fallback。
- [x] 3.4 将 `macosMenuCommandMigration` 主路径迁移到 local network migration settings window target，并保留 `LocalNetworkMigrationScreen` fallback。
- [x] 3.5 将 `macosMenuCommandDesktopShortcutsOverview` 主路径迁移到 desktop shortcuts overview settings window target，并保留原 overview fallback。
- [x] 3.6 将 `macosMenuCommandSelfRepair` 和 `macosMenuCommandExportDiagnostics` 主路径迁移到 feedback owner targets，并保留原页面 fallback。
- [x] 3.7 将 `macosMenuCommandFeedback` 和 `macosMenuCommandReleaseNotes` 主路径迁移到 feedback/about owner targets，并保留原页面 fallback。
- [x] 3.8 保持 `New Memo`、`Search Memos`、`Sync Queue`、`AI Reports` 不纳入本 change routing。

## 4. Tests And Guardrails

- [x] 4.1 增加或扩展 settings window target tests，覆盖 pane root target、nested route target、以及 `desktopShortcutsOverview` bindings 读取。
- [x] 4.2 扩展 macOS menu guardrail，确认本 change allowlist commands 的主路径使用 `_openMacosSettingsWindow(target: ...)`。
- [x] 4.3 确保 guardrail 允许 explicit fallback widget construction，但禁止 allowlist command 直接 standalone push 作为主路径。
- [x] 4.4 检查 touched public files 不包含商业、订阅、付费、StoreKit、entitlement、receipt、paywall、private overlay 或 `AccessDecision.source` 业务分支。

## 5. 验证

- [x] 5.1 运行 settings window focused tests。
- [x] 5.2 运行 macOS menu / public shell architecture guardrail tests。
- [x] 5.3 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.4 从 `memos_flutter_app` 运行 `flutter test`，或记录明确环境 blocker。
- [x] 5.5 运行 `openspec validate route-macos-menu-owner-surfaces --strict`。
- [x] 5.6 在 macOS 手动 smoke 本 change allowlist menu commands：窗口聚焦、pane/nested route、返回、fallback 行为。

## 6. AI Quick Prompts 修正

- [x] 6.1 更新 proposal/design/spec/notes，将 `Quick Prompts` 从暂缓项移入本 change 的 AI owner surface。
- [x] 6.2 增加 `DesktopSettingsWindowTarget.quickPrompts` 及 stable payload 解析。
- [x] 6.3 将 `macosMenuCommandQuickPrompts` 主路径迁移到 settings window quick prompts target，并使用可持久化的 `AiInsightPromptEditorScreen.custom()` fallback。
- [x] 6.4 补 settings window target test 和 macOS guardrail 覆盖，禁止回退到旧 `QuickPromptEditorScreen` 主路径。
- [x] 6.5 运行 focused tests、`flutter analyze`、`flutter test` 和 `openspec validate route-macos-menu-owner-surfaces --strict`，或记录明确 blocker。
