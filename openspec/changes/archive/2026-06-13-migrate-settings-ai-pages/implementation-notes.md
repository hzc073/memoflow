## Summary

本批完成 AI settings visual seam migration。运行时代码只触碰 `memos_flutter_app/lib/features/settings` 中的 AI settings screens、`settings_ui.dart` 的窄通用参数扩展，以及对应 focused test / drift guardrail。未修改 API files、AI HTTP adapter behavior、数据库 schema、private hooks、commercial logic 或 `add-ai-summary-history`。

## Runtime Changes

- `AiSettingsScreen` root 迁移到 `SettingsPage`，profile/proxy entry 使用 `SettingsNavigationRow`，service empty state 使用 `SettingsInfoRow`，service enable switch 使用 `PlatformSwitch`。
- `AiProxySettingsScreen` root 迁移到 `SettingsPage`，protocol selector、input rows、bypass toggle、test action 和 result row 使用 settings seams；保留 save、clear、validation 和 proxy test behavior。
- `AiRouteSettingsScreen` route cards 迁移到 `SettingsValueRow`，保留 Windows adaptive picker anchor 和 binding replacement behavior。
- `AiProviderSettingsScreen` 与 `AiUserProfileScreen` root/save surface 迁移到 settings seams，保留 controllers、dirty state、model picker 和 save behavior。
- `AiServiceDetailScreen` 普通 route 使用 `SettingsPage`，embedded task surface 继续使用 `PlatformSecondaryTaskFrame`，service section/action helper 改用 `settingsPageTokens`。
- `AiServiceModelScreen` 普通 route 使用 `SettingsPage`，panel colors 改用 `settingsPageTokens`。
- `AiServiceWizardScreen` page shell 改用 `PlatformPage`，背景使用 `settingsPageTokens`，保留 Stepper flow 和 desktop secondary task surface。
- `settings_ui.dart` 给 `SettingsInputRow` 增加 `suffixIcon`、`minLines`、`maxLines`，给 `SettingsWarningRow` 增加可选 `iconColor`。

## Guardrails

- `settings_ui_drift_guardrail_test.dart` 已将以下 files 从 `legacyAllowlist` 移入 `migratedFiles`：
  - `ai_provider_logo.dart`
  - `ai_provider_settings_screen.dart`
  - `ai_proxy_settings_screen.dart`
  - `ai_route_settings_screen.dart`
  - `ai_service_detail_screen.dart`
  - `ai_service_model_screen.dart`
  - `ai_service_wizard_screen.dart`
  - `ai_settings_screen.dart`
  - `ai_user_profile_screen.dart`
- 剩余 allowlist 只保留 `desktop_settings_window_app.dart` 和 `desktop_shortcuts_overview_screen.dart`，它们属于 desktop routing / shortcut overview follow-up，不是 AI settings visual migration 未完成项。
- In-scope AI settings files 已用 guardrail pattern 扫描，未命中 direct `return Scaffold`、direct `MemoFlowPalette`、page-local `styleFrom`、bare `Switch` / `Switch.adaptive` 或 private `_ToggleCard`。
- 商业/private/history 关键词扫描未命中 `billing`、`subscription`、`entitlement`、`StoreKit`、`receipt`、`paywall`、`productId`、`AccessDecision.source` 或 `AppCapability.aiSummaryHistory`。

## Verification

- `openspec validate migrate-settings-ai-pages --strict` passed.
- `flutter test test/features/settings/ai_settings_screen_test.dart test/features/settings/ai_proxy_settings_screen_test.dart test/features/settings/ai_service_wizard_screen_test.dart --reporter expanded` passed.
- `flutter test test/features/settings/settings_ui_semantic_components_test.dart --reporter expanded` passed.
- `flutter test test/architecture/settings_ui_drift_guardrail_test.dart test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded` passed.
- `flutter analyze` passed.

## Remaining Risk

- Full `flutter test` was not run in this pass; scoped AI/settings/architecture coverage passed.
- `desktop_settings_window_app.dart` and `desktop_shortcuts_overview_screen.dart` remain deliberately allowlisted for separate desktop follow-up work.
