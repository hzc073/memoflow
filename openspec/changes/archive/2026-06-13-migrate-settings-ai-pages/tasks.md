## 1. 准备与边界确认

- [x] 1.1 读取当前 AI settings files、settings UI seam、总控 change、`settings_ui_drift_guardrail_test.dart` 和相关 focused tests，确认本 change 不触碰 `add-ai-summary-history` 产品能力。
- [x] 1.2 运行 `openspec validate migrate-settings-ai-pages --strict`，确认 artifacts 可 apply。
- [x] 1.3 确认本 change 不修改 API files、AI HTTP adapter behavior、数据库 schema、private hooks、commercial logic 或 `AccessDecision.source` business branching。

## 2. AI settings semantic UI migration

- [x] 2.1 将 `AiSettingsScreen` root、entry rows、service list、service enable switch、empty state 和 add service action 迁移到 settings UI seam。
- [x] 2.2 将 `AiProxySettingsScreen` form、protocol selector、toggle、test action 和 result state 迁移到 settings UI seam，保留 save/test validation behavior。
- [x] 2.3 将 `AiRouteSettingsScreen` default route rows 和 route picker surface 迁移到 settings UI seam，保留 binding replacement behavior。
- [x] 2.4 将 legacy `AiProviderSettingsScreen` 和 `AiUserProfileScreen` 迁移到 settings UI seam，保留 text controllers、dirty state、model picker 和 save behavior。
- [x] 2.5 将 `AiServiceDetailScreen`、`AiServiceModelScreen`、`AiServiceWizardScreen` 的 page chrome、sections、rows、toggles、actions 和 panels 迁移到 settings/theme seams，保留 embedded task surface、unsaved close、service validation、model sync 和 wizard create behavior。
- [x] 2.6 验证 in-scope AI settings files 不再命中 direct `Scaffold` return、direct `MemoFlowPalette`、page-local `styleFrom`、bare `Switch` / `Switch.adaptive` drift patterns。

## 3. Guardrails and tests

- [x] 3.1 更新 `settings_ui_drift_guardrail_test.dart`，将完成迁移的 AI settings files 从 `legacyAllowlist` 移入 `migratedFiles`，保留非本 change desktop files 的明确 allowlist。
- [x] 3.2 增加或更新 focused AI settings widget tests，覆盖 AI settings home、proxy form、route rows、profile/provider save surface、service detail/model/wizard 关键 seam。
- [x] 3.3 增加或更新 source/architecture guardrail，确认 public AI settings migration 未引入商业/private terms 或 dependency direction 回退。

## 4. Verification

- [x] 4.1 运行 `openspec validate migrate-settings-ai-pages --strict`。
- [x] 4.2 运行 focused AI settings widget/source tests。
- [x] 4.3 运行 `flutter test test/architecture/settings_ui_drift_guardrail_test.dart --reporter expanded`。
- [x] 4.4 运行 `flutter test test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded`。
- [x] 4.5 运行 `flutter analyze`。
- [x] 4.6 记录肉眼可见变化、保留行为、验证结果、剩余 allowlist 和风险。
