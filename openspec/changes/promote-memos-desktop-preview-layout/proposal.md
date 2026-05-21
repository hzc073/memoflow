## Why

macOS 主页的笔记列表仍保留部分 Windows-only 桌面行为分支：单条 memo card 只在 Windows 上限宽，右侧 desktop preview pane 也被 Windows 平台判断挡住。结果是在 macOS 大窗口中，笔记卡片会被横向拉伸，点击卡片不能像 Windows 端一样在右侧打开预览栏。

当前架构阶段为 `evolve_modularity`，基线 modularity score 为 `4/10`。本变更触及 `features/memos` 与 `core/platform_layout.dart` 的桌面布局 seam，应把“桌面 memo list 卡片限宽 / preview pane”收敛为 desktop 行为，而不是继续扩散 `Platform.isWindows` 分支。

## What Changes

- 将 memo list 卡片的 `maxWidth` 规则从 Windows-only 提升为 desktop target 行为，覆盖 macOS / Windows / Linux。
- 将 desktop preview pane 支持从 Windows-only 提升为 desktop target 行为，使 macOS 大窗口下点击 memo card 可以打开右侧预览栏。
- 保留 Windows 现有 wide / expanded layout 语义，不回退已有 Windows 体验。
- 增加 focused tests 覆盖 macOS 卡片限宽、macOS preview layout 支持、desktop preview helper 行为。

## Capabilities

### Modified Capabilities

- `apple-platform-ui-adaptation`: macOS memo list 应复用 desktop memo list 布局能力，避免卡片横向拉伸，并支持右侧预览栏。
- `desktop-shell-host-boundary`: desktop memo list preview / card-width 规则应通过 desktop layout seam 表达，而不是隐藏在 Windows-only 分支。
- `memo-card-press-feedback`: 桌面 memo card 点击 / 按压语义应在 macOS 与 Windows 保持一致，支持预览交互而不改变原有手势。

## Impact

- 预计受影响代码位于 `memos_flutter_app`：
  - `lib/core/platform_layout.dart`
  - `lib/features/memos/memos_list_screen.dart`
  - `lib/features/memos/memos_list_screen_view_state.dart`
  - `lib/features/memos/widgets/memos_list_animated_memo_item.dart`
  - focused widget/unit tests
- 不触碰 API 请求/响应、route adapters、version compatibility logic 或 `memos_flutter_app/lib/data/api`。
- 不新增商业化、订阅、StoreKit、receipt、paywall 或 private overlay 逻辑。

## Non-Goals

- 不重做完整 macOS home shell。
- 不改变 memo card 内容渲染、编辑、删除、同步或 API 数据逻辑。
- 不把 macOS 主窗口改成 Windows-style window controls。
- 不改变 Windows 现有 preview pane 阈值和默认显示规则。
