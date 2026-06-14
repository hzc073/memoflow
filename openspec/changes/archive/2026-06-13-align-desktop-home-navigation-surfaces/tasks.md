## 1. UX Decisions and Navigation Seam

- [x] 1.1 确认 stats embedded header、日期过滤清除 affordance、primary-column utility swap motion 的最终 UX 细节，并记录在 implementation notes 或对应代码注释中。
- [x] 1.2 在 home/memos navigation seam 中集中 `HomeQuickAction` 到 desktop destination / desktop utility / fallback route 的映射，避免继续在 `MemosListScreen._openHomeQuickAction` 中扩散 ad hoc `Navigator.push` 分支。
- [x] 1.3 确保 quick action availability 继续复用现有 account/local-library gating，不绕过 `AppDrawerDestination` 或 notification/explore availability rules。

## 2. Stats Desktop Utility

- [x] 2.1 扩展 `DesktopHomeUtilityView`，加入 stats utility，并更新 selected drawer destination / tag clearing 逻辑。
- [x] 2.2 在 `MemosListScreen` primary content override 中渲染 embedded stats content，确保 memo list、inline compose、desktop preview pane 在 stats utility active 时被替换。
- [x] 2.3 调整 `StatsScreen` 以支持 desktop embedded 使用场景，包括避免重复 top-level chrome，并提供 local back affordance 清除 utility state。
- [x] 2.4 将 desktop homepage 的 `HomeQuickAction.monthlyStats` 改为打开 stats utility；保留 mobile、tablet、standalone fallback 的现有 stats route 行为。

## 3. Quick Action Destination Consistency

- [x] 3.1 将 desktop homepage 的 `HomeQuickAction.aiSummary` 委托到与 `AppDrawerDestination.aiSummary` 相同的 destination navigation seam。
- [x] 3.2 将 desktop homepage 的 `HomeQuickAction.dailyReview` 委托到与 `AppDrawerDestination.dailyReview` 相同的 destination navigation seam。
- [x] 3.3 复核 `collections`、`resources`、`archived`、`notifications`、`draftBox` 等 quick actions，确保 desktop 行为与 drawer destination / utility seam 一致。
- [x] 3.4 确保同一 destination 从顶部快捷入口和侧边栏进入时具有一致 selected drawer state、titlebar ownership、back behavior 和 motion policy。

## 4. Heatmap Date Filter In Home Workspace

- [x] 4.1 为 `AppDrawer` / `_DrawerHeatmap` 增加可选 day selection callback，使 desktop home host 可以消费日期选择 intent。
- [x] 4.2 在 `MemosListScreen` 中增加 desktop home-local day filter state，并通过 `effectiveDayFilter` 参与 memo query、AI search preflight 和 header/filter presentation。
- [x] 4.3 将 desktop homepage heatmap date click 改为设置 local day filter 并关闭 drawer / overlay，而不是 `pushNamed('/memos/day')`。
- [x] 4.4 增加清除日期过滤或返回全部笔记的 affordance，并让 desktop back handling 优先清除 local day filter。
- [x] 4.5 保留非 desktop home context 和外部 `/memos/day` named route 的现有 fallback 行为。

## 5. Inline Compose Resize and Motion

- [x] 5.1 调整 `shouldEnableDesktopHomeInlineComposeResizeForMemosList` 或其调用 seam，使 desktop home-local date filter 不会仅因 `dayFilter` 语义关闭 resize。
- [x] 5.2 确认 heatmap date filter apply / clear 不清空 inline compose draft text、pending attachments、linked memos、template、location 或 visibility state。
- [x] 5.3 让 desktop primary-column utility swap 使用轻量或无 route-level animation，并确保 stats/date filter 切换不叠加页面级强动画。
- [x] 5.4 保持 unsupported desktop platform 和 mobile/tablet 的 inline compose fallback behavior 不变。

## 6. Tests and Guardrails

- [x] 6.1 增加 focused tests：desktop homepage 点击 `monthlyStats` quick action 激活 stats utility，且不 push standalone stats route。
- [x] 6.2 增加 focused tests：desktop homepage 点击 `aiSummary` / `dailyReview` quick action 与 drawer destination navigation 结果一致。
- [x] 6.3 增加 focused tests：desktop heatmap date selection 设置 local effective day filter，且不调用 `/memos/day` route。
- [x] 6.4 增加 focused tests：desktop heatmap date filter active 时 resizable inline compose layout 仍启用并恢复 persisted `homeInlineComposePanelLayout`。
- [x] 6.5 增加 focused tests：date filter apply / clear 保留 inline compose draft state。
- [x] 6.6 增加或收紧 architecture guardrail，防止 `state`、`application`、`core` 引入新的 `features` reverse dependencies，并防止 quick action route mapping 继续散落在多个 widget 中。
- [x] 6.7 增加 fallback tests 或覆盖：mobile / embedded navigation host / standalone `/memos/day` route 行为保持不变。

## 7. Verification

- [x] 7.1 运行相关 focused widget/unit tests。
- [x] 7.2 运行相关 architecture guardrails。
- [x] 7.3 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 7.4 在 `memos_flutter_app` 运行 `flutter test`；如果完整测试不可行，记录 scoped verification 和剩余风险。

## 8. Follow-up: Heatmap Date Selection From Desktop Destinations

- [x] 8.1 将 `DesktopDestinationShell` 增加 `onSelectDay` 透传，确保 shell 内部 AppDrawer heatmap 可以使用页面提供的 day selection intent。
- [x] 8.2 增加 `openDesktopHomeDayFilterDestination` / `buildDesktopHomeDayFilterDestination`，让 desktop top-level destination 点击 heatmap 日期时进入同一个 home-local day filter surface，而不是 `/memos/day` route。
- [x] 8.3 将 AI summary、daily review 以及其他 desktop drawer/destination 页面接入同一 day selection helper。
- [x] 8.4 增加 focused tests / guardrail 覆盖 shell callback 透传、local day filter 初始化和 desktop destination heatmap 一致性。
