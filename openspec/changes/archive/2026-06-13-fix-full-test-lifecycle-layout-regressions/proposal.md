## Why

`flutter analyze` 已通过，但 full `flutter test` 仍有 3 个稳定失败，阻止当前工作区获得完整测试背书。失败集中在两个独立问题：

- `App.dispose` 期间注销桌面快速记录 hotkey 时，`DesktopQuickInputController.unregisterHotKey()` 仍写入 Riverpod provider，导致 disposed `WidgetRef` 被读取。
- `AboutScreen` 作为 home/drawer destination 使用 `AboutUsContent` 时缺少滚动容器，在 bottom navigation shell 与测试视窗约束下出现 bottom overflow。

当前架构阶段是 `evolve_modularity`。本 change 触及 `application/desktop` 既有耦合热点、`app.dart` composition root 和 home/about destination。修复必须让资源释放与 UI 状态写入边界更清晰，并让 shell-launched about route 的布局行为通过页面容器修复，而不是改变导航语义或扩大平台分支。

## What Changes

- 桌面快速记录 hotkey 注销 SHALL 支持 dispose/teardown 场景只释放系统资源，不在 disposed widget/ref 上写状态。
- 正常运行时注销或注册失败 SHALL 继续把 quick record system hotkey state 标记为 inactive，保留主窗口 fallback 语义。
- Shell-launched 或 standalone `AboutScreen` SHALL 在可用高度不足时允许内容滚动，且 SHALL 保持返回到 `HomeBottomNavShell` / `HomeEntryScreen` 的现有导航语义。
- 增加 focused tests 或复用现有失败测试作为回归验证，并在修复后运行 `flutter analyze` 与相关 tests。
- 不修改 API route/version、request/response model、`memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
- 不添加 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、price、private overlay 或 `AccessDecision.source` business branching。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `desktop-quick-record-hotkey-fallback`: 补充 hotkey 注销在 app teardown/dispose 期间的状态写入边界。
- `home-navigation-back-safety`: 补充 shell-launched About route 在紧凑高度下必须可滚动且不破坏 shell 返回语义的规则。

## Impact

- 预计影响 `memos_flutter_app/lib/application/desktop/desktop_quick_input_controller.dart`，为 teardown-safe hotkey release 提供更明确的方法或参数。
- 预计影响 `memos_flutter_app/lib/app.dart`，让 `dispose` 使用 teardown-safe release path。
- 预计影响 `memos_flutter_app/lib/features/about/about_screen.dart`，给 `AboutUsContent` 在 drawer/home destination 场景增加 bounded scroll container。
- 预计影响 focused tests：`test/private_hooks/app_ready_hook_test.dart`、`test/application/desktop/desktop_quick_input_controller_test.dart`、`test/features/home/home_bottom_nav_shell_test.dart`。
- 模块化清单相关项：`2.` application coupling hotspot 不得新增反向依赖；`5.` `app.dart` 继续作为 composition root；`8.` 用现有/focused tests 防回归；`10.` touched area equal or better structured。
