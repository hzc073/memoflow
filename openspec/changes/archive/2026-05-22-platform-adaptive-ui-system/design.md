## Context

当前项目已经有平台适配的基础，但覆盖不均：

- `PlatformTarget`、`PlatformPage`、`PlatformListTile`、`PlatformGroupedList` 等提供了早期平台 seam。
- `DesktopShellHost` 已能在 macOS 与 Windows 桌面外壳之间路由。
- `AppleMacosPageShell`、`WindowsDesktopPageShell`、`WindowsDesktopWorkspaceShell` 已经存在，但主要集中在主页和部分桌面交互。
- 大量二级页面仍使用移动端 mental model：全宽按钮、全宽卡片、bottom sheet、单列 ListView、触摸优先间距和移动端导航。

这不是一个“调大窗口”问题，而是平台交互模型问题：

```text
Mobile-first page
  ├─ full-width primary actions
  ├─ bottom sheets
  ├─ large touch rows
  └─ single-column navigation

Desktop platform expectation
  ├─ sidebar / toolbar / command bar
  ├─ bounded content widths
  ├─ dialogs / popovers / inspectors
  ├─ denser lists and keyboard/right-click behavior
  └─ window/menu/shortcut semantics
```

架构上，项目处于 `evolve_modularity`，modularity score 为 `4/10`。平台 UI 改造如果直接在 feature pages 中散落 `TargetPlatform` 分支，会加剧耦合；因此总方向必须是“先建 seam，再分批迁移”。

## Goals / Non-Goals

**Goals:**

- 让平台差异成为系统性设计，而不是页面级临时分支。
- 为 macOS、Windows、iPadOS、iPhone、Android 建立可持续的 UI 语义映射。
- 保留同一套业务状态、repository、provider、数据模型和 feature ownership。
- 后续迁移批次能围绕同一 change 和 task map 展开，避免上下文丢失。
- 每个迁移批次都能独立验证，并保持 touched area equal or better structured。

**Non-Goals:**

- 不一次性重写 100+ 个页面。
- 不复制完整平台专属 feature tree。
- 不把平台 adapter 变成业务逻辑层。
- 不改变商业/public-private 边界。
- 不要求所有平台同时达到最终状态；允许按高感知区域优先迁移。

## Decisions

### 1. 使用 semantic adaptive components，而不是 scattered platform branches

后续平台 UI 改造应优先增加或复用语义组件：

```text
Feature page
  │
  ▼
Adaptive UI semantics
  ├─ AdaptiveScaffold / PlatformPage
  ├─ AdaptiveCommandBar
  ├─ AdaptivePrimaryAction
  ├─ AdaptiveListSection
  ├─ AdaptiveDialog / AdaptivePicker
  ├─ AdaptivePopoverOrSheet
  ├─ AdaptiveMasterDetail
  └─ AdaptiveFormControl
       │
       ├─ iPhone: tab / full-screen / sheet
       ├─ iPad: sidebar / split view / popover
       ├─ macOS: sidebar / toolbar / dialog / inspector
       ├─ Windows: sidebar or rail / command bar / preview pane
       └─ Android: existing Material behavior
```

备选方案是直接在每个页面内写 `if macOS` / `if windows`。这短期快，但会导致页面逻辑膨胀，后续 AI 和人工都很难判断哪些差异是产品策略、哪些只是临时补丁。结论：页面可以在迁移初期有少量 bridge code，但最终差异应沉淀到 platform/adaptive seam。

### 2. 保持 feature ownership，平台 seam 只负责呈现策略

依赖方向目标：

```text
features/* pages
  ├─ own feature-specific composition and state reading
  └─ call platform/adaptive UI components

platform/adaptive
  ├─ owns platform visual and interaction mapping
  └─ MUST NOT import features/state/application/data

desktop shell host
  ├─ owns desktop shell composition
  └─ routes to macOS / Windows / Linux shell strategies
```

这能避免 `platform -> features`、`core -> features` 或 `application -> features` 的新增反向依赖。

### 3. 桌面端优先做“高感知路径”，不是平均铺开

优先级不是按文件数量，而是按用户每天感知：

```text
P0: App shell / navigation / window chrome
P1: memo list + detail preview + editor / compose
P2: settings center + preferences + account/security
P3: onboarding / login / workspace selection
P4: collections / resources / review / AI / stats
P5: debug / low-frequency tools
```

这允许先解决“整个软件在桌面端奇怪”的主观感受，而不是被低频页面拖住。

### 4. 平台策略按交互模型分，而不是只按 OS 名称分

平台差异要考虑设备形态：

| Target | Primary model | Typical UI |
| --- | --- | --- |
| iPhone | 手持、单手、全屏流 | tab、navigation stack、bottom sheet、full-width action |
| iPad | 大屏触控、多栏 | sidebar、split view、popover、floating sheet |
| macOS | 桌面窗口、键鼠、菜单 | sidebar、toolbar、dialog、popover、inspector、keyboard shortcuts |
| Windows | 桌面工作台、键鼠 | sidebar/rail、command bar、preview pane、context menu |
| Android | 保持当前 Material/mobile | existing Material behavior |

所以 `Apple` 不等于同一套 UI。iPhone、iPad、macOS 应共享 Apple 视觉语义，但 shell 和交互不同。

### 5. 每个迁移批次必须留下进度和验收记录

`tasks.md` 将作为长期路线图。每个批次完成后应更新对应 task 状态或新增后续子任务，避免下一次工作只看到局部 change 而忘记整体目标。

批次完成定义：

- 页面或区域使用 adaptive seam，而不是散落平台分支。
- 桌面端控件密度、按钮宽度、弹窗/菜单形式符合目标平台。
- 移动端现有行为未回退。
- 有 focused tests、golden/screenshot/manual smoke checklist 或 architecture guardrail 支撑。

## Risks / Trade-offs

- [Risk] 总纲 change 过大，实际执行失焦。  
  Mitigation：tasks 分阶段，优先 P0/P1/P2；每次 apply 只取一个小批次。

- [Risk] 为平台差异抽象过度，组件变得难用。  
  Mitigation：从真实页面迁移中提取 seam，不提前设计过多泛型 API。

- [Risk] 桌面端改造破坏移动端体验。  
  Mitigation：所有 adaptive 组件必须保留当前 mobile fallback；高风险页面加 mobile focused tests。

- [Risk] macOS 与 Windows 混用同一 desktop shell 造成两边都不像。  
  Mitigation：`DesktopShellHost` 只作为组合入口，具体 shell strategy 可按平台分化。

- [Risk] 平台 adapter 反向依赖 feature/state。  
  Mitigation：增加 architecture guardrail，限制 `platform/adaptive` 依赖方向。

- [Risk] public shell 混入商业/private hooks。  
  Mitigation：沿用并扩展 commercial leakage guardrails；平台 UI change 不承载 paid feature logic。

## Migration Plan

1. 建立 UI inventory：标记每个高感知页面当前使用的 scaffold、action、dialog、sheet、picker、list、form、navigation、desktop behavior。
2. 建立或整理 adaptive UI seam：优先覆盖 primary action、dialog/picker、popover/sheet、bounded content、list section、desktop page wrapper。
3. 迁移 P0 shell/navigation：让 macOS / Windows / iPad / mobile 外壳策略更清晰。
4. 迁移 P1 memo 主流程：list、preview、detail、editor、compose、context menu、keyboard/right-click。
5. 迁移 P2 settings：settings center、preferences、account/security、platform grouped lists、desktop dialog/picker。
6. 迁移 P3 onboarding/login/workspace：避免移动端控件在桌面端全宽拉伸。
7. 迁移 P4/P5 低频但高复杂页面，并补齐 smoke checklist。
8. 持续收缩散落平台分支，沉淀 guardrails。

回滚策略：每个批次只迁移有限区域；如某个平台出现回归，可让 adaptive seam 暂时回退到现有 Material/mobile behavior，而不回滚业务逻辑。

## Open Questions

- 是否需要截图基线工具来持续检查桌面端视觉密度和按钮拉伸？
- macOS 与 Windows 是否都应有独立 UI token，还是先共享 desktop token 再分化？
- iPad 是否与 macOS 同批处理，还是作为 Apple touch-large-screen 独立阶段？
- 设置页是否先整体迁移，还是先迁移 `SettingsScreen` + `PreferencesSettingsScreen` 两个样板？
- memo editor 是否先解决 desktop modal/fullscreen 体验，还是先统一编辑器 toolbar 和 action placement？
