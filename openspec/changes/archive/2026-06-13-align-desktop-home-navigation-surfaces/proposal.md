## Why

桌面端首页存在多条进入同一类内容的路径：顶部三个快捷胶囊、侧边栏目的地、抽屉热力图日期入口。当前这些路径分别使用独立 route、desktop utility embedding、named route 等不同承载方式，导致统计页像独立页面、AI 总结和侧边栏进入感受不一致、日期筛选重置内联输入框布局，并且切换动画显得过重。

这个 change 旨在把桌面首页的辅助视图和顶部快捷入口收敛到一致的桌面导航语义，让用户感觉是在同一个工作区内切换内容，而不是被跳转到多个不同页面模型。

## What Changes

- 桌面端统计入口从顶部快捷胶囊或桌面首页侧边栏进入时，SHALL 优先显示在 `MemosListScreen` 的 primary content column 中，行为与现有 desktop utility view 类似。
- 顶部快捷胶囊中的 `monthlyStats`、`aiSummary`、`dailyReview` 在桌面首页上下文中 SHALL 复用与侧边栏目的地一致的导航语义，避免同一目的地因入口不同表现为不同页面。
- 侧边栏热力图点击具体日期时，桌面首页上下文 SHALL 保持“全部笔记列表工作区”的体验：日期过滤不应重置已保存的 resizable inline compose 布局，也不应使用抢眼的独立页面跳转动画。
- 桌面端工作区内切换辅助视图或 top-level destination 时，SHALL 使用轻量、统一、可关闭的 motion policy；对于同一工作区内的 primary content 替换，SHOULD 避免 route-level 强动画。
- 保留移动端、tablet bottom navigation 和非桌面 standalone routes 的现有行为。
- 不修改 Memos server API、request/response models、route adapters 或 `memos_flutter_app/lib/data/api`。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `desktop-home-utility-embedding`: 增加 stats/date-filter 等桌面首页辅助内容的嵌入规则，并要求顶部快捷入口优先复用 desktop home utility/destination seam。
- `desktop-destination-shell-navigation`: 增加桌面首页顶部快捷入口进入 `aiSummary`、`dailyReview` 等 top-level destinations 时的统一导航语义，避免与侧边栏入口分叉。
- `desktop-home-inline-compose-resize`: 明确桌面日期过滤入口不得因为 `dayFilter` route 模型重置或禁用用户已保存的 home inline compose resize layout。

## Impact

- 主要影响 `memos_flutter_app/lib/features/memos/memos_list_screen.dart`、`memos_flutter_app/lib/features/home/home_navigation_host.dart`、`memos_flutter_app/lib/features/home/app_drawer_destination_builder.dart`、`memos_flutter_app/lib/features/home/app_drawer.dart`、`memos_flutter_app/lib/features/stats/stats_screen.dart`、`memos_flutter_app/lib/features/review/ai_summary_screen.dart`、`memos_flutter_app/lib/features/review/daily_review_screen.dart` 及相关 desktop shell/navigation tests。
- 可能影响 `memos_flutter_app/lib/features/home/desktop_home_inline_compose_resize_capability.dart` 的 capability decision，但不应把产品导航规则藏进低层或 API 层。
- 当前架构阶段：`evolve_modularity`。
- 触及 modularity checklist：item 6（feature-to-feature collaboration 应通过 navigation/boundary seam，而不是散落 screen 直连）、item 7（桌面 utility/destination 打开路径需要明确 owner）、item 8（需要 guardrail 或 focused tests 保护入口一致性）、item 10（触及 coupled home/memos/navigation 区域后结构应不变差）。
- scoped modularity improvement：实现时应把桌面快捷入口和热力图日期入口的路由决策收敛到现有 home/navigation seam 或 focused helper，减少 `MemosListScreen` 内直接 `Navigator.push` 分支继续扩散。
