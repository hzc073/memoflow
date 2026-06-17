## 1. 范围确认

- [x] 1.1 在 iPhone dark mode 配置下确认底部导航、合集页侧边栏入口、笔记列表顶部滚动露白的当前复现路径，并记录涉及的 widget / shell 文件。
- [x] 1.2 确认本 change 不触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、请求/响应模型或 route adapter。
- [x] 1.3 检查待修改路径是否包含商业化、订阅、billing、entitlement、StoreKit、paywall、private overlay 或 `AccessDecision.source` 业务分支风险。

## 2. iPhone 底部导航夜间颜色

- [x] 2.1 在 `memos_flutter_app/lib/features/home/home_bottom_nav_shell.dart` 中先按当前 `BuildContext` 解析 `CupertinoDynamicColor`，再应用 alpha / channel 调整。
- [x] 2.2 调整 iPhone dark mode selected / unselected destination 颜色，确保图标和 label 在暗色底部导航表面可读且选中态清晰。
- [x] 2.3 保持 light mode 的既有半透明视觉和 bottom safe-area 覆盖行为不变。
- [x] 2.4 增加或更新 `HomeBottomNavShell` widget test，覆盖 iPhone dark mode 背景不是浅色、label 可见、safe-area 装饰仍覆盖手势区域。

## 3. iPhone 合集侧边栏入口

- [x] 3.1 为 Apple mobile `PlatformPage` drawer 或 bottom navigation shell 增加通用打开 seam，使 `drawer` 内容可在 `CupertinoPageScaffold` 路径下展示。
- [x] 3.2 保持 `platform/widgets` 不导入 `features/*`、`state/*`、`application/*` 或 app data repositories，drawer 内容继续由调用方或 shell 组合。
- [x] 3.3 调整 `CollectionsScreen` 在 bottom navigation / `HomeEmbeddedNavigationHost` 路径下的 menu action，使用户点击后能打开现有 `AppDrawer` 或等价共享导航 surface。
- [x] 3.4 确认 standalone Collections、desktop、Material scaffold 路径的现有 drawer / navigation 行为不回退。
- [x] 3.5 增加或更新 Collections / `PlatformPage` widget test，覆盖 iPhone embedded navigation 中 menu button 可打开侧边栏并通过 host 处理 drawer 选择。

## 4. 笔记列表顶部夜间表面

- [x] 4.1 检查 `memos_flutter_app/lib/features/memos/memos_list_screen.dart` 和 `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart` 的 `headerBg`、`SliverAppBar`、`Scaffold` / scroll 背景来源。
- [x] 4.2 为 iPhone dark mode 顶部 pinned chrome 提供稳定暗色承托，避免半透明 header 后方透出白色或浅色 page background。
- [x] 4.3 保持 reader、light mode 和非 iPhone 平台视觉尽量不变；如发现相同规则可复用，优先通过 shared platform/page/shell seam 收束。
- [x] 4.4 增加或更新 memo list widget test，覆盖 iPhone dark mode 向上滚动时顶部 surface 保持暗色。
- [x] 4.5 修复 iPhone dark mode 设置子页面上滑时顶部 `CupertinoNavigationBar` / page chrome 露出浅色背景，并补设置子页面回归测试。

## 5. 模块化和回归检查

- [x] 5.1 检查本次 touched area 没有新增 `state -> features`、`application -> features`、`core -> state|application|features` 反向依赖。
- [x] 5.2 为新增 drawer / platform seam 保留 focused guardrail 或 widget 覆盖，满足 `evolve_modularity` 下 touched area 等于或优于现状。
- [x] 5.3 运行 `flutter test` 的相关 focused test 文件，至少覆盖 home bottom navigation、Collections drawer、memo list top surface。
- [x] 5.4 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.5 在 `memos_flutter_app` 运行完整 `flutter test`，并记录任何与本 change 无关的既有失败。
