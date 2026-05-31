# Implementation Notes

## 扫描结果

- `memos_flutter_app/lib/app.dart`: 以下本 change allowlist commands 在实现前仍直接 `_pushMacosMenuRoute(...)`：
  - `macosMenuCommandWebDavBackup`
  - `macosMenuCommandImportFile`
  - `macosMenuCommandImportMarkdown`
  - `macosMenuCommandImportFlomo`
  - `macosMenuCommandImportSwashbucklerDiary`
  - `macosMenuCommandExportMemos`
  - `macosMenuCommandMigration`
  - `macosMenuCommandQuickPrompts`
  - `macosMenuCommandDesktopShortcutsOverview`
  - `macosMenuCommandSelfRepair`
  - `macosMenuCommandExportDiagnostics`
  - `macosMenuCommandReleaseNotes`
  - `macosMenuCommandFeedback`
- `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`: 已有 `components`、`importExport`、`feedback`、`about`、`windowsRelated` pane，并已有 pane-local `Navigator` 机制可打开 nested route。
- `memos_flutter_app/lib/application/desktop/desktop_settings_window.dart`: `DesktopSettingsWindowTarget` 当前只覆盖上一轮 settings-like targets，需要扩展 stable payload values。

## 迁移项

- `macosMenuCommandWebDavBackup` -> `DesktopSettingsWindowTarget.webDavBackup` -> `components` pane + `WebDavSyncScreen`
- `macosMenuCommandImportFile` / `macosMenuCommandImportMarkdown` / `macosMenuCommandImportFlomo` / `macosMenuCommandImportSwashbucklerDiary` -> `DesktopSettingsWindowTarget.importData` -> `importExport` pane + `ImportSourceScreen`
- `macosMenuCommandExportMemos` -> `DesktopSettingsWindowTarget.exportMemos` -> `importExport` pane + `ExportMemosScreen`
- `macosMenuCommandMigration` -> `DesktopSettingsWindowTarget.localNetworkMigration` -> `importExport` pane + `LocalNetworkMigrationScreen`
- `macosMenuCommandQuickPrompts` -> `DesktopSettingsWindowTarget.quickPrompts` -> `ai` pane + `AiInsightPromptEditorScreen.custom()`
- `macosMenuCommandDesktopShortcutsOverview` -> `DesktopSettingsWindowTarget.desktopShortcutsOverview` -> `windowsRelated` pane + `DesktopShortcutsOverviewScreen`
- `macosMenuCommandSelfRepair` -> `DesktopSettingsWindowTarget.selfRepair` -> `feedback` pane + `SelfRepairScreen`
- `macosMenuCommandExportDiagnostics` -> `DesktopSettingsWindowTarget.exportDiagnostics` -> `feedback` pane + `ExportLogsScreen`
- `macosMenuCommandFeedback` -> `DesktopSettingsWindowTarget.feedback` -> `feedback` pane root
- `macosMenuCommandReleaseNotes` -> `DesktopSettingsWindowTarget.releaseNotes` -> `about` pane + `ReleaseNotesScreen`

## 暂缓项

- `macosMenuCommandNewMemo`: 应接入 desktop home compose / quick input 语义，不属于 settings window owner surface。
- `macosMenuCommandSearchMemos`: 应接入 home-level search command seam，不属于 settings window owner surface。
- `macosMenuCommandSyncQueue`: 已有 `DesktopHomeUtilityView.syncQueue`，适合后续单独接入 desktop home utility embedding。
- `macosMenuCommandAiReports`: `AiInsightHistoryScreen` 当前向 `AiSummaryScreen` 返回 selection，顶部菜单直接打开缺少接收方。

## 复查修正

- `macosMenuCommandQuickPrompts` 不再使用旧 `QuickPromptEditorScreen`。该页面只 `safePop(AiQuickPrompt)`，从顶部菜单直接打开时没有接收方，也不会持久化。
- 当前可持久化的快速提示词产品语义落在自定义 AI insight template 上，因此 macOS 菜单主路径和 fallback 都改为 `AiInsightPromptEditorScreen.custom()`。

## 边界确认

本 change 不修改 API、数据库 schema、同步协议、商业/private overlay 行为，也不新增订阅、付费、StoreKit、entitlement、receipt、paywall 或 `AccessDecision.source` 业务分支。
