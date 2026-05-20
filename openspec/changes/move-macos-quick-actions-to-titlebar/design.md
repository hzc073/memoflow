## Context

Windows 端已有 `MemosListWindowsDesktopTitleBar`，会在自绘 command bar 中把 `MemosListPillRow` 放到中间区域。macOS 用户现在希望获得类似的空间利用和快捷入口可见性，但 Apple 平台不宜直接复制 Windows 的 frameless chrome 和右侧窗口控制按钮。

目标不是“完全不画顶部 UI”，而是采用 hybrid titlebar：

```text
macOS native window
┌─────────────────────────────────────────────────────┐
│ ● ● ●       [ 快捷入口 1 ][ 快捷入口 2 ][ 3 ]  搜索 │
├─────────────────────────────────────────────────────┤
│ memo list content                                    │
└─────────────────────────────────────────────────────┘
```

这意味着：

- 原生 NSWindow 仍拥有 traffic lights、Window menu、全屏、Spaces、Stage Manager、多显示器和系统可访问性语义。
- Flutter 负责标题栏可用内容区域内的 title / quick action pills / search / sort 等业务 UI。
- 可拖动区域和可点击控件要精确分层，避免 `DragToMoveArea` 截获快捷胶囊点击。

## Goals / Non-Goals

**Goals:**

- macOS home titlebar 显示三个快捷入口胶囊，优先复用 `MemosListPillRow` 和现有 `HomeQuickActionChipData`。
- 保留系统 traffic-light window controls，不自绘红黄绿按钮。
- 保留 macOS 标准关闭、最小化、缩放、全屏、Window menu 和 `Cmd+W` 等窗口语义。
- 标题栏布局避让 traffic lights，并在窄宽度下优雅降级。
- 被移动后的页面 header 不重复显示同一组快捷胶囊。
- 触达的 coupled area 保持 equal or better structured。

**Non-Goals:**

- 不做原生 `NSToolbar` / `NSTitlebarAccessoryViewController` 完整重写。
- 不新增一套 macOS-only quick action state。
- 不改变快捷入口配置、排序、图标、点击行为或设置页。
- 不引入商业化逻辑。

## Decision: use hybrid titlebar, not full custom chrome

采用 macOS hybrid titlebar：

```text
NSWindow chrome
  ├─ native traffic lights
  ├─ fullSizeContentView / transparent titlebar, if required
  └─ Flutter titlebar content
       ├─ traffic-light safe inset
       ├─ title / optional menu anchor
       ├─ MemosListPillRow
       └─ search / sort actions
```

备选方案：

| Option | Result | Trade-off |
| --- | --- | --- |
| 全 frameless + Flutter 自绘窗口按钮 | 复用 Windows 逻辑最多 | macOS 风险最高，会破坏 traffic lights 和系统窗口语义 |
| 原生 `NSToolbar` / `NSTitlebarAccessoryViewController` | 最 Apple-native | 难以复用现有 Flutter pill row、主题、i18n 和状态 |
| hybrid titlebar | 平衡布局自由和 Apple 语义 | 需要处理 native titlebar 属性、safe inset、拖动区域和布局降级 |

结论：优先 hybrid titlebar。只有在验证 hybrid titlebar 无法稳定承载 Flutter 内容时，才考虑 native accessory view；不采用全 frameless 作为 macOS 默认方案。

## Layout model

标题栏建议使用三段式，但 macOS 左侧必须为空出 traffic lights 区域：

```text
┌─────────────────────────────────────────────────────────────┐
│ [traffic safe inset] [title] [       pills       ] [actions] │
└─────────────────────────────────────────────────────────────┘
```

约束：

- `traffic safe inset` 应覆盖左上角系统红黄绿按钮和其 hover/drag 区域。
- `pills` 使用 `FittedBox` / constrained width，宽度不足时优先 scale down 或隐藏到现有 header fallback。
- `actions` 可以承载 search / sort 等轻量按钮，但不得包含 Windows-style minimize / maximize / close。
- 空白背景区域可作为 `DragToMoveArea`；pill buttons 和 action buttons 需要位于可点击层。
- 在 `data.searching` 或 header search 展开时，titlebar 可切换为 search field，沿用 Windows 端的状态模型，但视觉和窗口控制语义仍按 macOS 处理。

## Dependency direction and modularity

当前相关路径：

```text
features/memos/widgets/memos_list_screen_body.dart
  ├─ uses MemosListWindowsDesktopTitleBar for Windows desktop header
  ├─ uses MemosListPillRow in page header fallback
  └─ owns quickActions display decisions
```

目标方向：

```text
features/memos/widgets
  ├─ shared quick action pill row remains UI-only
  ├─ macOS titlebar widget owns macOS-specific layout only
  └─ no state/business duplication

macOS Runner / platform window seam
  └─ owns native titlebar/full-size-content setup
```

Guardrail:

- 不让 `core` 或 `application/desktop` 新增对 `features/memos` 的依赖来构造 pill row。
- 如果需要跨 shell 复用 titlebar pieces，优先在 `features/memos/widgets` 内抽取 UI-only composition，或在既有 shell host seam 中通过 child widgets 注入。
- macOS 原生窗口属性设置应留在 Runner 或 platform seam，不散落到业务页面。

## Risks / Trade-offs

- [Risk] Flutter 内容延伸到标题栏后与 traffic lights 重叠。  
  Mitigation：固定 traffic-light safe inset，并在 light/dark/inactive 状态截图验证。

- [Risk] `DragToMoveArea` 覆盖按钮，导致快捷胶囊可见但不可点。  
  Mitigation：拖动层放在背景层，交互控件放在上层；增加 widget test 或 manual smoke checklist。

- [Risk] 窄窗口下标题、快捷胶囊、搜索和排序互相挤压。  
  Mitigation：定义宽度阈值，优先隐藏 title 或 pills，必要时回退到内容 header。

- [Risk] native titlebar 设置影响 Windows/Linux 或设置子窗口。  
  Mitigation：Runner/platform seam 仅在 macOS main window 启用，并以 guardrail 限定。

- [Risk] 视觉像 Windows command bar。  
  Mitigation：不展示右侧 window controls；颜色、间距和 traffic-light safe inset 按 macOS shell 单独校准。

## Open Questions

- 三个快捷胶囊在窄宽度下应该 scale down、横向滚动，还是隐藏回内容 header？
- 搜索展开时是否完全替代 pills，还是在右侧 actions 区展开一个紧凑搜索框？
- macOS 主窗口是否需要取消当前 Windows-style command bar 视觉，只保留更轻的 toolbar band？
- 是否需要给用户偏好开关来控制 quick action pills 出现在 titlebar 还是内容 header？
