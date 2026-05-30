## Why

`standardize-desktop-secondary-task-dialogs` 已经把 Collections 的创建、编辑和管理条目流程迁移到共享桌面任务表面，证明了这一模式可以避免桌面端普通 `Scaffold + AppBar` 二级页面进入 macOS 窗口按钮区域，也能让短任务的关闭、取消和完成语义更清楚。

设置相关页面里仍有一些短任务继续以完整页面方式打开。最明显的是 `ShortcutEditorScreen` 和 `AiServiceWizardScreen`：它们都有明确的完成/取消边界，桌面端继续 push 完整页面会把任务语义和页面返回语义混在一起，也让后续页面容易回退到旧的 `AppBar` 模式。

当前架构阶段为 `evolve_modularity`。本 change 触及 settings 和 memos route delegate 这类耦合区域，应复用现有 `PlatformSecondaryTaskSurface` seam，并增加防回退检查，避免已迁移的 settings 任务流程重新直接 push 页面级 `Scaffold + AppBar`。

## What Changes

- 为快捷方式编辑新增统一入口，例如 `openShortcutEditor(...)`：桌面端使用共享任务表面，移动端保留现有 route 体验。
- 迁移 `ShortcutsSettingsScreen` 和 memo 标题菜单中的创建快捷方式入口，使它们通过统一入口打开快捷方式编辑任务。
- 为 AI 服务新增向导新增统一入口，例如 `openAiServiceWizard(...)`：桌面端使用共享任务表面，移动端保留现有 route 体验。
- 迁移 `AiSettingsScreen` 中的添加服务入口，使桌面端不再直接 push `AiServiceWizardScreen`。
- AI 向导中的代理设置入口先保持现状，不在本 change 中把 `AiProxySettingsScreen` 迁移为嵌套任务表面。
- 增加 guardrail 或 focused test，防止已迁移的 settings 任务流程回退为直接 push 页面级 `Scaffold + AppBar`。
- 不在本 change 中迁移 `AiServiceDetailScreen`。它由第二阶段 change `migrate-ai-service-detail-task-surface` 单独处理。

## Capabilities

### Modified Capabilities

- `desktop-secondary-task-surfaces`: 补充 settings 任务型二级流程的桌面任务表面要求，覆盖快捷方式编辑、AI 服务新增向导，以及已迁移 settings 任务流程的防回退检查。

## Impact

- Affected app files:
  - `memos_flutter_app/lib/features/settings/shortcut_editor_screen.dart`
  - `memos_flutter_app/lib/features/settings/shortcuts_settings_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_route_delegate.dart`
  - `memos_flutter_app/lib/features/settings/ai_service_wizard_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_settings_screen.dart`
- Affected tests / guardrails:
  - settings/AI widget tests
  - platform secondary task surface tests if API gaps are found
  - desktop window chrome / secondary task surface guardrail
- Out of scope:
  - `AiServiceDetailScreen`
  - `AiProxySettingsScreen` migration
  - export/import, reminder editor, location picker, camera capture
  - API code under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api`
  - subscription, billing, entitlement, paywall, StoreKit, private overlay, or other commercial behavior
