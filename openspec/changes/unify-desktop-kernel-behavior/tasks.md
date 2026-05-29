## 1. Preparation And Scope Control

- [x] 1.1 Confirm active architecture phase is still `evolve_modularity` from `openspec/config.yaml`.
- [x] 1.2 Confirm implementation does not require API-related files. If `memos_flutter_app/lib/data/api` or `memos_flutter_app/test/data/api` appears necessary, pause for explicit approval.
- [x] 1.3 Inventory current desktop kernel divergences with `rg` for route motion, layout, close, minimum size, secondary pane, modal surface, search, compose, preview, `DragToMoveArea`, and direct `TargetPlatform.windows/macOS` checks.
- [x] 1.4 Decide and document the concrete file location for pure desktop kernel policy seams, ensuring those files do not import `features/*`, `state/*`, `application/*`, `data/*`, or API code.
- [x] 1.5 Run current focused baselines from `memos_flutter_app`: desktop shell guardrails, platform UI guardrails, modularity dependency guardrails, and existing memo list layout/search/compose tests.

## 2. Window Lifecycle And Close Policy

- [x] 2.1 Add focused regression coverage proving Windows shell close controls request the shared close coordinator rather than direct native close.
- [x] 2.2 Update Windows desktop command-bar close handling so user-facing main-window close enters `DesktopExitCoordinator.requestClose(...)` or an injected equivalent.
- [x] 2.3 Preserve minimize/maximize behavior while separating close lifecycle side effects from pure shell rendering where practical.
- [x] 2.4 Add or tighten a source guardrail that allows direct `windowManager.close()` only in approved lifecycle/termination paths and documented subwindow exceptions.
- [x] 2.5 Inventory main-window and subwindow minimum-size/frameless policy, then either centralize the main-window size contract or document verified native-runner and subwindow exceptions.
- [x] 2.6 Run Windows exit lifecycle tests and desktop shell close-control tests.

## 3. Desktop Route And Layout Kernel

- [x] 3.1 Introduce a pure desktop route motion policy that resolves drawer destination replacement transitions for Windows/macOS desktop contexts.
- [x] 3.2 Migrate `closeDrawerThenPushReplacement` to use the desktop route motion policy without embedding Windows-only shared-axis decisions in the navigation helper.
- [x] 3.3 Introduce a shared desktop layout policy/model with desktop layout tier, navigation mode, secondary pane support, default visibility, and default pane width.
- [x] 3.4 Migrate Windows shell layout resolution to the shared desktop layout policy while preserving existing Windows overlay/rail/expanded behavior.
- [x] 3.5 Migrate macOS shell layout resolution to the shared desktop layout policy while preserving macOS toolbar, traffic-light safe-area, rail, and expanded-sidebar title suppression.
- [x] 3.6 Keep or replace legacy `resolveWindowsDesktopLayout` through a compatibility wrapper only if needed, and add tests proving Windows/macOS use the shared policy.
- [x] 3.7 Add layout policy tests covering narrow, compact, expanded, and wide tiers on Windows and macOS.

## 4. Desktop Surface Kernel

- [x] 4.1 Introduce a desktop surface policy/capability model for secondary pane presentation, width bounds, resize capability, motion, modal barrier, blur, and fallback support.
- [x] 4.2 Migrate `DesktopShellHost` / `DesktopDestinationShell` to pass semantic surface policy output rather than relying on platform shell defaults alone.
- [x] 4.3 Migrate `WindowsDesktopWorkspaceShell` to consume the shared surface policy while preserving existing inline/overlay pane, resizer, and modal motion behavior.
- [x] 4.4 Migrate `AppleMacosPageShell` to consume secondary pane and modal surface policy explicitly, either implementing parity behavior or exposing documented unsupported/fallback capability.
- [x] 4.5 Add widget tests for Windows and macOS secondary pane visibility, width, motion/fallback semantics, and modal surface behavior.
- [x] 4.6 Add guardrail coverage that fails when platform shell APIs accept secondary pane or modal policy inputs but silently ignore them without a documented capability fallback.

## 5. Memo List Desktop Presentation Kernel

- [x] 5.1 Define a memo-list desktop presentation model that includes layout tier, navigation mode, titlebar strategy, preview pane policy, search presentation, compose presentation, and inline compose capability.
- [x] 5.2 Migrate `buildMemosListScreenLayoutState` away from raw `isWindowsDesktop` / `isMacosDesktop` behavior decisions toward the semantic desktop presentation model.
- [x] 5.3 Preserve current Windows and macOS memo list header/titlebar behavior through renderer-specific widgets fed by the shared presentation model.
- [x] 5.4 Migrate desktop preview pane support and default click-to-preview behavior to the shared desktop layout/presentation policy.
- [x] 5.5 Replace Windows-named search entry points such as `openWindowsHeaderSearch()` with semantic desktop search presentation APIs while preserving current Windows behavior.
- [x] 5.6 Replace Windows-named compose presenter wiring with a semantic desktop compose presentation path for text compose and voice-result compose.
- [x] 5.7 Preserve inline compose resize capability and desktop pane state while migrating compose/preview policy ownership.
- [x] 5.8 Add focused unit/widget tests for Windows and macOS memo list layout, preview, search shortcut, compose entry, and inline compose resize behavior.

## 6. Architecture Guardrails

- [x] 6.1 Add a desktop kernel branching guardrail that prevents feature pages from adding new Windows/macOS branches for route motion, layout tier, surface behavior, search, compose, preview, or main-window close without a documented exception.
- [x] 6.2 Add a desktop policy dependency guardrail proving pure desktop policy files do not import `features/*`, `state/*`, `application/*`, `data/*`, or API code.
- [x] 6.3 Add a shell boundary guardrail proving desktop shell host/platform shells consume shared layout/surface/window policies rather than duplicating platform-local breakpoint/kernel decisions.
- [x] 6.4 Update allowlists only for existing legacy drift that cannot be migrated in this change, and add tasks/comments for every remaining exception.
- [x] 6.5 Confirm the change reduces or isolates at least one touched coupling hotspot under `evolve_modularity`.

## 7. Verification

- [x] 7.1 Run `flutter analyze` from `memos_flutter_app`.
- [x] 7.2 Run architecture guardrails from `memos_flutter_app`, including desktop shell boundary, platform UI, modularity dependency, and new desktop kernel guardrails.
- [x] 7.3 Run focused desktop shell tests for Windows and macOS.
- [x] 7.4 Run focused memo list view state/body/route delegate/search/compose/preview tests.
- [x] 7.5 Run Windows desktop exit lifecycle tests.
- [x] 7.6 Run `openspec validate unify-desktop-kernel-behavior --strict`.
- [x] 7.7 Run `git diff --check`.
- [x] 7.8 If time allows before PR readiness, run full `flutter test`.

## 8. 最终手动验证

- [ ] 8.1 Windows 桌面端开启 close-to-tray 后，点击 shell 关闭按钮；通过标准：主窗口隐藏到托盘，应用进程不退出，再次从托盘打开后状态可继续使用。
- [ ] 8.2 Windows 桌面端关闭 close-to-tray 后，点击 shell 关闭按钮；通过标准：进入完整退出流程，窗口关闭前完成受控清理，没有跳过 `DesktopExitCoordinator` 的直接 native close 行为。
- [ ] 8.3 Windows 桌面端分别在 narrow、compact、expanded、wide 宽度下切换 drawer destination；通过标准：每个宽度下的页面切换动效、导航模式和当前 destination 高亮都符合对应 desktop layout policy。
- [ ] 8.4 macOS 桌面端分别在 rail 和 expanded-sidebar 宽度下切换 drawer destination；通过标准：页面切换后 titlebar、traffic-light 安全区、toolbar/chrome 显示不重叠、不丢失，并符合 macOS shell 策略。
- [ ] 8.5 Windows 和 macOS 桌面端分别打开、关闭 preview pane、modal compose surface 和 editor surface；通过标准：每个平台的宽度、遮罩、动效、关闭方式和 fallback 行为与已记录的 desktop surface policy 一致。
- [ ] 8.6 Windows 和 macOS 桌面端从桌面工具视图返回 memo list 后，依次验证搜索快捷键/入口、文本 compose、语音结果 compose、点击 memo 打开 preview、inline compose resize；通过标准：每个入口都可触发目标行为，返回后状态不丢失，resize 后尺寸保持可见且不破坏列表布局。
