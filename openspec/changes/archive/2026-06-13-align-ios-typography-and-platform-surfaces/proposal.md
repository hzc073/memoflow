## Why

iOS 当前已经有部分 Apple shell、route、list、picker 与 bottom navigation 适配，但全局 typography 仍由 `MaterialApp`、应用字体偏好、固定行高和固定 `TextScaler` 驱动，导致 iPhone/iPadOS 上可能出现“像 Apple 又不像 Apple”的字体和界面观感。这个问题现在需要单独收敛，因为继续局部迁移平台控件会放大 typography、无效字体选择和平台 surface 规则不一致带来的视觉割裂。

当前架构阶段是 `evolve_modularity`，本变更触及 `app.dart` composition root、`core/app_theme.dart`、`platform/` Apple UI seam 和 settings pilot area。相关模块化清单项主要是 `5.` composition root 职责、`6.` 平台协作通过 seam 表达、`8.` guardrail coverage、`10.` touched area equal or better structured。实现应通过集中化的 iOS typography/platform policy 或现有 platform/settings seams 收敛行为，而不是在 feature pages 散落新的 `TargetPlatform.iOS` 分支。

## What Changes

- iOS/iPadOS 的 effective app typography SHALL default to platform system font，即使设备偏好或迁移数据中存在来自其他平台的 `fontFamily` / `fontFile`。
- iOS/iPadOS SHALL not present a misleading system-font picker that can only return an empty list; settings 字体入口应隐藏、禁用或明确显示系统默认，并保留其他平台现有字体选择行为。
- iOS/iPadOS SHALL preserve platform text scaling semantics instead of unconditionally replacing system `MediaQuery.textScaler` with only app-level small/standard/large scale.
- 全局 UI chrome 的行高策略 SHALL avoid forcing reader-oriented line height onto Apple shell/list/button/text chrome; reader/body content preferences may continue to use user-selected line height where appropriate.
- Apple platform surface rules SHALL be documented so future high-perception iOS UI work knows which behavior belongs in `platform/` or settings seams and which MemoFlow brand surfaces may remain shared.
- 增加 focused tests/guardrails 覆盖 iOS effective typography、无效字体入口、text scaling 和 platform seam dependency direction。
- 不引入内置应用字体，不增加新第三方依赖，不触碰 API route/version compatibility、request/response model、`memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `apple-platform-ui-adaptation`: 明确 Apple mobile typography、字体偏好、text scaling、line height 和 high-perception surface 的平台规则。
- `platform-adaptive-ui-system`: 明确 adaptive UI system 必须通过 centralized policy/seams 表达平台 typography 与 settings 字体入口行为，避免 feature-local 平台分支和无效 controls。

## Impact

- 预计影响 `memos_flutter_app/lib/app.dart` 的 `MediaQuery.textScaler` 组合策略。
- 预计影响 `memos_flutter_app/lib/core/app_theme.dart` 或新增/调整稳定的 typography policy seam，用于解析 effective `fontFamily`、`fontFile`、fallback 和 line-height scope。
- 预计影响 `memos_flutter_app/lib/features/settings/preferences_settings_screen.dart` 或 settings semantic seam，使 iOS 上字体入口不再呈现无效系统字体列表。
- 可能影响 `memos_flutter_app/lib/platform/shells/apple_shells.dart`、`memos_flutter_app/lib/platform/platform_experience.dart` 或相关 platform UI adapters，用于承载 Apple typography/surface decision。
- 预计补充 focused widget/unit tests，例如 `test/platform/...`、`test/features/settings/...`、`test/core/...`，并运行 `flutter analyze` 与 focused tests。
- Public/private split 不变；本变更不得添加 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
