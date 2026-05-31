## Why

上一次 change 已经把明确属于设置的 macOS 顶部菜单项迁移到 target settings window，但 `WebDAV Backup`、Import/Export/Migration、Self Repair、Export Diagnostics、Feedback、Release Notes 等仍从主窗口直接 push standalone page。它们在现有产品结构中已有 settings window 的拥有 pane，继续走独立 route 会让同一功能在 macOS 上出现两套入口、两套返回/chrome 体验。

项目当前处于 `evolve_modularity` 阶段。本变更触及 `app.dart`、macOS menu command seam、settings window target routing 和 settings 页面二级导航，主要影响模块化清单中的 5、6、8、10；结构改善是把这些“已有 owner surface 的页面”统一收敛到 settings window target seam，并用 allowlist/guardrail 防止后续继续散落为直接 route。

## What Changes

- 扩展 `DesktopSettingsWindowTarget` 或等价 target 结构，使其支持以下 settings window 拥有的页面目标：
  - `WebDavSyncScreen`：归属 `Components` pane 内的 WebDAV nested route。
  - `ExportMemosScreen`、`ImportSourceScreen`、`LocalNetworkMigrationScreen`：归属 `Import/Export` pane 或 pane-local nested route。
  - `DesktopShortcutsOverviewScreen`：归属 settings window 内快捷键/桌面快捷键上下文。
  - `SelfRepairScreen`、`ExportLogsScreen`：归属 `Feedback` pane 内二级 route。
  - `FeedbackScreen`：归属 `Feedback` pane。
  - `ReleaseNotesScreen`：归属 `About` pane 内二级 route。
  - `macosMenuCommandQuickPrompts`：归属 `AI` pane 内可持久化的自定义 AI 模板编辑 route。
- 将对应 macOS menu commands 的主路径从 `_pushMacosMenuRoute(...)` 改为 targeted settings window routing，并保留 unsupported / failed fallback 到原页面。
- 记录并守住暂不迁移范围：`New Memo`、`Search Memos`、`Sync Queue`、`AI Reports` 暂不纳入本 change。
- 增加 focused tests / architecture guardrail，确认本 change allowlist 中的 menu commands 不再以 standalone route 作为主路径，同时不阻断显式 fallback。
- 不修改 native menu label、菜单层级、API、数据库 schema、同步协议、商业/private overlay 或付费能力边界。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `macos-app-menu`: 扩展 macOS menu command routing 规则，让已有 settings window owner surface 的页面优先进入对应 settings window target，而不是直接 push 主窗口 standalone page。
- `macos-settings-window`: 扩展 settings window target routing，支持更多 top-level pane 和 pane-local nested page 目标，并保持 fallback 语义。

## Impact

- Affected code: `memos_flutter_app/lib/app.dart`, `memos_flutter_app/lib/application/desktop/desktop_settings_window.dart`, `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`, focused settings window/menu tests 和 architecture guardrails。
- Affected specs: `openspec/specs/macos-app-menu/spec.md`, `openspec/specs/macos-settings-window/spec.md`。
- 不涉及 API、数据模型、同步协议、商业/private overlay、StoreKit、subscription、entitlement、receipt、paywall 或 `AccessDecision.source` 业务分支。
