## Why

手机端设置首页在上一轮 `enhance-mobile-settings-home-hierarchy` 中建立了 profile card、quick shortcut tiles 和 grouped function sections 的层级，但当前普通功能行和分组间距偏高，导致首屏信息密度不足。用户反馈截图中的设置行容器太高，希望先按已确认的第一版收紧方案处理。

本 change 聚焦设置首页手机端密度微调：保留现有分层卡片、分组列表和导航行为，只降低普通功能入口行高、快捷卡片高度、分组间距和 profile 内边距。不重做信息架构，不影响二级/三级设置页。

## What Changes

- 手机端设置首页普通单行功能入口使用 home-only compact row treatment，目标单行高度为 48 logical pixels；带描述、多行内容或无障碍文本放大时 MAY 自然增高。
- 手机端设置首页 home hierarchy token 第一版数值调整为：
  - 普通功能行目标高度：48
  - quick shortcut tile height：80
  - section spacing：12
  - profile padding：16
- 保留 grouped card + row divider 模型；普通功能入口不会被拆成独立卡片。
- home-only density 值继续由 `settings_ui.dart` / settings-owned seam 或 approved platform seam 集中解析，避免在 `settings_screen.dart` 写局部 padding、高度或视觉硬编码。
- 二级/三级设置页继续使用标准 `SettingsPage`、`SettingsSection` 和 settings row surface，不继承首页 compact treatment。
- 增加 focused widget tests / guardrail 覆盖，锁定手机端设置首页密度范围，并确认 desktop 和普通 settings 页面不受影响。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 增加手机端设置首页 compact density 要求，明确第一版数值、home-only 范围、二级/三级页面隔离和 guardrail 覆盖。

## Impact

- Affected code:
  - `memos_flutter_app/lib/features/settings/settings_ui.dart`
  - 可能涉及 `memos_flutter_app/lib/platform/widgets/platform_list_section.dart`，仅用于承载 semantic row density seam；不得新增 `platform/` 对 `features/*` 的依赖。
  - `memos_flutter_app/lib/features/settings/settings_screen.dart` 只应在必要时接入 semantic seam，不应写 page-local height/padding/radius/shadow 值。
- Affected tests:
  - `memos_flutter_app/test/features/settings/settings_ui_semantic_components_test.dart`
  - `memos_flutter_app/test/features/settings/settings_screen_test.dart`
  - `memos_flutter_app/test/platform/platform_ui_test.dart` 或等价 platform row seam focused tests
  - `memos_flutter_app/test/architecture/settings_ui_drift_guardrail_test.dart`
- Architecture phase: `evolve_modularity`.
- Modularity checklist impact:
  - 触及 checklist `8`、`10`：settings UI 是 coupled area，本 change MUST 通过 home-only density tokens/seam 和 focused tests/guardrail 防止设置首页视觉值重新散落到 page-local code。
  - 不触及 API、数据模型、数据库、同步协议、AI provider、private hooks 或商业逻辑。
  - 不得引入新的 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖。
