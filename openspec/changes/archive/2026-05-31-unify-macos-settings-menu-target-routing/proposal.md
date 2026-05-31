## Why

macOS 菜单中有多项“设置类”命令仍直接 push 独立页面，例如 `AI Provider`、`Shortcut Settings`、`Template Settings`、`Memo Toolbar Settings`、`Location Settings`、`Image Bed Settings` 和 `Image Compression`。这些页面在主窗口普通 route 中呈现时，会绕过 `DesktopSettingsWindowApp` 的桌面设置外壳，导致同一设置内容从菜单进入和从桌面设置窗口进入时视觉、导航和 macOS titlebar/chrome 行为不一致。

`route-macos-ai-settings-to-settings-pane` 先为 `AI Settings` 建立目标化 settings window routing。本 change 在该机制稳定后，扫描其他设置类 macOS 菜单项和 settings 页面入口，按同一模式迁移明确属于设置的页面，避免继续新增直接 push 根设置页的入口。

项目当前处于 `evolve_modularity` 阶段。本变更触及 `app.dart`、settings window、settings 页面和 macOS menu 导航热点，主要影响模块化清单中的 5、6、8、10。结构改善是用统一 target routing seam 管理设置类目的地，并通过扫描清单和 guardrail 防止 settings-like 菜单继续散落为 page-local pushes。

## What Changes

- 扫描 macOS 菜单、settings root、components/preferences/desktop settings 内的设置页面入口，形成可 review 的迁移清单。
- 在目标化 settings window routing 中增加其他 settings-like targets，例如 `aiProvider`、`desktopShortcuts`、`templates`、`memoToolbar`、`location`、`imageBed`、`imageCompression`。
- 让 macOS 菜单中的设置类命令优先打开 settings window 并定位到相应 pane 或 pane 内二级页。
- 保留失败 fallback，确保 settings window 不可用时仍能打开原页面。
- 明确不把业务功能、任务型流程或诊断工具误迁入 settings window。
- 增加测试和 guardrail，检查被迁移的 settings-like menu commands 不再直接 push standalone settings pages 作为主路径。

## Capabilities

### Modified Capabilities

- `macos-app-menu`: 将设置类 MemoFlow 菜单命令统一路由到目标化 settings window，而非默认直接 push 主窗口页面。
- `macos-settings-window`: 扩展 settings window target routing，支持 pane 内二级页目标和已有窗口目标切换。

## Impact

- Affected app files: `memos_flutter_app/lib/app.dart`, `memos_flutter_app/lib/application/desktop/desktop_settings_window.dart`, `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`, `memos_flutter_app/lib/core/desktop_quick_input_channel.dart`, and selected settings pages used as target destinations.
- Affected active change: `generalize-desktop-settings-platform-sections` overlaps on desktop settings / shortcut settings naming and should be coordinated before implementing shortcut-related target routing.
- Affected tests/guardrails: macOS menu routing guardrails, settings window target tests, focused widget tests for pane and nested route selection.
- Public/private boundary: 不引入订阅、付费、StoreKit、entitlement、receipt、paywall、private overlay 或 `AccessDecision.source` 业务分支。
- Out of scope: 不迁移 `AI Summary`、`AI Reports`、`Quick Prompts`、`Self Repair`、`Export Diagnostics`、Import/Export workflows 或其他非设置类业务流程。
