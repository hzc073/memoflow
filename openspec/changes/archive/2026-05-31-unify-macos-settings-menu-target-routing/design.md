## Context

macOS native menu 通过 `macosMenuCommandChannelName` 把命令派发给 `app.dart`。当前 command handler 对大量命令采用 `_pushMacosMenuRoute(...)`。这对业务页面合理，例如 AI 总结、AI 报告、导入导出、诊断工具；但对设置类页面会产生两个问题：

1. 同一设置内容在主窗口普通 route 和 `DesktopSettingsWindowApp` 内的视觉/导航/chrome 行为不同。
2. macOS settings window 已经是设置入口的标准外壳，但业务菜单中的设置项没有复用它。

第一个 change `route-macos-ai-settings-to-settings-pane` 先提供 AI 设置目标。这个 change 复用同一机制，把其他明确设置类命令纳入统一路由。

## Goals / Non-Goals

**Goals:**

- 建立 settings-like macOS menu command 的扫描清单和分类标准。
- 将明确属于设置的 macOS 菜单命令迁移到目标化 settings window routing。
- 支持 settings window target 定位到顶层 pane 和 pane 内二级 route。
- 对 settings window unsupported / failed 保留原页面 fallback。
- 与 `generalize-desktop-settings-platform-sections` 协调桌面设置/快捷键入口，避免冲突。
- 增加 guardrail，避免已迁移设置类命令回退到直接 push standalone settings pages。

**Non-Goals:**

- 不把所有 macOS 菜单命令都迁移到 settings window。
- 不重构每个设置页面的内部 UI seam，除非目标路由需要最小适配。
- 不迁移任务型编辑流程到 settings window；任务型流程应单独评估 `PlatformSecondaryTaskSurface`。
- 不改变 native menu label、本地化文件或菜单层级，除非扫描发现 label 与目标语义明显冲突。
- 不修改 API、数据库 schema、同步协议或商业/private overlay 行为。

## Decisions

### 1. 先扫描分类，再迁移

实现前应扫描至少以下来源：

```text
app.dart macOS command cases
macos/Runner/AppDelegate.swift menu definitions
settings_screen.dart root settings rows
desktop_settings_window_app.dart pane list
components_settings_screen.dart nested settings routes
preferences_settings_screen.dart nested settings routes
windows_related/desktop settings page routes
```

候选项按三类记录：

```text
settings target
  应进入 settings window，例如 AI Provider、模板、图床、位置、图片压缩

task surface candidate
  更像短任务/编辑器，例如 Quick Prompts，后续考虑 task surface

business/tool page
  保持普通 route，例如 AI Summary、AI Reports、Self Repair、Export Diagnostics
```

### 2. settings window target 需要支持 pane 内 route

部分目标不是顶层 pane，而是 pane 内二级页。例如：

```text
Template Settings
  -> components pane
  -> push TemplateSettingsScreen inside pane navigator

Memo Toolbar Settings
  -> preferences pane
  -> push MemoToolbarSettingsScreen inside pane navigator
```

因此 target 不应只是 `_DesktopSettingsPane` enum 的外部别名。它应能表达：

```text
target
  pane: components
  nestedRoute: templateSettings
```

或等价结构。目标到 widget 的映射仍由 `DesktopSettingsWindowApp` 拥有，避免 lower layer 持有 feature imports。

### 3. 批量迁移采用允许列表，不采用名称猜测

不要通过字符串包含 `Settings` 自动迁移。应明确列出被迁移的 menu command，并为每个 command 写出目标和 fallback。

初始建议候选：

```text
macosMenuCommandAiProvider       -> AI pane 或 AI provider nested target
macosMenuCommandShortcutSettings -> desktop settings / shortcut target
macosMenuCommandTemplateSettings -> components/template target
macosMenuCommandMemoToolbarSettings -> preferences/memo toolbar target
macosMenuCommandLocationSettings -> components/location target
macosMenuCommandImageBedSettings -> components/image bed target
macosMenuCommandImageCompression -> components/image compression target
```

需保留普通 route 的命令：

```text
macosMenuCommandAiSummary
macosMenuCommandAiReports
macosMenuCommandQuickPrompts
macosMenuCommandSelfRepair
macosMenuCommandExportDiagnostics
import/export/migration commands
```

### 4. 与 desktop settings platform sections change 协调

`generalize-desktop-settings-platform-sections` 正在把 `WindowsRelatedSettingsScreen` 泛化为桌面设置，并将桌面快捷键作为共享桌面设置。若两个 change 同时实施，应先落地或合并该 change 的桌面设置 pane 命名，再在本 change 中把 `Shortcut Settings` target 指向新的 desktop settings surface。否则容易出现 target 指向旧 `WindowsRelatedSettingsScreen` 的过渡状态。

### 5. fallback 是兼容路径，不是主体验

每个被迁移 command 都应保留原页面 fallback，方便 settings window unsupported / failed 时可见。但 guardrail 应防止主路径绕过 target window。测试应覆盖至少一个 pane target 和一个 nested target。

## Risks / Trade-offs

- [Risk] 一次迁移太多页面导致 pane 内导航状态、返回和保存语义混乱。Mitigation: 先按扫描清单确认目标类别，任务中允许逐个迁移并测试。
- [Risk] `AI Provider` 与 `AiSettingsScreen` 的关系不清楚，可能应该并入 AI pane 而不是 nested page。Mitigation: 扫描后记录为需要产品确认的 target；未确认前可以保持 fallback 或单独 nested route。
- [Risk] 桌面快捷键 target 与 `generalize-desktop-settings-platform-sections` 冲突。Mitigation: 明确依赖/协调任务，实施时先处理 desktop settings surface 命名。
- [Risk] target seam 扩展时引入 `application -> features` imports。Mitigation: lower layer 只传递 target value，widget construction 留在 settings window UI composition。
- [Risk] guardrail 误拦截 fallback。Mitigation: 区分主路径和 fallback，允许 fallback 构造原页面。

## Open Questions

- `AI Provider` 是否应该作为 AI pane 内二级页，还是作为 AI 设置页中的某个 section/任务入口。
- `Quick Prompts` 是否应保持普通 route，还是后续作为 task surface 迁移；本 change 暂不纳入 settings window。
- `Shortcut Settings` target 应等待 `generalize-desktop-settings-platform-sections` 完成后再接入，还是先指向现有页面并在后续重定向。
