## Why

macOS full-size titlebar 允许 Flutter 内容绘制到窗口左上角，但顶级侧边栏页面在该区域重复显示当前页面标题，会与 native traffic lights 形成视觉冲突，也降低信息密度。现在需要把“是否显示标题”从单页修补提升为桌面外壳规则：window chrome 优先，导航上下文其次，页面标题只在提供额外信息时出现。

## What Changes

- 新增桌面 titlebar navigation context 规则，明确顶级 drawer destination 在展开侧边栏下不应在 macOS top-leading titlebar 区重复渲染页面名。
- 规定 rail / overlay / narrow navigation 下可以显示当前页面标题，因为导航文字不可见或临时隐藏，但必须由 shell 统一避开 native window chrome。
- 规定 macOS 主窗口内的二级页面、详情页、编辑页或 pushed task page 不额外渲染 App 级返回/关闭按钮；窗口处于二级 route 时，native red close control 的实际行为为 logical back / route pop，回到打开该页面前的上下文。
- 规定 root/top-level 页面下 native red close control 仍保持正常窗口关闭/隐藏语义，避免把所有窗口关闭行为无条件改成返回。
- 规定二级页面标题可以保留，但标题应位于 safe toolbar/content header，而不是系统窗口控件保留区。
- 规定 macOS expanded-sidebar 顶级页面隐藏重复标题和 leading 控件时仍必须保留一致的 titlebar / toolbar 占位高度，避免不同顶级页面之间切换时侧边栏整体上下跳动。
- 规定 macOS expanded-sidebar 顶级页面的隐藏 chrome 占位行不应额外绘制页面级底部分割线，避免归档、AI 总结等页面和其他顶级页面视觉不一致。
- 明确 titlebar / toolbar / page title 的显示决策属于 desktop shell 或 platform adapter 层，不应散落在各 feature page 的 magic padding 或平台分支中。
- 保持 Windows / Linux / mobile 现有导航语义不回退；本变更只约束桌面外壳规则与 macOS titlebar context。
- 不改变 API、数据库、同步、商业/private overlay 或 paid-feature 逻辑。

## Capabilities

### New Capabilities

- `desktop-titlebar-navigation-context`: 定义桌面 titlebar 中页面标题、导航上下文和 native window chrome 的优先级与显示规则。

### Modified Capabilities

- `apple-platform-ui-adaptation`: macOS shell 在 full-size / transparent titlebar 下必须把 native traffic lights 视为 reserved area，避免在展开侧边栏下重复显示顶级页面标题，并在主窗口二级 route 中将 native red close control 映射为 logical back。
- `desktop-shell-host-boundary`: 桌面外壳宿主负责根据 navigation mode 决定 titlebar leading title 是否显示，feature pages 只提供语义内容。
- `desktop-layering-governance`: titlebar title visibility、window chrome 避让和顶层导航上下文属于平台外壳工作，不应下沉到业务 feature 页面。

## Impact

- 主要影响 `memos_flutter_app` 桌面 shell / page chrome 规则：
  - `lib/features/home/desktop/**`
  - `lib/features/home/app_drawer.dart`
  - 使用 `DesktopShellHost`、`AppleMacosPageShell`、`WindowsDesktopPageShell` 的顶级 drawer destination 页面
  - 使用 `PlatformPage` 或手写 `Scaffold/AppBar` 的 macOS 顶级 drawer destination 页面
  - macOS 主窗口 route stack 与 window close interception seam
  - `lib/core/desktop/**`、`lib/platform/**` 或 `lib/application/desktop/**` 中已有 window chrome / platform adapter seam
- 当前架构阶段为 `evolve_modularity`，本变更触及 `home` 与 desktop shell coupling hotspot；实现时必须通过 shell seam 或 guardrail 收敛规则，避免新增 `feature page -> platform magic padding` 扩散。
- 不修改 `memos_flutter_app/lib/data/api`、request/response models、route adapters、`test/data/api` 或任何 paid-feature/private commercial 边界。
