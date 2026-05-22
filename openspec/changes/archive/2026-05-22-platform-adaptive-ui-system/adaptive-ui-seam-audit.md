# Adaptive UI Seam Audit

Last updated: 2026-05-20

本审计对应任务 2.1，用于记录当前 `platform/` adapters、desktop shell host 与高感知 UI 模式的覆盖缺口。它不是一次性最终结论；后续每个 migration batch 应继续补充。

## Existing Platform / Adaptive Seams

| Seam | File | Current Coverage | Gap |
| --- | --- | --- | --- |
| Platform target detection | `lib/platform/platform_target.dart` | iPhone / iPad / macOS / Windows / Linux / web target resolution | 已可用；后续应避免新增零散 `defaultTargetPlatform` 分支 |
| Platform route | `lib/platform/platform_route.dart` | Apple mobile uses Cupertino route; others fallback | 需要审计 desktop modal/secondary pane flows |
| Platform scroll behavior | `lib/platform/platform_scroll_behavior.dart` | Apple bounce physics | 覆盖基础滚动；未覆盖 desktop scrollbars / dense lists |
| Platform page | `lib/platform/widgets/platform_page.dart` | Apple mobile Cupertino scaffold; desktop/material fallback | 桌面 page chrome 仍主要依赖 feature/shell 层 |
| Platform grouped list | `lib/platform/widgets/platform_grouped_list.dart` | Apple mobile grouped list; material fallback | 需要 desktop dense row / bounded section 语义 |
| Platform list tile | `lib/platform/widgets/platform_list_tile.dart` | Apple mobile `CupertinoListTile`; material fallback | 需要 desktop row density、hover/selection、trailing actions |
| Platform list section | `lib/platform/widgets/platform_list_section.dart` | Apple grouped sections, desktop bordered dense rows, Material mobile touch rows | 可作为 settings/forms 迁移目标；hover/selection/table-like 行为留给具体批次 |
| Platform adaptive layout | `lib/platform/widgets/platform_adaptive_layout.dart` | Bounded single-column content and desktop master-detail helper | 可作为 onboarding/login/settings/memo/resources 等批次的布局基础；具体 pane state 仍由 feature owning layer 管理 |
| Platform controls | `lib/platform/widgets/platform_controls.dart` | switch/checkbox/radio/slider/progress/text field | 缺少 semantic primary action、segmented/search/form layout |
| Platform primary action | `lib/platform/widgets/platform_primary_action.dart` | mobile / narrow desktop full-width fallback, regular desktop bounded primary button, filled/tonal/outlined/text variants | 已可供 onboarding/login/settings/memo 等后续批次迁移；尚未大范围替换 feature 页面 |
| Platform dialog | `lib/platform/widgets/platform_dialog.dart` | Alert dialog abstraction | 需要更系统地迁移 feature dialogs |
| Platform popover or sheet | `lib/platform/widgets/platform_popover_or_sheet.dart` | iPhone/iPad uses Cupertino popup, Android/web uses Material bottom sheet, desktop uses bounded dialog surface | 桌面 generic popover 仍是 dialog-like surface；anchored popover/menu 可在 context action batch 继续细化 |
| Platform action sheet | `lib/platform/widgets/platform_action_sheet.dart` | Delegates to `showPlatformPopoverOrSheet` | 已避免 desktop bottom sheet fallback；feature call sites 尚未大范围迁移 |
| Platform picker | `lib/platform/widgets/platform_picker.dart` | Delegates to `showPlatformPopoverOrSheet` with bounded desktop width | enum/date/font/theme/value picker call sites 需要在 settings batch 迁移 |
| Desktop shell host | `lib/features/home/desktop/desktop_shell_host.dart` | macOS / Windows shell routing | 主要服务 home-like shell；二级页面覆盖不均 |
| Apple macOS page shell | `lib/features/home/desktop/apple_macos_page_shell.dart` | macOS sidebar + toolbar shell | 需要避免被 Windows shell 语义污染 |
| Windows desktop shells | `lib/features/home/desktop/windows_desktop_*.dart` | Windows command bar / workspace shell / pane | 需要保持 Windows-specific，不作为 macOS final UI |

## Immediate Missing Seams

| Missing Seam | Why It Matters | First Candidate Task |
| --- | --- | --- |
| Bounded desktop primary action | 解决桌面按钮被移动端 full-width 拉伸的问题 | 2.2 completed; later feature batches migrate call sites |
| Desktop bounded content helper | 解决单列页面和卡片在宽窗口无限拉伸的问题 | 2.5 completed; later batches migrate call sites |
| Adaptive dialog / picker / popover-or-sheet | 统一桌面 bounded dialog surface 与移动 sheet/popup 入口；大量 feature 直接 `showDialog` / `showModalBottomSheet` 仍需后续迁移 | 2.3 completed; later feature batches migrate call sites |
| Desktop dense list/form section | 设置页和资源页仍像移动端大卡片列表 | 2.4 completed; later batches migrate call sites |
| Master-detail helper | memo/resources/collections/review 需要稳定 preview/inspector 模式 | 2.5 completed at seam level; later feature batches migrate stateful flows |
| Context action seam | right-click / menu / popover 未统一 | Memo / resources batches |
| Smoke checklist storage | 手动窗口/menu/shortcut 检查目前分散在任务文字里 | 8.3 |

## Guardrail Coverage

任务 2.6 已收紧 `test/architecture/platform_ui_guardrail_test.dart`：

- 明确要求核心 adaptive seam 文件存在，包括 primary action、popover/sheet、picker、list section、bounded layout。
- 递归扫描 `lib/platform/**`，禁止导入 `features/*`、`state/*`、`application/*`、`data/*`。
- 继续阻止 public platform seam 中出现商业 / private 逻辑关键词。

该 guardrail 只覆盖 shared `platform/` seam。已有 `core/windows_adaptive_surface.dart` 仍是 Windows 专用 surface，后续 shell/settings/memo 批次可按实际迁移策略决定是否收口到新的 shared seam。

## High-Frequency Direct Widget Usage

粗略代码搜索显示，feature 层仍大量直接使用：

- `FilledButton` / `ElevatedButton` / `OutlinedButton`
- `showDialog` / `AlertDialog`
- `showModalBottomSheet`
- `PopupMenuButton`
- `DropdownButton`

这些不一定都要立刻替换；迁移原则是：

1. 高感知页面先迁移；
2. 先迁移“桌面明显错误”的控件，例如 full-width primary action、desktop bottom sheet；
3. 每次替换都通过语义 seam 复用，不在页面内新增平台分支；
4. 保留移动端现有行为。

## First Implementation Slice

第一个 runtime slice 应选择低风险、可复用、能直接回应用户痛点的 seam：

```text
PlatformPrimaryAction
  ├─ mobile / narrow desktop: full width
  ├─ desktop / regular: bounded width
  ├─ supports filled / tonal / outlined / text variants
  └─ used by future onboarding/login/settings migrations
```

本 slice 不应直接迁移所有页面；先建立组件和测试，再由后续 batch 逐页采用。
