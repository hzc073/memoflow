## Why

当前 memo 点赞/评论展示由多个入口分别决定：home memo cards 基本尊重 `showEngagementInAllMemoDetails` 偏好，`MemoDetailScreen` 会使用 `widget.showEngagement || showEngagementInAllMemoDetails`，desktop preview pane 直接传入 `shouldShowEngagement: true`。这导致同一个用户偏好无法统一控制点赞和评论展示，也让本地库模式可能挂载 `MemoEngagementSurface` 并触发 remote engagement loading。

用户期望本地模式不支持展示点赞/评论；服务端工作区中，偏好设置里的单一开关应统一控制所有 memo engagement surfaces。这个 change 固定规则和命名方向，避免后续实现继续出现绕过偏好的强制显示入口。

## What Changes

- 本地库模式 SHALL 不支持点赞/评论展示：home cards、desktop preview pane、memo detail、desktop reader surface、explore/notification detail 等入口均不得展示或挂载 memo engagement surface。
- 服务端工作区 SHALL 使用一个统一 effective gate 控制点赞/评论展示；所有支持 engagement 的 surface 必须尊重该 gate，不得通过 `showEngagement: true` 或 `shouldShowEngagement: true` 绕过偏好。
- 偏好设置的用户可见名称 SHALL 改为更通用的“显示点赞与评论”（英文建议为 `Show likes and comments`），不再限定为“home cards and memo details”。
- 新代码命名 SHOULD 收敛到 `showMemoEngagement` / `effectiveShowMemoEngagement` 语义；旧存储 key `showEngagementInAllMemoDetails` MAY 暂时保留读取兼容，避免现有用户偏好丢失。
- memo engagement display gate SHALL 停留在 UI/provider seam，不修改 Memos server API、request/response models、route adapters、version compatibility logic 或 `memos_flutter_app/lib/data/api`。
- 增加 focused widget tests / architecture guardrail，覆盖本地模式不挂载 engagement surface、服务端模式统一尊重偏好、以及不存在强制显示绕过点。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `home-memo-engagement`: 扩展 engagement preference 的作用范围，从 home/detail 规则收敛为所有 memo engagement surfaces 的统一 gate，并增加本地模式不支持展示的要求。

## Impact

- Affected code:
  - `memos_flutter_app/lib/data/models/workspace_preferences.dart`
  - `memos_flutter_app/lib/data/models/app_preferences.dart`
  - `memos_flutter_app/lib/data/models/resolved_app_settings.dart`
  - `memos_flutter_app/lib/state/settings/workspace_preferences_provider.dart`
  - `memos_flutter_app/lib/features/settings/preferences_settings_screen.dart`
  - `memos_flutter_app/lib/i18n/*.i18n.yaml`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card_container.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_desktop_preview_pane.dart`
  - `memos_flutter_app/lib/features/memos/memo_detail_screen.dart`
  - `memos_flutter_app/lib/features/memos/desktop_memo_reader_surface.dart`
  - 可能涉及 `memos_flutter_app/lib/features/explore/explore_screen.dart`、`memos_flutter_app/lib/features/notifications/notifications_screen.dart` 中的 read-only detail entry
- Affected tests:
  - `memos_flutter_app/test/features/memos/memo_engagement_surface_test.dart`
  - `memos_flutter_app/test/features/memos/memo_detail_screen_test.dart`
  - `memos_flutter_app/test/features/memos/memos_list_screen_test.dart`
  - 可能新增 desktop preview pane 或 focused harness tests
  - `memos_flutter_app/test/i18n/engagement_preference_localization_test.dart`
  - `memos_flutter_app/test/architecture/memo_engagement_provider_guardrail_test.dart` 或新增 focused guardrail
- 不修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，因此不触发 API route/version compatibility 编辑。
- Architecture phase: `evolve_modularity`.
- Modularity checklist impact:
  - 触及 checklist `4`、`8`、`10`：当前 engagement display decision 分散在 widget/screen files，本 change MUST 通过 focused effective gate 或等价 seam 让 touched area equal or better structured，并用 tests/guardrail 阻止绕过偏好回流。
  - 不得引入新的 `state -> features`、`application -> features` 或 `core -> state|application|features` dependencies。
  - 不得新增 subscription、billing、entitlement、receipt、paywall、StoreKit、private overlay 或 paid-feature branching logic。
