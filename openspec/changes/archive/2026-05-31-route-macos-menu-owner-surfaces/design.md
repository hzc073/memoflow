## Context

macOS native menu 通过 `macosMenuCommandChannelName` 将 command string 派发到 `memos_flutter_app/lib/app.dart`。上一个 change 已经让明确 settings-like 的命令进入 `openDesktopSettingsWindow(target: ...)`，但仍有一组页面虽然在 settings window 里已经有明确 owner pane，却继续从 macOS 顶部菜单直接 `_pushMacosMenuRoute(...)` 到主窗口。

当前状态的关键点：

- `DesktopSettingsWindowTarget` 已能表达 pane 和 pane-local nested route，但 allowlist 只覆盖 AI、快捷键设置、模板、工具栏、位置、图床、图片压缩等设置类命令。
- `DesktopSettingsWindowApp` 已有 `feedback`、`importExport`、`about`、`components` 等 pane，也已有 pane-local `Navigator` 可承接二级页。
- `ImportExportScreen`、`FeedbackScreen`、`AboutUsScreen`、`ComponentsSettingsScreen` 内部已经能打开本 change 目标页面，说明这些目标有明确的 settings window owner surface。
- `app.dart` 仍是 macOS menu command 的 UI composition root，因此 fallback widget construction 可以继续留在 `app.dart`，但主路径应尽量只传递 stable target value。

依赖方向变化：

- 变更前：`app.dart` 对这些 command 直接构造 feature pages，并把主窗口作为所有二级页面的默认宿主。
- 变更后：`app.dart` 对 allowlist command 优先传递 `DesktopSettingsWindowTarget`，由 `desktop_settings_window_app.dart` 这个 settings UI composition point 负责 target-to-widget mapping；`app.dart` 只保留 unsupported / failed fallback。
- lower layers 仍不引入新的 `features/*` imports；`DesktopSettingsWindowTarget` 只表达 stable target values，不包含 feature widget 类型或业务逻辑。

## Goals / Non-Goals

**Goals:**

- 为有明确 settings window owner surface 的 macOS menu commands 增加 target routing。
- 保留原页面 fallback，避免 settings window unsupported / failed 时无可见反馈。
- 将目标分类写入 artifacts，避免自动按名称猜测迁移。
- 通过 focused tests / guardrail 防止 allowlist command 回退到直接 standalone route 主路径。
- 在 `evolve_modularity` 阶段改善 `app.dart` composition root 压力，并守住 `application -> features`、`core -> features` 不恶化。

**Non-Goals:**

- 不改 native menu label、本地化资源或菜单层级。
- 不把 `New Memo`、`Search Memos`、`Sync Queue`、`AI Reports` 纳入本 change；它们需要 home command、desktop utility embedding、AI history 或 task surface 的单独设计。
- 不把任务型流程迁移到 `PlatformSecondaryTaskSurface`，除非 settings window 内已有 owner pane 的二级 route 需要保持现状。
- 不修改 API、数据库 schema、同步协议、商业/private overlay 或付费能力边界。

## Decisions

### 1. 以 owner surface 为迁移标准，而不是 label 关键词

采用显式 allowlist：

```text
macosMenuCommandWebDavBackup              -> DesktopSettingsWindowTarget.webDavBackup
macosMenuCommandQuickPrompts              -> DesktopSettingsWindowTarget.quickPrompts
macosMenuCommandImportFile                -> DesktopSettingsWindowTarget.importData
macosMenuCommandImportMarkdown            -> DesktopSettingsWindowTarget.importData
macosMenuCommandImportFlomo               -> DesktopSettingsWindowTarget.importData
macosMenuCommandImportSwashbucklerDiary   -> DesktopSettingsWindowTarget.importData
macosMenuCommandExportMemos               -> DesktopSettingsWindowTarget.exportMemos
macosMenuCommandMigration                 -> DesktopSettingsWindowTarget.localNetworkMigration
macosMenuCommandDesktopShortcutsOverview  -> DesktopSettingsWindowTarget.desktopShortcutsOverview
macosMenuCommandSelfRepair                -> DesktopSettingsWindowTarget.selfRepair
macosMenuCommandExportDiagnostics         -> DesktopSettingsWindowTarget.exportDiagnostics
macosMenuCommandFeedback                  -> DesktopSettingsWindowTarget.feedback
macosMenuCommandReleaseNotes              -> DesktopSettingsWindowTarget.releaseNotes
```

这些目标都能在 settings window 内找到现有 owner pane。替代方案是继续保持普通 route，成本最低但会保留两套桌面体验；另一种方案是创建新的独立工具窗口，但会扩大多窗口生命周期和插件注册范围，不适合这个小步迁移。

### 2. target enum 继续只表达目标值，widget mapping 留在 settings UI composition

`DesktopSettingsWindowTarget` 增加目标值、payload serialization 和 deserialization。每个 target 在 `_DesktopSettingsWorkbench._applyTargetRequestIfNeeded()` 中映射到 owning pane 和可选 `_pendingTargetRouteBuilder`。

目标到 pane 的初始映射：

```text
webDavBackup              -> components pane + WebDavSyncScreen
quickPrompts              -> ai pane + AiInsightPromptEditorScreen.custom()
importData                -> importExport pane + ImportSourceScreen
exportMemos               -> importExport pane + ExportMemosScreen
localNetworkMigration     -> importExport pane + LocalNetworkMigrationScreen
desktopShortcutsOverview  -> windowsRelated pane + DesktopShortcutsOverviewScreen
selfRepair                -> feedback pane + SelfRepairScreen
exportDiagnostics         -> feedback pane + ExportLogsScreen
feedback                  -> feedback pane root
releaseNotes              -> about pane + ReleaseNotesScreen
```

`DesktopShortcutsOverviewScreen` 需要读取当前 `desktopShortcutBindings`。为避免 lower layer 依赖 feature widget，读取和 widget construction 留在 `DesktopSettingsWindowApp` 的 provider-aware composition 中，而不是放进 `application/desktop`。

### 3. macOS menu handler 使用统一 helper，fallback 保持原页面

在 `app.dart` 中复用或扩展 `_openMacosSettingsWindow(target: ..., fallback: ...)`。主路径 request settings window，失败时 fallback 到原有 widget：

```text
target request succeeds -> no main-window route push
target request unsupported / failed -> push original visible page
```

guardrail 需要区分主路径与 fallback，不应禁止 fallback widget construction。

### 4. 暂缓项写入实现备注，不在本 change 猜测语义

以下项保持普通路径或暂缓：

- `New Memo`: 应进入 desktop home compose / quick input 语义，而不是 settings window。
- `Search Memos`: 应打开 home 的搜索状态，需要 home-level command seam。
- `Sync Queue`: 已有 `DesktopHomeUtilityView.syncQueue`，适合单独接入 desktop home utility embedding。
- `AI Reports`: 当前 `AiInsightHistoryScreen` 返回 selection 给 `AiSummaryScreen`，顶部菜单直接打开缺少接收方。
`Quick Prompts` 曾被暂缓，因为旧 `QuickPromptEditorScreen` 只返回 `AiQuickPrompt`，顶部菜单直接打开时没有接收方。实现复查后确认当前可持久化的产品语义是自定义 AI insight template，因此本 change 将它纳入 `AI` owner surface，主路径打开 `AiInsightPromptEditorScreen.custom()`，fallback 也使用同一可保存编辑器，而不是继续使用旧的返回值编辑器。

## Risks / Trade-offs

- [Risk] 一次增加较多 targets，pane-local navigation 可能遗漏某个目标的返回或参数依赖。Mitigation: 为至少一个 pane root target、一个 nested route target、一个带 provider 读取的 target 加 focused tests，并用 guardrail 覆盖全部 allowlist command。
- [Risk] `DesktopShortcutsOverviewScreen` 的 bindings 来源在 main window 和 settings window 不一致。Mitigation: settings window 内从 `devicePreferencesProvider` 读取并 normalize，保持与现有 settings window shortcut handler 一致。
- [Risk] fallback 被 guardrail 误判为主路径。Mitigation: guardrail 按 command case body 检查 `_openMacosSettingsWindow` 和 target，同时允许 fallback 参数内出现原页面 widget。
- [Risk] `generalize-desktop-settings-platform-sections` 后续可能重命名 `windowsRelated` pane。Mitigation: 本 change 只记录当前 owner pane；后续 change 可更新 target-to-pane mapping，不需要改 macOS menu command seam。
- [Risk] 这些页面里仍有一些 full-page `Scaffold + AppBar` 风格。Mitigation: 本 change 只改变 owner surface；若页面内部 chrome 需要进一步桌面化，交给 `desktop-secondary-task-surfaces` 或 `secondary-page-navigation` 后续 change。
