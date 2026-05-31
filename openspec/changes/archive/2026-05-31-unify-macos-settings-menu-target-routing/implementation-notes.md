# Implementation Notes

## 扫描清单

已扫描以下入口：

- `memos_flutter_app/lib/app.dart`: macOS command handler 中 `AI Settings` 已使用 `DesktopSettingsWindowTarget.ai`；`AI Provider`、`Shortcut Settings`、`Template Settings`、`Memo Toolbar Settings`、`Location Settings`、`Image Bed Settings`、`Image Compression` 仍直接 `_pushMacosMenuRoute(...)`。
- `memos_flutter_app/macos/Runner/AppDelegate.swift`: 原生菜单只分发 command string；AI 菜单包含 `AI Summary`、`AI Reports`、`Quick Prompts`、`AI Settings`、`AI Provider`，Tools 菜单包含 shortcut/settings-like/tool commands。
- `memos_flutter_app/lib/features/settings/settings_screen.dart`: root settings rows 继续作为普通 settings root 内部导航，不是本 change 的 macOS menu 主路径。
- `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`: settings window 已有 pane-local `Navigator`，但 `DesktopSettingsWindowTarget` 当前只支持 AI pane。
- `memos_flutter_app/lib/features/settings/components_settings_screen.dart`: components pane 内已有 reminders、image bed、image compression、location、template、WebDAV nested settings routes。
- `memos_flutter_app/lib/features/settings/preferences_settings_screen.dart`: preferences pane 内已有 memo toolbar nested route。
- `memos_flutter_app/lib/features/settings/windows_related_settings_screen.dart`: desktop shortcuts 当前挂在 Windows-related pane 内；`generalize-desktop-settings-platform-sections` 后续会泛化该 pane 命名和平台分段。

## macOS menu command 分类

### settings target

- `macosMenuCommandAiSettings`: 已迁移，打开 AI pane。
- `macosMenuCommandAiProvider`: 迁移为 AI pane 内 `AiProviderSettingsScreen` nested target，保持原页面 fallback。
- `macosMenuCommandShortcutSettings`: 迁移为现有 `windowsRelated` pane 内 `DesktopShortcutsSettingsScreen` nested target；不在本 change 中重命名 pane，后续 `generalize-desktop-settings-platform-sections` 落地后调整 owning pane。
- `macosMenuCommandTemplateSettings`: 迁移为 components pane 内 `TemplateSettingsScreen` nested target。
- `macosMenuCommandMemoToolbarSettings`: 迁移为 preferences pane 内 `MemoToolbarSettingsScreen` nested target。
- `macosMenuCommandLocationSettings`: 迁移为 components pane 内 `LocationSettingsScreen` nested target。
- `macosMenuCommandImageBedSettings`: 迁移为 components pane 内 `ImageBedSettingsScreen` nested target。
- `macosMenuCommandImageCompression`: 迁移为 components pane 内 `ImageCompressionSettingsScreen` nested target。

### task surface candidate

- `macosMenuCommandQuickPrompts`: 保持普通 route。本 change 不评估 task surface 迁移。

### business/tool page

- `macosMenuCommandAiSummary`
- `macosMenuCommandAiReports`
- `macosMenuCommandSelfRepair`
- `macosMenuCommandExportDiagnostics`
- import/export/migration commands
- `macosMenuCommandDesktopShortcutsOverview`
- help/release/feedback commands

## 边界确认

本 change 不修改 API、数据库 schema、同步协议、商业/private overlay 行为，也不新增订阅、付费、StoreKit、entitlement、receipt、paywall 或 `AccessDecision.source` 业务分支。
