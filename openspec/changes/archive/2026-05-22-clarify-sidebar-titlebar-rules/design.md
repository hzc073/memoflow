## Context

macOS 主窗口使用 full-size / transparent titlebar 后，Flutter 可以绘制到 native traffic lights 区域。此前 `fix-desktop-titlebar-overlap` 已经定义了 window chrome safe-area 方向，但截图暴露的体验问题不只是缺少 padding：展开侧边栏已经通过选中态表达当前顶级页面，titlebar 左上再显示“探索 / 设置 / 合集”等页面名，既重复又容易与系统窗口控件竞争空间。

当前桌面页面多通过 `DesktopShellHost` 接入 Windows / macOS shell，feature page 通常提供 `leadingTitle`、`trailing` 和 `body`。这给我们一个更好的边界：feature page 可以继续表达语义内容，是否渲染 titlebar leading title、是否显示 App 级 back/close control、以及 native close 在二级 route 中如何分派，都由 shell 根据平台、navigation mode 和页面层级决定。

本变更处于 `evolve_modularity` 阶段，会触及 `home` 与 desktop shell coupling hotspot。实现必须把规则收敛到 shell / platform adapter seam，并通过测试或 guardrail 防止后续页面继续在 feature 内自行添加 macOS magic padding。

## Goals / Non-Goals

**Goals:**

- 明确 macOS native window chrome 优先于页面标题展示，top-leading titlebar reserved area 不承载重复页面名。
- 明确展开侧边栏中的顶级 drawer destination 默认不在 titlebar leading 区重复显示页面标题。
- 隐藏重复标题和 leading 控件时仍保持顶级页面之间一致的 titlebar / toolbar 占位高度，避免侧边栏在菜单跳转时上下跳动。
- 保留 rail / overlay / narrow navigation 下的页面标题能力，因为此时当前导航文字可能不可见。
- 保留二级页面、详情页、编辑页、返回栈页面的标题能力，但不额外渲染 App 级返回/关闭按钮。
- 在 macOS 主窗口处于二级 route 时，将 native red close control 的实际行为定义为 logical back / route pop；root/top-level 时仍执行正常窗口关闭/隐藏。
- 让 title visibility decision 位于 desktop shell / platform adapter seam，而不是散落在 feature pages。
- 为实现阶段留下 focused tests / guardrail 入口，确保 touched area equal or better structured。

**Non-Goals:**

- 不重新设计整个桌面导航或所有页面 header。
- 不要求删除所有页面内部标题，只约束 desktop shell titlebar leading context。
- 不改变 Windows caption controls、Linux、mobile 或 web 的既有行为。
- 不把 macOS native red close control 无条件改成返回；该行为只适用于主窗口中可 pop 的二级 route。
- 不修改 API、数据库、同步、账号、商业/private overlay 或 paid-feature 状态。
- 不把 macOS 专属规则复制到独立 `features_macos/` 页面树。

## Decisions

### 1. Titlebar leading title 使用“信息增量”规则

规则优先级为：

```text
native window chrome
  > navigation context
  > page title
  > decorative/branding text
```

展开侧边栏已经显示可读的 destination label 和 selected state，因此顶级 destination title 在 titlebar leading 区没有信息增量，应默认不显示。rail、overlay、窄屏或隐藏导航时，当前页面标题仍有信息增量，可以显示，但必须由 shell 避开 native window chrome。

替代方案是在所有 title 上统一加 macOS leading inset。这样能解决 overlap，但仍保留重复标题，并让有限 titlebar 空间继续被低价值文本占用。结论：只做避让不够，必须同时定义显示条件。

### 1.1 隐藏重复标题不等于移除 titlebar 占位

展开侧边栏顶级页面隐藏 titlebar leading title 和 leading control 时，shell / platform adapter 仍应保留一致的顶部 chrome 行高度。否则不同页面可能出现三种 body 起点：

```text
custom macOS titlebar: 52px
Material default AppBar: 56px
omitted AppBar: 0px
```

侧边栏位于 body 内时，这些差异会在菜单切换时表现为侧边栏整体上下跳动。结论：macOS expanded-sidebar top-level context 应使用统一 titlebar spacer height；隐藏的是重复内容，不是页面顶部布局锚点。

同时，隐藏 chrome 后的 spacer 应保持视觉空白；它只负责保留 native titlebar 高度，不应该由归档列表、自定义 AppBar 或单页 header 继续绘制底部分割线。否则页面虽然高度一致，顶部样式仍会在不同顶级 destination 间变化。

### 2. Feature page 只提供语义，shell 决定展示

Feature page 可以继续向 `DesktopShellHost` 提供 `leadingTitle`、`trailing`、`center`、`body` 等语义槽位；shell 根据 navigation mode、平台和页面层级决定是否渲染 `leadingTitle`。

依赖方向应保持为：

```text
features/* page
  └─ provides semantic shell slots

DesktopShellHost / platform shell
  └─ decides title visibility and chrome-safe placement

desktop chrome helper / platform adapter
  └─ owns native reserved metrics
  └─ MUST NOT import features/state/application/data
```

替代方案是在 `ExploreScreen`、`CollectionsScreen`、`SettingsScreen` 等页面内分别判断 macOS + expanded sidebar 后传空标题。短期直接，但会继续扩大 feature-page platform branching。结论：实现阶段应抽出或复用 shell-level policy。

### 3. 顶级页面和二级页面分开处理

顶级 drawer destination 是侧边栏导航上下文的一部分；二级页面、详情页、编辑页或 pushed task page 是 route stack 中的任务上下文。后者的标题仍可能必要，但不应占用 macOS traffic-light reserved area，也不应额外渲染手机式 App 返回按钮。

```text
Top-level + expanded sidebar
  sidebar selected state is the title
  titlebar leading title hidden

Top-level + rail/overlay/narrow
  titlebar leading title visible if needed
  chrome safe-area applies

Secondary/detail/editor
  title visible in safe toolbar/content header
  no app-level back/close control in macOS main-window chrome
  native red close performs logical route pop when route can pop
```

状态规则：

```text
macOS main window root/top-level route
  red close
    -> normal window close/hide policy

macOS main window secondary route
  red close
    -> maybePop / logical back to previous app context
    -> window remains open
```

替代方案是在二级页面显示 `←`、`关闭` 或 `完成` App 控件，并把它们放到 traffic lights 右侧。这更符合普通 Flutter route，但会在 macOS 左上角形成两个关闭/退出语义：native red close 和 App 级退出控件。结论：在主窗口二级 route 中，应移除 App 级 back/close 控件，由 native red close 承担 dismiss current route 的实际行为。

### 4. 测试优先覆盖 contract，不逐页快照

实现阶段应优先验证 shell policy：

- macOS + expanded sidebar + top-level destination: leading page title is absent from titlebar leading slot。
- macOS + rail/overlay/narrow: page title can appear and does not overlap traffic lights。
- macOS main-window secondary/detail context: App-level back/close control is absent, title remains available outside reserved chrome area, and native red close pops the current route。
- macOS main-window root/top-level context: native red close keeps normal window close/hide behavior。
- Windows / non-macOS behavior does not receive macOS-only title suppression unless navigation mode requires the same semantic rule。

逐页截图可作为 smoke check，但核心应该是 shell-level policy test 或 guardrail，避免每个页面重复维护。

## Risks / Trade-offs

- [Risk] 隐藏 titlebar page title 后，部分用户可能觉得当前页面识别弱。  
  Mitigation：仅在展开侧边栏且 selected destination 可见时隐藏；rail / overlay / narrow 模式仍保留标题。

- [Risk] 页面传入 `leadingTitle` 后 shell 不渲染，可能让页面作者误判。  
  Mitigation：将 policy 命名清楚，例如 title display mode / navigation context policy，并用测试覆盖关键组合。

- [Risk] 隐藏 titlebar 内容时误删整个 toolbar / AppBar，导致侧栏位置随页面切换上下跳动。  
  Mitigation：将 top-level chrome omission 与 toolbar spacer height 作为同一 centralized policy 输出；`PlatformPage` 和手写顶级 `AppBar` 都复用同一高度规则。

- [Risk] 二级页面和顶级页面边界不清。  
  Mitigation：用 destination metadata 或 shell presentation context 表达 `topLevelDestination` vs `secondaryTask`，不要依赖 title 文本内容推断。

- [Risk] 拦截 native red close 可能违反用户对窗口关闭的预期。  
  Mitigation：只在 macOS 主窗口存在可 pop 的二级 route 时拦截；root/top-level route 仍走正常窗口关闭/隐藏。`Cmd+W` 如被支持，应与 red close 保持同一分派规则。

- [Risk] 二级页面没有 App 级返回按钮后，可发现性依赖 traffic lights。  
  Mitigation：该规则仅用于桌面主窗口；二级页面 title 保持清晰，菜单/快捷键/文档可说明窗口关闭会退出当前视图。移动端和非 macOS 平台不套用该交互。

- [Risk] 与已有 `fix-desktop-titlebar-overlap` 的 window chrome safe-area 规则重复。  
  Mitigation：本变更只补充 title visibility 和 navigation context 语义；window chrome metrics 仍沿用既有 safe-area seam。

## Migration Plan

1. 审计当前使用 `DesktopShellHost` / `AppleMacosPageShell` 的顶级 drawer destination，标记哪些 title 属于重复导航上下文。
2. 在 desktop shell / platform adapter seam 中定义 title visibility policy，避免 feature pages 直接判断 macOS traffic lights。
3. 将顶级 drawer destination 的 expanded sidebar + macOS titlebar leading title 默认隐藏。
4. 在隐藏顶级重复 title / leading 的同时保留统一 titlebar spacer height，确保展开侧边栏顶级页面之间切换时 body / sidebar 垂直锚点稳定。
5. 在 macOS 主窗口 close policy 中区分 root/top-level route 与 secondary route：root 执行正常窗口关闭/隐藏，secondary route 执行 logical pop。
6. 移除 macOS 主窗口二级 route 的 App 级 back/close 控件，同时保留 title / task context 的 safe placement。
7. 保留 rail / overlay / narrow navigation 的 title 展示，并复用 window chrome safe-area seam。
8. 为 shell policy 和 close dispatch 添加 focused tests 或 guardrail。
9. 运行 focused tests、`flutter analyze`，必要时按仓库规范运行 `flutter test`。

Rollback：如果隐藏标题影响导航识别，可只回滚 title visibility policy；如果 native close pop 造成可发现性或窗口管理回归，可回滚 secondary-route close interception，保留 window chrome safe-area 与 shell-level policy seam。

## Open Questions

- 是否需要为个别顶级页面允许强制显示 titlebar title，例如 search-active state 或特殊 workspace mode？
- 顶级页面的 `leadingTitle` 在隐藏时是否应该完全不构建，还是构建但不布局以保留语义测试 hooks？
- 独立 subwindow 是否应使用同一 secondary-route close policy，还是只对主窗口 route stack 生效？
