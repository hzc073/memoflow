## Context

`coordinate-settings-ui-migration-batches` 将 AI settings 从普通 settings visual 批次中延后，原因是它与 desktop settings routing 和其他 active AI work 交叠。后续批次已经迁移 WebDAV、account/server、security、navigation、import/export、local migration、utility、shortcut/toolbar 等 settings pages，并通过 `settings_ui_drift_guardrail_test.dart` 收紧 drift 保护。

现在剩余 legacy allowlist 主要集中在 AI settings files 与 desktop routing/shortcut overview files。`route-macos-ai-settings-to-settings-pane` 已完成菜单到 AI pane 的目标化路由，但它明确不重构 `AiSettingsScreen` 页面布局，也不迁移 AI provider/model/wizard/profile/proxy 等页面。本 change 补齐 AI settings visual seam 迁移。

当前架构阶段为 `evolve_modularity`。本 change 触碰 `features/settings` 的 coupled area，必须减少 screen-local reusable visual logic 或收紧 guardrail，不能新增 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖。

## Decisions

### Decision 1: AI settings 迁移只覆盖 existing settings UI，不实现 AI history

本 change 迁移已有 AI settings screens 的页面 chrome、section、row、toggle、input、action 和 empty state visual seams。`add-ai-summary-history` 仍是独立 active change，产品规则和 capability gating 未确认前不在这里实现。

Rationale: 用户指出的 “AI 部分未完成” 在 settings UI 整改语境下指 AI settings files 仍在 `legacyAllowlist`。AI summary history 是另一个产品能力，混入会扩大商业/capability 风险。

### Decision 2: 复用 `settings_ui.dart`，只做窄扩展

优先使用现有 `SettingsPage`、`SettingsSection`、`SettingsNavigationRow`、`SettingsValueRow`、`SettingsToggleRow`、`SettingsInfoRow`、`SettingsWarningRow`、`SettingsInputRow`、`SettingsMenuRow`、`SettingsAction` 和 `settingsPageTokens`。若 AI 页面需要 service card、action row、status badge、inline panel 等表达，可以新增小型通用 settings seam，但不能把 AI provider domain concept 硬塞进 shared UI。

Rationale: 已迁移 settings pages 的一致性来自 settings-owned semantic seams，而不是每个 screen 自己复制 card/palette/shadow。

### Decision 3: 保留 AI 行为 owner 和 desktop secondary surface

AI settings screens 继续读取和写入现有 `aiSettingsProvider`，保持 provider/repository owner 不变。`AiServiceDetailScreen` 和 `AiServiceWizardScreen` 的 desktop secondary task surface、unsaved close、service validation、model discovery 和 proxy test behavior SHALL remain unchanged。

Rationale: 本次是 visual seam migration；行为 owner 改动会让验证面扩大，并可能触碰 API/network/private boundary。

### Decision 4: Guardrail 完成标准按文件收敛

完成后，in-scope AI settings files SHALL move from `legacyAllowlist` to `migratedFiles`。这些文件不应再命中 direct `return Scaffold`、direct `MemoFlowPalette`、page-local `styleFrom`、bare `Switch` / `Switch.adaptive`、private `_ToggleCard` drift patterns。

`desktop_settings_window_app.dart` 和 `desktop_shortcuts_overview_screen.dart` 不属于本 change。前者是 desktop workbench/routing shell，后者是 shortcut overview；若仍保留 allowlist，需要在最终状态中明确它们不是 AI settings visual migration 的未完成项。

## Risks / Trade-offs

- [Risk] AI service detail/model/wizard 文件体量大，视觉迁移可能改变 validation、sync、wizard step 或 unsaved close behavior。Mitigation: 保持 controllers/provider calls/route calls 原样，只替换 outer chrome 和 reusable visual wrappers。
- [Risk] 迁移所有 AI files 会导致 guardrail 暴露同 file 内 dialog/card helper drift。Mitigation: 文件级扫描前先清理 direct palette/style/switch patterns，必要时将 reusable helpers改为 settings/theme tokens。
- [Risk] AI summary history 被误实现。Mitigation: tasks 和 tests 明确不触碰 `AppCapability.aiSummaryHistory` 或 history persistence。
- [Risk] commercial/private leakage。Mitigation: focused source guardrail 检查 touched public files 不包含 high-confidence commercial terms 或 `AccessDecision.source` business branching。

## Migration Plan

1. 在 `settings_ui.dart` 中确认现有 seam 是否足够；只在必要时增加通用 visual wrapper。
2. 迁移轻量 AI pages：`AiSettingsScreen`、`AiProxySettingsScreen`、`AiRouteSettingsScreen`、`AiUserProfileScreen`、legacy `AiProviderSettingsScreen`。
3. 迁移重型 AI pages：`AiServiceDetailScreen`、`AiServiceModelScreen`、`AiServiceWizardScreen`，保留 embedded task surface 行为。
4. 更新 `settings_ui_drift_guardrail_test.dart`，将 AI settings files 移入 `migratedFiles`，非本 change desktop files 继续 allowlist。
5. 增加 focused widget/source tests，运行 OpenSpec validate、settings drift guardrail、modularity guardrail、focused AI settings tests 和 `flutter analyze`。

## Open Questions

- `ai_provider_logo.dart` 没有 page-level visual drift，但 guardrail 以 file 为单位 tracking；实现时可将其移入 `migratedFiles`，保持无 runtime change。
- `desktop_settings_window_app.dart` 渲染 AI pane 但不是 AI settings page；本 change 默认不迁移它，除非 implementation 发现 guardrail tracking 必须调整。
