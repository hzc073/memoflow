## Why

Settings UI 整改的大部分页面已经迁移到 `SettingsPage`、`SettingsSection`、`SettingsToggleRow` 和相关 semantic seams，但 AI settings 相关页面仍保留在 `settings_ui_drift_guardrail_test.dart` 的 `legacyAllowlist` 中。当前剩余 AI 页面仍有 direct `Scaffold`、direct `MemoFlowPalette`、page-local card/row styling、bare adaptive switches 和 page-local button styling，和已迁移的 settings 体验不一致。

本 change 只收敛已有 AI 设置页的 UI seam 和 drift guardrail，不实现 `add-ai-summary-history` 的产品能力，不新增商业、订阅、StoreKit、entitlement 或 private overlay 行为。

## What Changes

- 将 AI settings 入口、proxy、route、legacy provider/profile、service detail/model/wizard 等已有 AI 设置页面迁移到 settings semantic UI seam 或等价 settings/platform seam。
- 保留现有 AI settings provider、repository、model、route binding、proxy test、service validation、model discovery、wizard create flow、desktop secondary task surface 和 fallback routing 行为。
- 更新 `settings_ui_drift_guardrail_test.dart`，把完成迁移的 AI settings files 从 `legacyAllowlist` 移入 `migratedFiles`，并防止重新引入 direct visual drift。
- 增加或更新 focused widget/source tests，覆盖 AI settings 入口、proxy form、route selection surface、service list/detail/model/wizard 的关键 settings seam 和行为不变点。

## Non-Goals

- 不实现 AI 总结历史、额度、搜索、rerun、history persistence 或 `AppCapability.aiSummaryHistory` gating。
- 不修改 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、AI provider HTTP adapters、数据库 schema 或 network protocol。
- 不新增 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
- 不重写 AI settings 信息架构；本次只做 existing screens 的 settings UI seam 迁移。
- 不迁移非 AI 的 `desktop_shortcuts_overview_screen.dart`；它应由 desktop shortcuts follow-up 单独处理。

## Impact

- Affected runtime files:
  - `memos_flutter_app/lib/features/settings/ai_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_proxy_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_route_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_provider_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_user_profile_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_service_detail_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_service_model_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_service_wizard_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_provider_logo.dart` if guardrail tracking requires it
- Affected tests:
  - `memos_flutter_app/test/architecture/settings_ui_drift_guardrail_test.dart`
  - Focused settings widget tests for AI settings pages.
- Capability delta:
  - `platform-adaptive-ui-system`: AI settings pages SHALL use settings semantic seams and SHALL leave product behavior unchanged.
