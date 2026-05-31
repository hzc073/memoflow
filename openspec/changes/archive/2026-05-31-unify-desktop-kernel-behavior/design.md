## Context

`unify-desktop-destination-shell-navigation` 已经把一批顶层 drawer destination 迁移到 `DesktopDestinationShell`，这解决的是“页面不再自己选择 Windows shell 或 macOS Scaffold”的问题。但桌面行为内核仍然分散：

```text
core/drawer_navigation.dart
  └─ route replacement motion 直接判断 Windows + side pane

core/platform_layout.dart
  ├─ WindowsDesktopLayoutSpec
  ├─ shouldUseDesktopSidePaneLayout()
  └─ memo preview tiers 混合 Windows 命名和 shared desktop 行为

features/home/desktop
  ├─ Windows shell: secondary pane motion / resizer / modal blur / close button
  └─ macOS shell: sidebar width / toolbar policy / inline pane / simplified modal

features/memos
  ├─ layout state 接收 isWindowsDesktop / isMacosDesktop
  ├─ search 状态机暴露 openWindowsHeaderSearch()
  └─ compose 通过 _showWindowsDesktopNoteInput 专线进入 desktop modal
```

目标不是把 Windows/macOS 渲染成同一种 UI，而是建立一个统一 desktop kernel：feature 表达语义意图，kernel 决定桌面行为规则，platform skin 负责平台外观和原生集成。

Dependency direction before:

```text
core
  ├─ drawer_navigation owns platform-specific route policy
  └─ desktop_window_controls imports application/desktop exit coordinator

features/home/desktop
  ├─ Windows shell owns richer surface/window behavior
  └─ macOS shell owns separate layout/surface interpretation

features/memos
  ├─ owns platform booleans for header/search/preview/compose
  └─ passes Windows-only compose/search callbacks through route delegate
```

Dependency direction after:

```text
core/desktop or platform/desktop policy seam
  ├─ pure desktop route/layout/surface/search/compose decisions
  └─ no imports from features, state, application, or data

application/desktop
  └─ owns lifecycle side effects such as close-to-tray/full-exit coordinator

features/home/desktop
  ├─ consumes desktop kernel policies
  ├─ routes semantic shell slots to Windows/macOS renderers
  └─ invokes injected/application-owned window commands for side effects

features/memos
  ├─ asks for desktop presentation decisions through a memo-list policy/model
  └─ stops owning Windows/macOS behavior forks for shared desktop semantics
```

本 change 不需要 API approval：不触及 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。它也不得引入 subscription、billing、entitlement、StoreKit、paywall 或 private overlay 逻辑。

## Goals / Non-Goals

**Goals:**

- 建立统一 desktop kernel policy seams，让 Windows/macOS 共享桌面语义由同一套规则表达。
- 保留 platform skin 差异：Windows command bar/window controls 与 macOS toolbar/traffic-light safe area 不需要视觉一致。
- 修正 Windows custom close button 绕过 `DesktopExitCoordinator.requestClose(...)` 的 lifecycle 风险。
- 将 desktop layout tiers、route motion、secondary pane、modal surface、search、compose 和 preview 的共享行为从 feature/platform 分支收敛到 policy seam。
- 让 memo list 从 `isWindowsDesktop` / `isMacosDesktop` 迁移到 semantic desktop presentation model。
- 增加 guardrails，防止后续 feature page 或 shell 重新引入 page-local Windows/macOS kernel 分叉。
- 在 `evolve_modularity` 下改善 touched areas：减少 `core` 向 higher layer 的耦合、减少 feature screen 内共享桌面逻辑、增加边界测试。

**Non-Goals:**

- 不要求 Windows/macOS 视觉完全一致。
- 不把 Linux 提升为完整 desktop shell 目标；Linux 保持现有 fallback 或明确例外。
- 不清理所有历史 `state -> features`、`application -> features` 或 `core -> higher layer` allowlist。
- 不改变 API、DB schema、同步协议、memo mutation、账号/session 模型或 public/private commercial boundary。
- 不一次性重写所有 settings 子页或所有 desktop subwindow。
- 不在当前 change 中引入新的外部依赖。

## Decisions

### 1. Kernel 是小 policy 集合，不是单个万能 DesktopKernel

Decision: 引入多个小而可测试的 policy/model，而不是一个全局 `DesktopKernel` singleton：

```text
DesktopRouteMotionPolicy
DesktopLayoutPolicy
DesktopWindowPolicy
DesktopSurfacePolicy
DesktopSearchPolicy
DesktopComposePolicy
```

这些 policy 首先应是纯 decision layer：输入 platform、window width、surface kind、navigation context、feature intent；输出 route style、layout tier、surface capability、compose/search presentation 等。纯 policy 不应导入 feature UI、Riverpod state、application service 或 data layer。

Rationale: 当前问题来自行为分散，不是缺少一个对象。小 policy 更容易测试，也能避免把所有桌面概念塞进新的万能 abstraction。

Alternatives considered:

- 只修各处 `if (windows)`：短期快，但会继续扩大平台分叉。
- 做一个 `DesktopKernel` 大类：命名统一，但容易变成高耦合服务定位器。
- 只靠 `DesktopDestinationShell` 扩 API：shell 可以消费 kernel，但不应承担 memo search/compose/window lifecycle 的全部决策。

### 2. Platform skin 渲染不同，kernel behavior 必须显式

Decision: Windows/macOS 可以用不同 chrome、toolbar、traffic-light safe area、native menu 和 scroll feel，但共享桌面行为必须通过同一个 policy 表达。平台实现若不支持某项行为，必须通过 policy capability 明确为 unsupported/fallback，而不是接收参数后静默忽略。

Example:

```text
DesktopSurfaceIntent.previewPane
  ├─ supportsInline: true
  ├─ supportsOverlay: true/false
  ├─ supportsResize: true/false
  ├─ widthRange
  └─ motionSpec

Windows skin: renders command-bar workspace + resizer + blur modal
macOS skin: renders macOS toolbar + traffic-light safe area + native-feeling pane
```

Rationale: “API 统一但实现不统一”比没有 API 更危险，因为调用方会以为行为一致。capability 输出能让 tests 覆盖每个平台的真实支持状态。

Alternatives considered:

- 强行让 macOS 复制 Windows surface 视觉：会破坏平台体验。
- 保持 macOS 简化实现但不声明差异：继续隐藏 drift。

### 3. Window lifecycle side effects 留在 application/desktop，shell 只发命令

Decision: `DesktopWindowPolicy` 分两层：

- pure policy：决定当前 surface 是否显示 minimize/maximize/close、minimum size、frameless/chrome safe-area intent。
- lifecycle side effects：由 `application/desktop` 的 coordinator 或 composition-root-injected callbacks 执行，例如 `DesktopExitCoordinator.requestClose(...)`。

Windows shell 中 Flutter-drawn close button 必须进入 shared close coordinator，不得直接 `windowManager.close()`。最终实现可先用最小补丁修正 direct close，再逐步抽出统一 command callback。

Rationale: close-to-tray、secondary route close、full-exit cleanup、hotkey unregister、tray disposal、database close 都是 application lifecycle，不应藏在 widget button handler 里。

Alternatives considered:

- 让 shell 继续直接调用 `windowManager.close()`：简单但绕过生命周期。
- 让 `core` import `application/desktop`：会扩大已存在的 upward dependency 问题。

### 4. Layout policy 统一桌面层级，Windows/macOS 只保留平台映射

Decision: 用 shared desktop layout tier 描述 window width and navigation/surface capability，而不是让 `resolveWindowsDesktopLayout()` 和 macOS shell 自己判断 breakpoint。

Proposed conceptual model:

```text
DesktopLayoutTier
  ├─ narrow
  ├─ compact
  ├─ expanded
  └─ wide

DesktopNavigationMode
  ├─ overlay
  ├─ rail
  └─ expandedSidebar

DesktopLayoutSpec
  ├─ tier
  ├─ navigationMode
  ├─ supportsSecondaryPane
  ├─ defaultSecondaryPaneVisible
  ├─ defaultSecondaryPaneWidth
  └─ platformChrome
```

Windows/macOS 可以把同一 tier 映射到不同 chrome details，但 breakpoint 和 secondary pane support 不应由 feature page 或单个平台 shell 重复决定。

Rationale: layout tier 是后续 route motion、memo preview、secondary pane 和 titlebar policy 的共同输入。如果它仍是 Windows-only，就无法得到真正 kernel。

Alternatives considered:

- 继续保留 `WindowsDesktopLayoutSpec` 但让 macOS 调用它：命名和语义都不对，会把 shared behavior 伪装成 Windows behavior。
- 只新增 macOS layout spec：两个 spec 仍会漂移。

### 5. Memo list 使用 semantic presentation model

Decision: memo list 不应继续让 view state 直接接收 `isWindowsDesktop` / `isMacosDesktop` 来决定 header、preview、compose、padding、search。改为一个 memo-list desktop presentation model：

```text
MemosDesktopPresentation
  ├─ layoutTier
  ├─ navigationMode
  ├─ titlebarStrategy
  ├─ previewPanePolicy
  ├─ searchPresentation
  ├─ composePresentation
  └─ inlineComposeCapability
```

`features/memos` 仍拥有 memo list 的业务状态和 UI slots，但共享桌面行为由 policy 输出。Windows/macOS 的 titlebar widget、toolbar skin、modal renderer 可以继续不同。

Rationale: memo list 是最大耦合点。只迁移顶层 destination shell 不会解决 home memo list 内部 search/compose/preview 分叉。

Alternatives considered:

- 只重命名 `openWindowsHeaderSearch()`：不会改变 behavior ownership。
- 先把 macOS 也接到 Windows compose presenter：能快速统一体验，但会把 Windows 命名和假设扩散到 macOS。

### 6. Guardrails 保护“kernel 行为不回流到 feature page”

Decision: 新增或收紧 architecture tests：

- feature files 不得新增 direct Windows/macOS branches 来决定 desktop kernel behavior，除非在 allowlist 中明确记录平台 skin 例外。
- shell/window controls 不得直接调用 `windowManager.close()` 作为主窗口 close button 行为。
- platform shells 不得接收 surface/motion/resizer/modal policy inputs 后完全忽略而无 documented capability fallback。
- memo list desktop behavior tests 覆盖 Windows/macOS 同一 semantic policy 下的 expected presentation。

Rationale: 这个项目处于 `evolve_modularity`，AI/人工后续修改很容易回到“页面里判断平台”的写法。guardrail 是让 kernel 成为持续约束的关键。

Alternatives considered:

- 只写 OpenSpec 文档：不足以防止回归。
- 只靠 widget tests：难以覆盖新增页面或 source-level platform branching。

## Risks / Trade-offs

- [Risk] change 范围过大，影响 Windows/macOS 多个主路径。→ Mitigation: 分阶段实施，先 close/layout/route/window policy，再 surface parity，最后 memo list search/compose/preview。
- [Risk] policy 抽象过早，变成无意义 wrapper。→ Mitigation: 只抽当前已发现的真实分叉，每个 policy 必须有至少一个调用点迁移和测试。
- [Risk] 平台体验被误抹平。→ Mitigation: spec 明确 platform skin 可以不同；kernel 统一的是 behavior ownership 和 semantic policy。
- [Risk] macOS secondary pane/modal 现状与 Windows 差距较大。→ Mitigation: 首批要求“不静默忽略”，再按 task 分阶段补齐 resize/motion/overlay。
- [Risk] window lifecycle 修复触碰 close-to-tray/full-exit。→ Mitigation: 复用 `DesktopExitCoordinator` existing tests and add focused close-button regression test。
- [Risk] memo list migration 影响 compose/search 高频路径。→ Mitigation: 先建立 presentation model 和 tests，再逐步替换 call sites；保留现有 UI behavior unless spec explicitly changes it。

## Migration Plan

## Implementation Location Decision

本 change 的纯 desktop kernel policy seam 放在 `memos_flutter_app/lib/core/desktop/` 下，按职责拆成小文件，例如：

```text
memos_flutter_app/lib/core/desktop/desktop_route_motion_policy.dart
memos_flutter_app/lib/core/desktop/desktop_layout_policy.dart
memos_flutter_app/lib/core/desktop/desktop_window_policy.dart
memos_flutter_app/lib/core/desktop/desktop_surface_policy.dart
```

这些文件只能依赖 Flutter SDK、`core` 内的纯常量/模型和同层 desktop policy 文件，不得导入 `features/*`、`state/*`、`application/*`、`data/*` 或 API 代码。需要执行生命周期 side effect 的地方，例如主窗口 close-to-tray/full-exit，仍由 `application/desktop` coordinator 或 composition-root 注入的 callback 负责；shell 只消费 policy 输出或调用已注入的命令。

## Window Size / Frameless Inventory

首批实现保留 native runner 对主窗口最小尺寸的权威约束，并把它作为 documented policy exception：

```text
Main window initial size
  Windows Dart WindowOptions: 1360 x 860
  Windows native runner default size: 1360 x 860
  macOS native runner desired content size: 1360 x 860

Main window minimum size
  Windows native runner: 960 x 640
  macOS native runner: 960 x 640

Subwindow exceptions
  Quick input window: Dart-owned min/max, 420 x 440 .. 420 x 960
  Settings subwindow: Dart-owned frameless setup, size comes from desktop_settings_window route config
```

当前 Dart 侧通过 `DesktopWindowPolicy` 暴露同名常量和 tests，用于主窗口 `WindowOptions.minimumSize` 与 shell/subwindow 决策；Windows C++ runner 和 macOS Swift runner 仍必须保存 native startup/min-size 约束，因为这些约束在 Flutter Dart 初始化之前生效。该例外由 source inventory / guardrail verification 保护，避免 Dart 和 native 常量无意漂移。

1. Pin current divergences with source inventory and tests:
   - route motion
   - layout tiers
   - close button lifecycle
   - secondary pane/modal behavior
   - memo list search/compose/preview
2. Fix Windows custom close button to use shared close coordinator.
3. Introduce shared desktop layout and route motion policy, then migrate shell/drawer call sites.
4. Introduce desktop window policy and reconcile minimum-size/frameless/window-command semantics for main window and quick input exceptions.
5. Introduce desktop surface policy and make Windows/macOS shells consume capability/motion/resizer/modal inputs explicitly.
6. Introduce memo-list desktop presentation model and migrate view state/body/route delegate away from platform booleans and Windows-only presenter names.
7. Add guardrails and focused widget/unit tests for Windows and macOS.
8. Run focused architecture tests, desktop shell tests, memo list tests, `flutter analyze`, and targeted `flutter test`.

Rollback strategy: if a stage regresses, keep the newly added pure policy tests and revert only the affected call-site migration. Temporary exceptions must be recorded in guardrail allowlists with follow-up tasks.

## Open Questions

- Should macOS support secondary pane resize in the first implementation batch, or should the first batch make unsupported resize explicit and schedule parity as a follow-up task inside this change?
- Should memo list compose unification keep the existing Windows-centered modal surface first and rename it generically, or introduce a platform-neutral compose presenter before adding macOS parity?
