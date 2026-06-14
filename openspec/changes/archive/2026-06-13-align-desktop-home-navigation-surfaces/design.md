## Context

桌面首页目前有三套导航路径：

- 顶部快捷胶囊由 `HomeQuickAction` 驱动，默认包含 `monthlyStats`、`aiSummary`、`dailyReview`，在 `MemosListScreen._openHomeQuickAction` 中直接 `Navigator.push` 新 route。
- 侧边栏目的地由 `AppDrawerDestination` 和 `MemosListRouteDelegate.navigateDrawer` 驱动；部分桌面 utility（`syncQueue`、`notifications`、`draftBox`）会嵌入 `MemosListScreen` primary content column。
- 抽屉热力图日期点击直接 `pushNamed('/memos/day')`，新建 `MemosListScreen(dayFilter: d)`。该 route 模型使 `shouldEnableDesktopHomeInlineComposeResizeForMemosList` 默认关闭 resize，因为 `dayFilter != null`。

这些路径共同位于 home/memos/navigation coupling hotspot。当前架构阶段为 `evolve_modularity`，本 change 应收敛导航决策到明确 seam，避免继续在 screen 方法里扩散 ad hoc route branching。

## Goals / Non-Goals

**Goals:**

- 让桌面端统计入口显示在首页 primary content column 中，而不是作为独立统计 route 打开。
- 让顶部快捷胶囊进入 `aiSummary`、`dailyReview` 等 top-level destinations 时复用侧边栏导航语义。
- 让热力图日期筛选在桌面首页中表现为当前工作区的过滤状态，并保留 resizable inline compose 的已保存布局。
- 降低和统一桌面工作区内切换动画，避免 route-level 强动画用于 primary content 替换。
- 保持移动端、tablet bottom navigation、非首页 standalone route 的既有行为。
- 不修改 server API、request/response models、route adapters 或 `memos_flutter_app/lib/data/api`。

**Non-Goals:**

- 不重新设计整个 desktop shell、drawer、bottom navigation 或 stats dashboard。
- 不改变统计、AI 总结、每日回顾本身的业务能力。
- 不把统计页加入商业能力、订阅、entitlement 或 private overlay 逻辑。
- 不解决所有 desktop route transition 观感问题，只处理本 change 涉及的首页入口。

## Decisions

### 1. Stats 作为 desktop home utility，而不是新的 top-level route

实现时应扩展现有 `DesktopHomeUtilityView` seam，加入 stats utility。桌面首页上下文打开 `HomeQuickAction.monthlyStats` 或相关桌面入口时，优先调用 `_showDesktopHomeUtilityView(DesktopHomeUtilityView.stats)`；primary content column 显示 `StatsScreen` 的 embedded 形态。

理由：用户期望统计像 draft box 等桌面辅助内容一样“放在笔记列表区域”。把 stats 纳入 utility seam 能复用现有 primary content override、drawer selection clearing、local back 语义和 route-less 切换。

替代方案是把 `StatsScreen` 加入 `HomeRootDestination` 或 drawer top-level destination。这个方案会让统计变成独立目的地，仍不满足“放笔记列表区域”的反馈，也会扩大 home navigation preference 的配置面。

### 2. Top quick actions 委托给 home navigation seam

`_openHomeQuickAction` 不应继续直接为所有 action 拼 route。桌面首页上下文中：

- `monthlyStats` -> desktop utility stats。
- `aiSummary`、`dailyReview`、`collections`、`resources`、`archived` 等已有 drawer/top-level destinations -> 复用 drawer destination navigation seam。
- `notifications`、`draftBox` 等 utility -> 继续使用 desktop utility seam。

移动端和 embedded navigation host 可保持既有分支，但桌面 standalone home 应减少直接 `Navigator.push` 分支。

这会让顶部胶囊和侧边栏进入同一 destination 时拥有相同 selected state、replacement/back 语义和 motion policy。

### 3. Heatmap day selection 是桌面首页局部过滤状态

桌面首页抽屉热力图点击某天时，不应 `pushNamed('/memos/day')`。更合适的模型是给 `AppDrawer` 增加可选的 date selection callback，由 `MemosListScreen` 在 desktop home context 中消费并设置 local effective day filter。

建议实现形态：

```text
AppDrawer(onSelectDay: ...)
  -> MemosListScreen._setDesktopHomeDayFilter(day)
  -> buildMemosListScreenQueryState(filterDay: effectiveDayFilter)
```

其中 `effectiveDayFilter = _desktopHomeDayFilter ?? widget.dayFilter`。route-level `widget.dayFilter` 继续保留给移动端或外部 named route，desktop drawer date selection 走局部状态。

日期过滤激活后应提供可见的清除/返回全部笔记 affordance，并且桌面 back handling 应优先清除局部日期过滤，而不是关闭窗口或离开当前 route。

### 4. Inline compose resize capability 需要区分 route-level day page 和 desktop home filtered state

当前 resize capability 用 `dayFilter == null` 判断是否是 all memos home。这个判断对 route-level 日期页合理，但对 desktop home 内的日期过滤不合理。

实现时应避免把 `dayFilter` 本身作为唯一否决条件。可以通过以下任一方式保持语义清楚：

- 给 resize helper 增加明确参数，例如 `desktopHomePrimaryContext` 或 `allowFilteredHomeInlineComposeResize`。
- 或在 desktop heatmap date selection 走本地过滤状态时，显式使用已有 `enableDesktopResizableHomeInlineCompose` override，但应确保该 override 只来自 home composition seam。

目标是让“桌面首页仍是同一个工作区”这一事实驱动 resize 决策，而不是让具体查询条件隐式关闭布局能力。

### 5. Motion policy 应跟随承载模型

primary content column 内的 utility/stat/date-filter 切换不应使用 route-level 动画。它可以使用极轻量 fade、短 duration content switch，或无动画；AI 总结/每日回顾作为 top-level destination 则应复用 drawer destination motion policy。

不建议在每个 button 上单独调 duration。动画一致性应来自同一导航 seam 的承载模型。

### 6. Modularity improvement

变更应把桌面快捷入口和热力图日期入口的打开逻辑集中到 home/navigation seam 或 focused helper 中，减少 `MemosListScreen._openHomeQuickAction` 和 `AppDrawer._DrawerHeatmap` 直接知道 route 细节。

允许的依赖方向：

```text
features/home drawer UI
  -> callback intent supplied by host

features/memos home host
  -> home navigation helper / route delegate / utility state
  -> feature screens as existing UI composition
```

应避免：

```text
state/application/core -> features
AppDrawer hardcodes desktop MemosListScreen route mutations
MemosListScreen keeps adding unrelated feature-specific Navigator.push branches
```

## Risks / Trade-offs

- [Stats embedded chrome mismatch] `StatsScreen` 当前以 `PlatformPage` 为主，直接嵌入可能出现重复 title/back chrome。缓解：为 stats 增加 desktop embedded presentation/back callback，或在 utility branch 使用 `showBackButton: false` 并提供局部 header。
- [Date filter state ambiguity] 用户可能需要区分“日期过滤”和“真正的 day route”。缓解：桌面 heatmap 使用局部 filter chip/clear affordance；外部 `/memos/day` route 保持原有 standalone 语义。
- [Route history expectations] 顶部快捷胶囊从 push 改为 destination/utility 切换后，返回栈行为会变化。缓解：限定在 desktop home context，并用 tests 覆盖返回到全部笔记和 clear utility behavior。
- [Animation regression] 减弱动画可能影响现有测试快照或过渡期视觉。缓解：用 focused tests 验证 route 选择和 utility state，而非依赖具体 animation frame。
- [Coupling hotspot expansion] home/memos/drawer 已经耦合。缓解：新增 helper/callback seam 和 tests，避免把更多 feature route 拼接逻辑直接塞进 widgets。

## Migration Plan

1. 先加入 stats utility branch 和 desktop quick action delegation，保留非桌面行为。
2. 再加入 drawer heatmap day callback 与 local effective day filter，保留 `/memos/day` route 作为 fallback。
3. 调整 inline compose resize decision，让 desktop home filtered state 保持 resize。
4. 添加 focused widget/unit tests 和必要 guardrail，验证顶部快捷入口、热力图日期入口、resize capability 和非桌面 fallback。
5. 若出现问题，可回滚到旧的 push route 行为；该 change 不涉及数据迁移或 API 迁移。

## Open Questions

- 日期过滤激活后的 UI 文案是使用现有 day route 标题，还是新增一个 compact filter chip 放在列表 header？
- Stats embedded header 应复用 `StatsScreen` 内部标题，还是让 `MemosListScreen` utility shell 统一提供 back/title？
- Windows primary content 替换是否完全无动画，还是保留 120-160ms fade 以避免突兀？
