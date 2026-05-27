## Why

当前设置入口和页面仍以 `Windows related settings` / `WindowsRelatedSettingsScreen` 为中心，但页面内已经包含跨桌面意图（例如桌面快捷键），并且独立桌面设置窗口也会把该入口呈现为 Windows 专属项。用户需要一个名为“桌面设置”的设置面板，按当前桌面平台加载可用内容，避免把跨平台桌面能力继续隐藏在 Windows 命名和 Windows-only gate 后面。

项目当前处于 `evolve_modularity` 阶段。本变更触及 settings 这一耦合热点，并主要影响模块化清单中的 4（共享 UI/平台逻辑不应继续藏在页面本地私有实现）、6（通过 settings/adaptive seams 组合平台差异）、8（guardrail 防止设置 UI 继续漂移）和 10（触及区域必须保持结构不变或更好）。

## What Changes

- 将 Windows 专属设置入口泛化为“桌面设置”，用于承载共享桌面设置和平台专属设置。
- 在桌面设置页内按平台分段展示内容：
  - 共享桌面分段：承载 Windows/macOS 都适用的桌面能力，例如桌面快捷键设置。
  - Windows 分段：保留 `windowsCloseToTray` 等 Windows 专属行为。
  - macOS 分段：仅展示已支持的 macOS 桌面设置；没有可配置项时不伪造功能。
  - Linux 分段：保持当前未适配状态，展示受支持范围或暂未适配提示，不把 Linux 当成完整支持平台。
- 主设置页和独立桌面设置窗口都使用同一个桌面设置语义入口和一致命名，不再硬编码 `Windows related settings` / `Windows settings`。
- 桌面设置页迁移到现有 `SettingsPage`、`SettingsSection`、`SettingsNavigationRow`、`SettingsToggleRow` 等 settings UI seams，移除页面本地 Scaffold、palette、group row 和 switch 样式漂移。
- 更新 i18n 文案：新增或替换桌面设置相关 key；保留确实描述 Windows 系统权限或 Windows 行为的既有 Windows 文案。
- 收紧 settings UI drift guardrail，让迁移后的桌面设置页不再留在 legacy allowlist。
- 不在本 change 中整改其他未迁移设置项；其他设置项 UI/样式整改单独创建后续 change。

## Capabilities

### New Capabilities
- `desktop-settings-platform-sections`: 定义“桌面设置”入口、平台分段、跨入口一致性、Linux 未适配 fallback，以及 settings UI seam 使用要求。

### Modified Capabilities
- `platform-adaptive-ui-system`: 补充设置页迁移时的桌面平台分段和 platform capability gating 规则，要求跨桌面意图通过共享 settings/adaptive seams 表达，而不是散落在 Windows-only 页面树中。

## Impact

- Affected app files: `memos_flutter_app/lib/features/settings/windows_related_settings_screen.dart`（重命名、替换或保留兼容 wrapper）、`settings_screen.dart`、`desktop_settings_window_app.dart`、`desktop_shortcuts_settings_screen.dart`、`settings_ui.dart`。
- Affected state: 继续使用现有 `devicePreferencesProvider` / `DevicePreferences`；不引入新的业务状态 owner，不改变 `windowsCloseToTray` 的 Windows 专属语义。
- Affected localization: `memos_flutter_app/lib/i18n/*.yaml` 和生成的 `strings.g.dart`。
- Affected tests/guardrails: settings UI drift guardrail、桌面设置显示/平台分段 widget tests、必要的桌面设置窗口入口测试。
- Public/private boundary: 不引入订阅、付费、StoreKit、entitlement、private overlay 或 `AccessDecision.source` 业务分支。
