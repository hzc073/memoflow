## Why

桌面端已经通过 `DesktopDestinationShell` 收敛了一批顶层 destination shell，但核心行为仍分散在 Windows shell、macOS shell、`core` helpers 和 memo list feature 内。现在的问题不是视觉是否完全一致，而是 route motion、layout tiers、window lifecycle、secondary pane、modal surface、search、compose 和 preview 行为没有统一 desktop kernel，后续 Windows/macOS 很容易继续漂移。

当前架构阶段是 `evolve_modularity`，本 change 触及 `core`、`application/desktop`、`features/home/desktop`、`features/memos` 等耦合热点。涉及模块化清单项：`3.` core 不应继续向 higher layer 漏依赖，`4.` 共享桌面行为不应隐藏在 screen/widget 文件，`6.` feature collaboration 应通过 seam，`8.` guardrail tests，`10.` touched coupled area equal or better structured。本 change 的架构改善是把跨 Windows/macOS 的桌面行为集中为 desktop kernel policy seams，并用 tests/guardrails 阻止新的页面级平台分叉。

## What Changes

- 引入统一 desktop kernel 行为层，负责表达 Windows/macOS 共享的桌面交互语义：
  - `DesktopRouteMotionPolicy`
  - `DesktopLayoutPolicy`
  - `DesktopWindowPolicy`
  - `DesktopSurfacePolicy`
  - `DesktopSearchPolicy`
  - `DesktopComposePolicy`
- 将 Windows/macOS 可以不同渲染但语义应一致的行为从 feature page 和单平台 shell 中收敛到 policy seam：
  - drawer destination route replacement motion
  - desktop navigation/layout tiers and breakpoints
  - close/minimize/maximize/minimum-size/window-frame policy
  - secondary pane inline/overlay/resizer/motion semantics
  - modal surface backdrop/motion/placement semantics
  - memo list preview/search/compose desktop presentation decisions
- 修正 Windows custom close button 不得绕过 `DesktopExitCoordinator.requestClose(...)` 的行为，保留 close-to-tray、bounded full-exit cleanup 和日志语义。
- 迁移 memo list 中直接接收 `isWindowsDesktop` / `isMacosDesktop` 的桌面行为判断，使 feature 层表达 semantic intent，desktop kernel 决定平台支持和呈现策略。
- 增加或收紧 architecture guardrails，防止：
  - 新增 Windows-only layout policy 被 macOS 重复实现
  - feature page 直接判断 Windows/macOS 来决定 desktop kernel 行为
  - shell/window close 直接调用 `windowManager.close()` 绕过 exit coordinator
  - secondary pane/modal surface API 统一但某个平台忽略 policy inputs
- 不改变 API、DB schema、同步协议、业务 mutation、商业/private overlay 行为。
- Linux 仍保持现有 fallback 或明确例外；本 change 的统一 kernel 首要目标是 Windows 与 macOS。

## Capabilities

### New Capabilities

- `desktop-kernel-behavior`: 定义跨 Windows/macOS 的桌面 route、layout、window、surface、search、compose、preview 行为应由统一 desktop kernel policy seam 表达。

### Modified Capabilities

- `desktop-layering-governance`: 明确 desktop common layer 应拥有共享桌面行为 policy，platform shell 只负责平台渲染和原生集成。
- `desktop-shell-host-boundary`: 要求 desktop shell host 消费统一 kernel policy，并保持 feature page 不拥有 window/surface/layout kernel 规则。
- `windows-desktop-exit-lifecycle`: 收紧 Windows custom close button 必须进入 shared close coordinator，不得直接绕过 close-to-tray/full-exit lifecycle。
- `platform-adaptive-ui-system`: 补充 desktop transient surface/search/compose 的语义 intent 应通过 adaptive/kernel seam，而不是 page-local platform branch。

## Impact

- Affected shared desktop/core files:
  - `memos_flutter_app/lib/core/drawer_navigation.dart`
  - `memos_flutter_app/lib/core/platform_layout.dart`
  - `memos_flutter_app/lib/core/app_route_transitions.dart`
  - possible new desktop kernel policy files under an approved `core/desktop` or `platform/desktop` seam
- Affected application desktop lifecycle:
  - `memos_flutter_app/lib/application/desktop/desktop_exit_coordinator.dart`
  - `memos_flutter_app/lib/application/desktop/desktop_window_manager.dart`
- Affected shell/platform files:
  - `memos_flutter_app/lib/features/home/desktop/desktop_shell_host.dart`
  - `memos_flutter_app/lib/features/home/desktop/desktop_destination_shell.dart`
  - `memos_flutter_app/lib/features/home/desktop/windows_desktop_page_shell.dart`
  - `memos_flutter_app/lib/features/home/desktop/windows_desktop_workspace_shell.dart`
  - `memos_flutter_app/lib/features/home/desktop/apple_macos_page_shell.dart`
- Affected memo desktop feature files:
  - `memos_flutter_app/lib/features/memos/memos_list_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_screen_view_state.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_route_delegate.dart`
  - `memos_flutter_app/lib/features/memos/widgets/memos_list_screen_body.dart`
- Affected tests / guardrails:
  - desktop shell/widget tests
  - memo list layout/search/compose tests
  - architecture guardrails for desktop platform branching and window close lifecycle
- No API-related files under `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` are in scope.
