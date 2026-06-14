## ADDED Requirements

### Requirement: AI settings pages SHALL use semantic settings UI seams

AI settings pages in this batch SHALL render page chrome, grouped sections, navigation rows, value rows, toggle rows, form rows, warning/info rows, service/model action rows, empty states, and save/test actions through `SettingsPage`, `SettingsSection`, `SettingsNavigationRow`, `SettingsValueRow`, `SettingsToggleRow`, `SettingsInputRow`, `SettingsMenuRow`, `SettingsInfoRow`, `SettingsWarningRow`, `SettingsAction`, `settingsPageTokens`, or equivalent settings/platform seams instead of direct page-local `Scaffold` / `MemoFlowPalette` / card styling implementations.

#### Scenario: AI settings home is migrated

- **GIVEN** the user opens `AiSettingsScreen`
- **WHEN** AI settings are rendered
- **THEN** the page SHALL use settings semantic page and section seams
- **AND** profile, proxy, add service, service detail, add model, manage service, and service enabled toggle behavior SHALL be preserved.

#### Scenario: AI proxy and route settings are migrated

- **GIVEN** the user opens `AiProxySettingsScreen` or `AiRouteSettingsScreen`
- **WHEN** the page renders forms, route rows, picker surfaces, toggles, save/test actions, or result states
- **THEN** those visible surfaces SHALL use settings semantic seams or equivalent settings/theme tokens
- **AND** proxy save/test validation and default route binding replacement behavior SHALL be preserved.

#### Scenario: AI provider and profile settings are migrated

- **GIVEN** the user opens legacy `AiProviderSettingsScreen` or `AiUserProfileScreen`
- **WHEN** form fields, model pickers, helper copy, or save actions render
- **THEN** those surfaces SHALL use settings semantic seams or equivalent settings/theme tokens
- **AND** controller synchronization, dirty state, model option editing, and save behavior SHALL be preserved.

#### Scenario: AI service management pages are migrated

- **GIVEN** the user opens `AiServiceDetailScreen`, `AiServiceModelScreen`, or `AiServiceWizardScreen`
- **WHEN** service forms, model lists, preset cards, warning rows, validation actions, sync actions, wizard steps, or destructive actions render
- **THEN** those visible surfaces SHALL use settings semantic seams or equivalent settings/theme tokens
- **AND** embedded desktop task surface, unsaved close, service validation, model discovery, model edit/delete, wizard create, route binding, proxy warning, and docs link behavior SHALL be preserved.

### Requirement: AI settings migration SHALL preserve public/private and product boundaries

AI settings UI migration SHALL NOT implement AI summary history, commercial feature gating, private overlay behavior, StoreKit behavior, subscription state, product IDs, prices, receipts, entitlements, paywalls, or `AccessDecision.source` business branching.

#### Scenario: AI summary history remains out of scope

- **GIVEN** `add-ai-summary-history` remains an active product change
- **WHEN** this AI settings UI migration is implemented
- **THEN** it SHALL NOT add history persistence, history list/detail UI, rerun behavior, quota rules, or `AppCapability.aiSummaryHistory` gating.

#### Scenario: Guardrail reflects completed AI settings migration

- **GIVEN** AI settings files have been migrated
- **WHEN** `settings_ui_drift_guardrail_test.dart` runs
- **THEN** migrated AI settings files SHALL be removed from `legacyAllowlist`
- **AND** migrated AI settings files SHALL be present in `migratedFiles`
- **AND** non-allowlisted migrated files SHALL fail architecture verification if they reintroduce direct `return Scaffold`, direct `MemoFlowPalette`, page-local `styleFrom`, bare `Switch`, `Switch.adaptive`, or private `_ToggleCard`.
