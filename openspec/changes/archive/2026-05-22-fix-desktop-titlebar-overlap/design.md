## Context

macOS 主窗口当前通过 `MainFlutterWindow.swift` 启用 `.fullSizeContentView`、透明 titlebar 和隐藏系统标题，使 Flutter 可以绘制到 titlebar 区域。这让主窗口 toolbar 可以更像 macOS 应用，但也意味着普通 `SafeArea` 不会自动避开左上角 native traffic lights。

已有实现中，`AppleMacosPageShell` 负责 macOS 主窗口 shell，`DesktopSettingsWindowApp` 负责独立设置窗口 frame。二者都可能在左上角绘制标题、导航或 command content；截图中的“设置”标题已经进入 traffic lights 区域。之前 `platform-adaptive-ui-system` 解决了按钮拉伸、桌面布局密度和 adaptive seams，但没有把 window chrome safe area 做成统一 contract。

本变更触及 `home`、`settings` 和 desktop shell 这些 coupling hotspots。依赖方向应保持为：

```text
features/home or features/settings shell composition
  └─ uses desktop/window-chrome safe-area helper

desktop/window-chrome helper
  └─ owns platform metrics / reserved insets
  └─ MUST NOT import features/state/application/data
```

## Goals / Non-Goals

**Goals:**

- 让 macOS 主窗口与独立设置窗口的左上角内容避开 native traffic lights。
- 将 titlebar safe-area 语义集中到 desktop shell / platform adapter / window frame 层。
- 保持 Windows frameless controls、Linux / Windows normal desktop、mobile safe-area 行为不回退。
- 增加 focused tests 或 guardrails，防止后续页面重新把内容放进系统控件区域。
- 在 `evolve_modularity` 阶段通过 seam extraction / guardrail tightening 保持 touched area equal or better structured。

**Non-Goals:**

- 不重新设计整个 desktop shell。
- 不改变 macOS Runner 的商业、签名、notarization 或私有 overlay 逻辑。
- 不重写所有 settings 子页面。
- 不引入平台专属 feature tree。
- 不修改 API、数据库、同步或状态模型。

## Decisions

### 1. 用 window chrome safe-area seam，而不是页面级 magic padding

实现应优先新增或复用一个集中 seam，例如 `DesktopWindowChromeSafeArea`、`DesktopWindowChromeInsets` 或等价 helper，用于描述：

```text
macOS transparent/full-size titlebar
  ├─ leading reserved width: traffic lights + drag margin
  ├─ top reserved height: titlebar/toolbar chrome height
  └─ applies only to top-leading titlebar content

Windows frameless
  ├─ top / trailing controls handled by Windows shell
  └─ no macOS traffic-light leading inset
```

备选方案是在 `DesktopSettingsWindowApp`、`AppleMacosPageShell` 和每个 title widget 中分别加 `Padding(left: 120)`。短期更快，但后续任何新窗口或 toolbar 都可能再次重叠，且 magic number 无法被测试和复用。结论：需要集中 seam，然后由 shell/frame 层消费。

### 2. 主窗口和设置子窗口都纳入验收范围

截图暴露的是设置窗口，但用户描述为“软件的左上角好像都有问题”。本 change 不应只修 `DesktopSettingsWindowApp`，还应检查 `AppleMacosPageShell`、desktop navigation sidebar/rail 和 memo titlebar quick actions 现有 traffic-light 处理是否一致。

```text
Main macOS window
  └─ AppleMacosPageShell / navigation / toolbar

Settings desktop subwindow
  └─ DesktopSettingsWindowFrame / DesktopSettingsWindowScreen titlebar
```

### 3. 避让发生在 shell/frame 层，feature 内容只表达标题和 actions

Feature page 应继续传入 `leadingTitle`、`trailing`、body 等语义内容；是否需要 titlebar reserved inset 由 shell/frame 根据平台决定。这样可以避免 `SettingsScreen`、memo pages 或其他 feature pages 知道 traffic lights 的像素位置。

### 4. 测试以 layout contract 为主

优先添加 focused widget tests，断言 macOS 场景下 titlebar leading content 的 global `dx` 不小于约定 reserved width，且移动端 / Windows 不应用 macOS traffic-light inset。若已有 memos titlebar 测试已经覆盖部分场景，应补 settings subwindow 和 shell-level 测试，而不是重复测试单个 memo quick action。

## Risks / Trade-offs

- [Risk] 固定 traffic-light inset 在不同 macOS 版本或窗口样式下不完全准确。  
  Mitigation：把数值封装为 named constant / helper，并只用于 Flutter titlebar content 的保守避让；未来如能从 native 侧传入更精确 metrics，可替换 helper 实现。

- [Risk] 增加 inset 后小窗口内容被挤压。  
  Mitigation：主窗口已有最小尺寸；设置窗口应确保标题可 ellipsis，toolbar actions 可保留最小宽度或向 trailing 收缩。

- [Risk] 修复 macOS 时误伤 Windows frameless controls。  
  Mitigation：helper 按 platform / window chrome mode 区分，tests 覆盖非 macOS 不出现 macOS leading inset。

- [Risk] 在 feature page 内直接修补最快，但加剧耦合。  
  Mitigation：任务要求先抽出或复用 shell/frame seam，再接入具体窗口。

## Migration Plan

1. 审计所有桌面 titlebar / window chrome 入口，确认主窗口、设置窗口、memo quick-action titlebar 的当前避让策略。
2. 新增或整理 desktop window chrome safe-area helper，定义 macOS traffic-light reserved inset 和适用条件。
3. 将 helper 接入 `AppleMacosPageShell`，使主窗口左上 titlebar / navigation / toolbar 内容避让 native controls。
4. 将 helper 接入 `DesktopSettingsWindowApp` 的 frame 或标题栏区域，修复设置窗口“设置”标题与 traffic lights 重叠。
5. 补 focused widget tests / guardrails。
6. 运行 `flutter analyze` 与相关 focused tests。

回滚策略：如果某个平台出现布局回归，可仅在该平台禁用新的 chrome inset，并保留 helper 与 tests 作为后续修复入口。

## Open Questions

- 设置独立窗口是否在 macOS 也需要 full-size transparent titlebar，还是只需要避让现有 traffic lights 区域？
- macOS traffic-light inset 是否应先使用保守常量，还是后续通过 native channel 暴露实际 `NSWindow` button frames？
- 是否需要把 drag region 的语义也一并纳入 helper，避免 titlebar 控件影响窗口拖拽？
