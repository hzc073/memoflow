## Why

iPhone 夜间模式下，底部导航字体对比不足、合集页侧边栏入口无法打开、笔记列表向上滚动时顶部露出浅色背景，说明当前 Apple mobile shell、`PlatformPage` drawer 边界和夜间表面颜色规则不够明确。现在需要把这些行为收束为可验证的规则，避免后续修复只处理单点颜色或按钮而留下同类回归。

## What Changes

- 明确 iPhone 底部导航在夜间模式下的背景、选中项、未选中项和安全区覆盖规则，禁止动态 iOS 颜色在解析前丢失暗色分支。
- 明确底部导航模式中的顶层目的地侧边栏入口必须在 iPhone 上可打开，即使页面使用 `PlatformPage` / `CupertinoPageScaffold`。
- 明确笔记列表顶部滚动区域在夜间模式下不得透出浅色背景，移动端顶部栏与页面底色必须有稳定暗色承托。
- 将 drawer 打开行为收束到平台/壳层边界或等价 seam，避免功能页继续依赖不存在的 Material `Scaffold` drawer。
- 保持 public shell 边界，不引入订阅、付费、StoreKit、entitlement、paywall 或私有 overlay 逻辑。
- 当前架构阶段为 `evolve_modularity`，本 change 触及模块化清单第 `6`、`8`、`10` 项；通过平台页面/导航壳 seam 和回归测试让 touched area 保持等于或优于现状。

## Capabilities

### New Capabilities
- `ios-night-navigation-boundaries`: 定义 iPhone 夜间导航、顶层侧边栏入口和滚动顶部表面的暗色可读性与边界规则。

### Modified Capabilities
- `home-bottom-navigation-visuals`: 扩展底部导航夜间可读性、动态颜色解析和 iPhone 安全区表面要求。
- `apple-platform-ui-adaptation`: 扩展 `PlatformPage` / Apple mobile page chrome 对 drawer、top-level navigation、平台 seam 的适配要求。

## Impact

- Affected code: `memos_flutter_app/lib/features/home/home_bottom_nav_shell.dart`, `memos_flutter_app/lib/platform/widgets/platform_page.dart`, `memos_flutter_app/lib/features/collections/collections_screen.dart`, `memos_flutter_app/lib/features/memos/memos_list_screen.dart`, `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart`, and related top-level destination pages that use drawer chrome inside bottom navigation mode.
- Tests: add or tighten iPhone dark-mode widget tests for bottom navigation colors, `PlatformPage` drawer/open behavior, Collections embedded navigation, and memo list top surface background.
- APIs: no server API, route adapter, request/response model, or `memos_flutter_app/lib/data/api` changes are planned.
- Dependencies: no new package dependency is expected.
