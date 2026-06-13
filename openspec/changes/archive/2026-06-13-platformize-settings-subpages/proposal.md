## Why

设置子页面里仍散落大量 Material-only 控件和 raw Material transient UI；真机日志已经暴露 `LocationSettingsScreen` 的 `ChoiceChip` 在 iPhone 上崩溃。仅修单个控件会继续留下同类风险，需要在通用控件 seam 准备好之后，系统性迁移设置首页及所有高风险子页面。

当前架构阶段是 `evolve_modularity`，本变更触及 `settings`、AI 设置、WebDAV 设置、迁移设置等 coupled area。修复必须让 touched area equal or better structured：页面表达设置意图，平台差异交给 settings/platform seam，减少页面内 raw Material/Cupertino 分支和重复控件逻辑。

## What Changes

- 迁移 `features/settings` 下使用 Material-only selection、chip、radio、checkbox、button、dialog、sheet、route、progress/feedback 的设置子页面，让它们复用 `platformize-settings-core-controls` 提供的 seam。
- 优先修复已知 iPhone 崩溃点：`LocationSettingsScreen` 的 precision `ChoiceChip`。
- 分批迁移热点页面：位置设置、Memo toolbar、自定义快捷方式、底部导航模式、Components、AI provider/model/detail/wizard、WebDAV、模板、快捷键、迁移、账号安全、自修复、存储空间等。
- 建立设置子页面 iOS smoke 覆盖，至少验证主要子页面在 `TargetPlatform.iOS` 下可打开且无 `No Material widget found`。
- 更新 settings UI drift guardrail 或 reviewable allowlist，防止迁移后页面重新引入高风险 Material-only 控件。
- 不修改 Memos API、request/response models、version compatibility、数据库 schema、WebDAV 协议语义、同步协议、private hooks 或商业能力边界。

## Capabilities

### New Capabilities

- `settings-subpage-platformization`: 约束设置子页面迁移范围、优先级、验收标准和 guardrail 行为。

### Modified Capabilities

- `platform-adaptive-ui-system`: 明确 migrated settings subpages 必须使用 semantic settings/platform seams，而不是 raw Material-only 控件。
- `apple-platform-ui-adaptation`: 明确 Apple mobile 设置子页面必须通过 smoke tests 或 focused tests 防止 `No Material widget found` 回归。

## Impact

- 预计修改多个 `memos_flutter_app/lib/features/settings/*.dart` 和 `memos_flutter_app/lib/features/settings/migration/*.dart` 文件。
- 预计复用或轻度调整 `settings_ui.dart`、`platform/widgets/*` 中由 `platformize-settings-core-controls` 建立的控件 seam。
- 预计补充或调整：
  - settings 子页面 iOS smoke/widget tests
  - settings UI drift guardrail 或 allowlist tests
  - 相关 focused page tests
- 本 change 不触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，除非用户另行明确批准。
- 本 change 不引入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
