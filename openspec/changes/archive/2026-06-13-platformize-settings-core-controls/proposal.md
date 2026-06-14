## Why

iPhone 真机日志已经证明设置页仍有 Material-only 控件被直接放进 `CupertinoListSection` / `CupertinoListTile`，例如 `LocationSettingsScreen` 的 `ChoiceChip` 触发 `No Material widget found`。此前 `SettingsMenuRow<T>` 只解决了 dropdown 一类问题；如果不先补齐通用设置控件 seam，后续每个子页面都会继续用局部补丁，问题会反复出现。

当前架构阶段是 `evolve_modularity`，本变更触及 `settings` 这个 coupled area。修复必须让 touched area equal or better structured：把 chip、single-choice、multi-choice、button、dialog、feedback 等设置控件意图集中到 settings/platform seam，而不是让子页面继续散落 Material/Cupertino 假设。

## What Changes

- 为设置页补齐通用平台化控件：选择标签/分段选择、单选、多选、动作按钮、确认弹窗、轻量反馈、加载/进度展示。
- 让 Apple mobile 设置页中的设置控件不依赖偶然存在的 `Material` ancestor，避免 `No Material widget found`。
- 明确 `PlatformPrimaryAction` / `SettingsAction` 在 iPhone/iPadOS 上应渲染 Apple-safe action，而不是只包装 Material buttons。
- 明确 settings semantic components 负责表达配置意图；页面只传入 label、value、options、onChanged、action variant。
- 添加或收紧 iOS widget tests，覆盖核心 settings 控件在 `TargetPlatform.iOS` 下可渲染、可交互、无 Flutter framework exception。
- 不迁移所有具体设置子页面；具体页面替换留给 `platformize-settings-subpages`。
- 不修改 Memos API、request/response models、version compatibility、数据库 schema、WebDAV 协议、private hooks 或任何商业能力边界。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 明确 settings semantic control seam 必须覆盖 chip、single-choice、multi-choice、actions、dialogs、feedback、loading/progress 等高频设置控件。
- `apple-platform-ui-adaptation`: 明确 Apple mobile 设置控件必须 Apple-safe，不得在 Cupertino 设置容器内直接依赖 Material-only 控件。

## Impact

- 预计修改：
  - `memos_flutter_app/lib/features/settings/settings_ui.dart`
  - `memos_flutter_app/lib/platform/widgets/platform_controls.dart`
  - `memos_flutter_app/lib/platform/widgets/platform_primary_action.dart`
  - `memos_flutter_app/lib/platform/widgets/platform_dialog.dart`
  - 可能新增少量 `platform/widgets/*` 或 settings-owned helper。
- 预计补充或调整：
  - `memos_flutter_app/test/features/settings/settings_ui_semantic_components_test.dart`
  - 平台控件相关 widget tests 或 architecture guardrail tests。
- 本 change 不触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、WebDAV 协议、数据库 schema 或 private hooks。
- 本 change 不引入 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。
