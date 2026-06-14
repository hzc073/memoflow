## Implementation Notes

### 2026-06-07 UX decisions

- stats embedded header：desktop home utility stats 使用局部内容 header，包含 Back 与 Share actions；stats dashboard body 在 embedded presentation 下省略重复标题，让 homepage shell 继续拥有 desktop chrome。
- 日期过滤清除 affordance：desktop drawer heatmap 日期选择表现为 memo list header 中的 local home filter chip；清除 chip 会回到全部笔记，不重建 route。
- primary-column utility swap motion：stats、sync queue、notifications、draft box 继续作为 homepage route 内的 primary-column content override，不叠加 standalone route transition；若有内容级 motion，应保持轻量并由现有 home shell/body 承载。
- fallback scope：mobile、embedded navigation host、standalone `/memos/day` route 保持 route-based 行为，除非 desktop home host 显式提供 local day selection callback。

### 2026-06-07 Verification

- `dart format` 覆盖本 change 触及的 runtime/test Dart files，结果为 `0 changed`。
- `flutter analyze` 通过，结果为 `No issues found`。
- `git diff --check` 覆盖本 change 触及的 Dart files，结果通过。
- focused verification 通过：`flutter test test/features/home/home_quick_action_navigation_test.dart test/features/home/desktop_home_inline_compose_resize_capability_test.dart test/features/home/app_drawer_tag_tree_test.dart test/features/memos/memos_list_screen_view_state_test.dart test/features/memos/memos_list_screen_test.dart test/architecture/desktop_home_utility_embedding_guardrail_test.dart --reporter expanded`。
- full verification 已运行：`flutter test --reporter expanded`。结果仍有 5 个失败，均位于本 change 未触及的既有/并行改动区域：
  - `test/architecture/ios_public_shell_guardrail_test.dart`：`ios/Runner.xcodeproj/project.pbxproj: DEVELOPMENT_TEAM` guardrail 命中。
  - `test/private_hooks/app_ready_hook_test.dart`：`DesktopQuickInputController.unregisterHotKey` 在 widget disposed 后使用 `ref`。
  - `test/features/onboarding/platform_adaptive_onboarding_test.dart`：`local workspace setup keeps mobile actions full width` 期望宽度 `358`、实际 `326.0`。
  - `test/features/home/home_bottom_nav_shell_test.dart`：`opening about from shell preserves bottom navigation on back` 出现 About 页面 vertical overflow。
  - `test/features/home/home_bottom_nav_shell_test.dart`：`standalone about back returns to HomeEntryScreen shell` 出现同类 About 页面 vertical overflow。

### 2026-06-07 Follow-up: desktop destinations heatmap day selection

- 发现问题：全部笔记页的 AppDrawer 已通过 `onSelectDay` 使用 local day filter，但 AI summary 等 desktop destination 的 AppDrawer 没有透传该 callback，仍会 fallback 到 standalone `/memos/day` route。
- 修复决策：新增 `openDesktopHomeDayFilterDestination` / `buildDesktopHomeDayFilterDestination`，并让 `DesktopDestinationShell` 支持 `onSelectDay` 透传。支持 desktop home utility destination 的页面点击 heatmap 日期时，会 replacement 到 memo home workspace，并用 `initialDesktopHomeDayFilter` 初始化 local effective day filter。
- 覆盖范围：AI summary、daily review、notifications、tags、about、collections、explore、resources、settings、recycle bin、draft box 等 desktop drawer/destination 页面接入同一 helper；mobile、embedded navigation host 和不支持 desktop home utility 的 context 保持原 fallback。
- 追加验证：
  - `flutter analyze` 通过，结果为 `No issues found`。
  - `flutter test test/features/home/desktop_destination_shell_test.dart test/features/home/app_drawer_tag_tree_test.dart test/features/memos/memos_list_screen_test.dart test/architecture/desktop_home_utility_embedding_guardrail_test.dart --reporter expanded` 通过。
  - `flutter test test/features/review/ai_summary_screen_test.dart test/features/review/daily_review_screen_embedded_test.dart --reporter expanded` 通过。
