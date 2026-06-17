## Context

当前 iPhone bottom navigation 路径由 `HomeEntryScreen` 包裹 `AppleMobileShell` 后进入 `HomeBottomNavShell`。底部导航的 iPhone 分支使用 `CupertinoColors.systemBackground.withValues(...)` 再解析颜色，存在先丢失 `CupertinoDynamicColor` 暗色分支的风险；同时选中/未选中状态依赖 Cupertino 主题和动态 label 颜色，夜间对比度缺少显式保障。

合集等顶层页面在 bottom navigation 中通过 `HomeEmbeddedNavigationHost` 嵌入，但 `CollectionsScreen` 的 fallback 使用 `PlatformPage(drawer: drawerPanel, leading: AppDrawerMenuButton(...))`。`PlatformPage` 在 iPhone 上渲染为 `CupertinoPageScaffold`，不会提供 Material `Scaffold` drawer；`AppDrawerMenuButton` 默认只查找 `Scaffold.maybeOf(context).openDrawer()`，因此按钮可见但没有可打开的侧边栏。

笔记列表顶部使用半透明 `headerBg` 作为 `SliverAppBar` 背景。在 iPhone 夜间、edge-to-edge 和滚动透出组合下，如果 header 背后没有稳定暗色表面，会出现顶部露出浅色背景。

架构阶段为 `evolve_modularity`。本 change 触及 `features/home`、`features/collections`、`features/memos` 和 `platform/widgets`，属于 coupled UI shell 区域；目标是把平台行为收束到 shell / platform seam，而不是在各功能页继续增加 Apple-only 分支。

## Goals / Non-Goals

**Goals:**

- iPhone 夜间底部导航的背景、图标和文字在 selected / unselected 状态下都保持可读。
- bottom navigation 模式下，合集页和同类顶层页面的侧边栏入口在 iPhone 上可打开。
- 笔记列表向上滚动时，顶部状态栏和 app bar 区域在夜间不会透出白色或浅色背景。
- 通过平台页面或导航壳 seam 统一 drawer 打开语义，减少功能页对 Material `Scaffold` drawer 的隐式依赖。
- 增加 focused widget tests 覆盖 iPhone dark mode、drawer 打开和顶部背景回归。

**Non-Goals:**

- 不改 Memos API、请求/响应模型、route adapter 或 `memos_flutter_app/lib/data/api`。
- 不重新设计整个 bottom navigation 或 drawer 信息架构。
- 不引入新的商业化、订阅、StoreKit、entitlement、paywall 或 private overlay 逻辑。
- 不进行宽泛 Apple UI 全量平台化；只处理本次缺陷相关的可验证边界。

## Decisions

1. 在使用 `CupertinoDynamicColor` 的 iPhone navigation 表面中先 `resolve`，再应用 alpha。

   Rationale: Flutter 的 `CupertinoDynamicColor.withValues()` 返回普通 `Color`，在未按 context 解析前调用会基于默认浅色有效值，夜间模式无法再恢复暗色分支。底部导航背景应使用 `CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context).withValues(...)` 或等价 helper。

   Alternative considered: 直接改为 `MemoFlowPalette.cardDark` / `cardLight`。这能修复当前颜色，但会丢掉 Apple elevated / high contrast 动态色语义；更稳妥的是保留动态色解析顺序，并在必要时为 brand accent 使用显式暗色主色。

2. 将 iPhone bottom navigation drawer 打开能力放到 shell / platform seam，而不是让功能页直接依赖 `Scaffold.openDrawer()`。

   Rationale: `PlatformPage` 的 iPhone 实现是 `CupertinoPageScaffold`，Material drawer 不存在。功能页传入 `drawer` 时，平台层或 bottom navigation shell 应负责提供等价的侧边栏展示方式，例如通过 modal route / sheet / overlay 承载 `AppDrawer`，或者为 `AppDrawerMenuButton` 提供明确 `onPressed` 回调。这样功能页只表达“打开顶层导航”，不判断当前平台 scaffold 类型。

   Alternative considered: 把 `CollectionsScreen` 从 `PlatformPage` 改回 Material `Scaffold`。这会绕开问题，但削弱 Apple platform adapter 的目标，也会让同类页面继续存在重复风险。

3. 夜间 memo list 顶部背景使用不透明或稳定暗色承托。

   Rationale: `SliverAppBar` 半透明背景可保留轻量视觉，但移动端夜间必须保证背后是暗色页面表面。实现时可以让 `Scaffold` / scroll viewport / header 背景统一使用 `Theme.of(context).scaffoldBackgroundColor` 或 resolved dark palette，并在 iPhone dark mode 下避免透明 header 透出浅色。

   Alternative considered: 只提高 `headerBg` alpha。该方案能降低露白概率，但不能解决背后 surface 错误的问题。

4. 用 focused tests 作为 guardrail。

   Rationale: 这些问题主要是 platform + theme + scaffold 组合回归，单元逻辑测试不足。应增加 widget tests 验证 iPhone dark mode bottom navigation 背景不是浅色、label 可读、Collections embedded drawer entry 能打开，以及 memo list top surface 在 dark mode 中保持暗色。

## Risks / Trade-offs

- [Risk] 为 iPhone drawer 增加平台等价 surface 可能影响其他 `PlatformPage(drawer:)` 页面。→ Mitigation: 先覆盖 bottom navigation 顶层目的地路径，并以 tests 限定 drawer 只在 drawer 存在且用户触发时展示。
- [Risk] 颜色调整可能改变 light mode 的视觉细节。→ Mitigation: 保留现有 light mode alpha 和 safe-area 规则，增加 dark mode 专项断言，避免无关重绘。
- [Risk] 如果 drawer 打开 seam 放错层，可能引入 `platform -> features` 依赖。→ Mitigation: `platform/widgets` 只承载通用 slot / callback，不导入 `features/*`；`features/home` 或调用方负责传入 `AppDrawer` 内容。
- [Risk] memo list 顶部露白可能涉及系统状态栏 overlay。→ Mitigation: 验证 `SliverAppBar`、scaffold background 和 system overlay style 三层；优先修复 Flutter surface，只有仍复现时再增加系统栏样式同步。

## Migration Plan

1. 先实现颜色解析 helper 或局部修正，验证 iPhone dark mode bottom navigation。
2. 再实现 drawer 打开 seam，使 `CollectionsScreen` bottom navigation 路径可打开侧边栏，同时检查同类顶层页面是否复用。
3. 最后修正 memo list 顶部 dark surface，补齐 widget tests。
4. 若出现回归，可回退到当前 `PlatformPage` fallback 和 bottom navigation 实现；本 change 不涉及数据迁移。

## Open Questions

- iPhone drawer 等价 surface 最终应采用 full-height modal、side sheet、还是 existing Material `Drawer` in an overlay；实现时应优先复用现有 `AppDrawer` 内容和已存在 motion/timing。
- 需要通过截图或真机进一步确认“笔记向上滑动顶部变白”是否发生在 memo list 首页、合集 reader，还是两者都有；当前规则先覆盖 memo list 顶部 surface，reader 已有独立 palette 和 system UI 同步逻辑。
