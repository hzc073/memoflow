# Platform Adaptive UI Migration Inventory

Last updated: 2026-05-20

本文档是 `platform-adaptive-ui-system` 的长期工作底图。后续每个 implementation batch 都应先对照这里选择一个小范围，再在完成后更新状态，避免平台 UI 改造退化成零散页面修补。

## Status Legend

| Status | Meaning |
| --- | --- |
| `mobile-expanded` | 主要是移动端布局在桌面端直接拉宽，存在全宽按钮、全宽卡片、bottom sheet 或触摸优先间距问题 |
| `partial-desktop-shell` | 已有桌面 shell、preview pane、toolbar、shortcut 或窗口集成，但覆盖不完整 |
| `adaptive-seam-ready` | 已有可复用的 platform/adaptive seam，可作为后续迁移基础 |
| `migrated` | 已按目标平台交互模型迁移，并有测试、guardrail 或 smoke checklist 支撑 |
| `blocked` | 需要先解决架构、设计或平台运行时问题 |
| `accepted-as-is` | 当前行为可接受，不计划迁移；必须记录原因 |

## Platform Target Matrix

| Area | iPhone | iPadOS | macOS | Windows | Android / Linux / Web |
| --- | --- | --- | --- | --- | --- |
| Shell | tab / navigation stack | sidebar or split view | sidebar + toolbar + native window/menu semantics | sidebar/rail + command bar + window controls | existing Material or platform fallback |
| Navigation | full-screen pushes, back gesture | split navigation with detail persistence | menu/shortcut aware routing, visible sidebar | desktop navigation rail/sidebar, preview-aware routing | current Material navigation |
| Primary action | full-width bottom or inline action | bounded action or toolbar action | toolbar/dialog action or bounded button | command bar/dialog action or bounded button | current Material behavior |
| Transient UI | action sheet / bottom sheet | popover or form sheet | dialog / popover / menu / inspector | dialog / menu / command surface | current Material behavior |
| List / form | touch rows, full-width groups | grouped lists, split form | dense rows, grouped settings, bounded form width | dense rows, table/list, bounded content | current Material behavior |
| Keyboard / right-click | minimal, text editing | hardware keyboard where useful | first-class shortcuts, menu commands, context menus | first-class shortcuts, context menus | keep current behavior unless platform-specific |
| Window / safe area | notch and bottom safe area | multitasking safe area | traffic lights, titlebar, window menu, resize | frameless/window controls where applicable | existing shell behavior |

## High-Perception Inventory

| Area | Current Status | Target Direction | Notes / Next Batch |
| --- | --- | --- | --- |
| App shell / navigation | `migrated` | Keep `DesktopShellHost` as desktop composition seam; differentiate macOS, Windows, iPad, mobile shells | Tasks 3.1-3.5 completed at shell-boundary level; page-level polish remains in later batches |
| Onboarding / first setup | `migrated` | Bounded desktop content and primary action; mobile layout unchanged | Tasks 4.1, 4.3, 4.4 completed; covered by `test/features/onboarding/platform_adaptive_onboarding_test.dart` |
| Login / server setup / workspace selection | `migrated` | Bounded desktop forms, adaptive dialogs/pickers, platform-appropriate primary action | Task 4.2 completed for `LoginScreen` and `LocalModeSetupScreen`; deeper account/workspace management remains in later settings/memo batches |
| Settings center | `migrated` | Desktop bounded/split settings, Apple grouped lists, adaptive value rows and pickers | Tasks 5.1-5.5 completed for `SettingsScreen`; deeper account/security subpages remain in later settings follow-ups |
| Preferences settings | `migrated` | Pilot page for adaptive grouped list, picker, row and primary action seams | Tasks 5.1-5.5 completed for `PreferencesSettingsScreen`; custom theme dialog remains feature-owned but opens from adaptive rows |
| Memo list | `migrated` | Desktop density, selection, hover, right-click, preview pane, keyboard navigation | Tasks 6.1-6.2 completed; macOS/Windows/Linux desktop right-click uses memo action popover; non-Windows split layout extracted to feature-owned seam |
| Memo detail | `migrated` | Bounded reading width, desktop action placement, context menu, media preview integration | Task 6.3 completed for bounded desktop document width and secondary-click context menu; existing image/video preview launcher retained |
| Memo editor / compose | `migrated` | Desktop modal/fullscreen polish, toolbar/action placement, shortcuts, attachment handling | Task 6.4 completed at presentation seam level; existing desktop modal/fullscreen, header actions, Esc and Ctrl/Cmd+Enter save protected by focused tests |
| Collections / reader | `partial-desktop-shell` | Master-detail, reader width, toolbar, popover actions | Task 7.1 审计完成；后续单独 reader shell 批次继续迁移 |
| Resources | `migrated` | Desktop list/table, filter/search, preview/context action behavior | Task 7.2 completed；桌面 dense table/search/filter/right-click，移动端 card grid fallback |
| Review / AI summary / Explore | `partial-desktop-shell` | Command placement, bounded reading width, side panels and adaptive transient UI | Task 7.3 部分迁移；AI 检索预览已 bounded，Explore/Review transient UI 仍 pending |
| Stats | `migrated` | Dashboard grid, chart constraints, desktop action placement | Task 7.4 completed；桌面 dashboard + calendar split，移动端 stacked fallback |
| Debug / low-frequency tools | `mobile-expanded` | Migrate only after high-perception paths, unless a regression appears | Task 7.5 |

## Cross-Cutting Inventory

| UI Concern | Current Status | Target Direction | Notes / Next Batch |
| --- | --- | --- | --- |
| Scaffold / page chrome | `adaptive-seam-ready` | Extend `PlatformPage` / `DesktopShellHost` semantics rather than page-local platform branches | Tasks 2.1, 3.1-3.5 completed at shell-boundary level |
| Primary actions | `adaptive-seam-ready` | Use `PlatformPrimaryAction` for mobile full-width actions, narrow desktop fallback, and bounded regular desktop buttons | Task 2.2 completed; migrate high-perception pages in later batches |
| Dialogs / alerts | `adaptive-seam-ready` | Use `showPlatformDialog` / `showPlatformAlertDialog` for confirm/destructive flows | Existing seam documented under Task 2.3; feature call sites migrate later |
| Pickers | `migrated` | Use `showPlatformPicker`, backed by desktop bounded dialog and mobile sheet/popup behavior | Task 5.3 completed for language/font size/line height/font/launch action/appearance selectors in preferences; broader date/theme sub-dialogs remain per-feature |
| Sheets / popovers / menus | `adaptive-seam-ready` | Use `showPlatformPopoverOrSheet` or `showPlatformActionSheet`; desktop no longer defaults to bottom sheet | Task 2.3 completed; menu/context action work remains in feature batches |
| Grouped lists / rows | `migrated` | Use `PlatformListSection` / `PlatformListSectionRow` for Apple grouped lists, desktop dense rows, and mobile touch rows | Task 5.1 completed for settings center and preferences pilot; remaining feature pages migrate in later batches |
| Forms / text inputs | `partial-desktop-shell` | Bounded desktop forms, platform search/text field behavior | Login/local setup migrated in Task 4.2; settings pilot bounded in Task 5.2; memo editor forms remain pending |
| Bounded content / master-detail | `adaptive-seam-ready` | Use `PlatformBoundedContent` for single-column max width and `PlatformMasterDetail` for desktop secondary pane choices | Task 2.5 completed; feature batches migrate call sites |
| Route transitions / back | `adaptive-seam-ready` | Keep `platform_route` behavior; audit desktop modal/secondary pane cases | Tasks 3.1, 8.2 |
| Keyboard shortcuts | `partial-desktop-shell` | Preserve existing desktop shortcut model, expand only through feature-owned seams | Tasks 6.1, 8.3 |
| Right-click / context menus | `partial-desktop-shell` | Promote high-frequency item actions to desktop context menus where useful | Tasks 6.2, 7.2 |
| Safe area / window chrome | `partial-desktop-shell` | Keep native semantics per platform; avoid compensating with distorted page layout | Tasks 3.3, 4.3 |
| Dark mode | `partial-desktop-shell` | Maintain platform color tokens and test migrated surfaces in light/dark | Task 8.3 |
| Accessibility | `blocked` | Needs per-batch semantics/focus review once surfaces are migrated | Task 8.5 |
| Smoke checks | `blocked` | Add per-batch manual checklist for shell/window/menu/shortcut/right-click/resize | Tasks 8.3-8.5 |

## Batch Notes

### Onboarding / Login / Workspace 批次 - 2026-05-20

Completed:

- `LanguageSelectionScreen` 使用 `PlatformBoundedContent` 和 `PlatformPrimaryAction`，桌面宽窗口下内容与 Get Started 按钮不再横向拉伸，移动端仍保持 full-width 主操作。
- `LoginScreen` 使用 bounded form；Connect 主操作改为 `PlatformPrimaryAction`，HTTPS/HTTP 确认与握手恢复弹窗改走 `showPlatformDialog` 入口。
- `LocalModeSetupScreen` 使用 bounded content 和 adaptive confirm/cancel actions，本地工作区命名流程在桌面端不再使用全宽按钮。
- macOS 主窗口保留 native traffic lights/titlebar 语义，并设置 `960x640` 最小尺寸与 `1360x860` 模板启动内容尺寸；Windows 主窗口同步到 `1360x860` 初始尺寸，并通过 `WM_GETMINMAXINFO` 设置 `960x640` 最小尺寸。
- Focused tests: `flutter test test/features/onboarding/platform_adaptive_onboarding_test.dart --reporter expanded` 覆盖桌面宽窗口按钮不拉伸、移动端 full-width fallback、窄桌面可滚动访问主操作。

Manual smoke checklist:

```text
Batch: Onboarding / Login / Workspace
Platforms checked:
- [ ] macOS
- [ ] Windows
- [x] mobile fallback via widget test

Checks:
- [ ] window controls / traffic lights / resize behavior
- [ ] menu commands and keyboard shortcuts
- [ ] right-click or context actions where applicable
- [ ] dark mode and inactive window state
- [x] narrow window fallback via widget test
- [x] mobile layout still usable via widget test
- [x] no public commercial leakage
- [x] no new forbidden dependency direction
```

### Settings 批次 - 2026-05-20

Completed:

- `SettingsScreen` 的设置中心内容改用 `PlatformBoundedContent`，桌面宽窗口下最大宽度限制为 `760`，不再把移动端单列设置流直接拉满整个窗口。
- `SettingsScreen` 的分组入口行改用 `PlatformListSection` / `PlatformListSectionRow`；Apple mobile 走 grouped list，桌面端走 dense bordered rows，并保留 private extension settings entry 的公开 seam 渲染方式。
- `PreferencesSettingsScreen` 的语言、字号、行高、字体、启动动作、外观选择器统一改用 `showPlatformPicker`，桌面端使用 bounded dialog，移动端仍使用平台 sheet / popup fallback。
- `PreferencesSettingsScreen` 的 value row、toggle row、theme color row 改用 adaptive list section row；修复 Apple grouped list 中 theme color dot 缺少 Material ancestor 的移动端渲染问题。
- 设置批次没有新增 subscription、billing、entitlement、receipt、paywall、StoreKit、product ID、`AccessDecision.source` 分支或其他商业逻辑。
- Focused tests: `test/features/settings/platform_adaptive_settings_test.dart` 覆盖桌面 bounded settings、Apple grouped list、桌面 picker dialog 和 public shell guardrail。

Manual smoke checklist:

```text
Batch: Settings
Platforms checked:
- [ ] macOS
- [ ] Windows
- [x] mobile fallback via widget test

Checks:
- [ ] window controls / traffic lights / resize behavior
- [ ] menu commands and keyboard shortcuts
- [ ] right-click or context actions where applicable
- [ ] dark mode and inactive window state
- [x] narrow / bounded desktop layout via widget test
- [x] mobile layout still usable via widget test
- [x] no public commercial leakage
- [x] no new forbidden dependency direction
```

### Memo 主流程批次 - 2026-05-20

Completed:

- 新增 `memo-main-flow-audit.md`，记录 `memos_list_screen.dart` 中 desktop preview、editor、shortcut、context menu、primary compose action 和 mobile fallback 的当前状态。
- 将非 Windows desktop drawer/list/preview pane 组合从 `MemosListScreenBody` 抽到 `MemosListDesktopSplitLayout`，主 body 不再内联整段桌面 split Row。
- Memo list 右键菜单从 Windows-only 扩展到 macOS / Windows / Linux desktop target，继续复用 `showMemoCardContextMenu`，移动端长按复制路径不变。
- Memo detail 正文在桌面 route 中使用 `820` 最大阅读宽度并居中；embedded preview pane 不启用二次宽度限制。
- Memo detail 支持 secondary-click context menu，并复用现有 `showMemoDetailActionPopover`；移动端长按菜单不回退。
- Memo editor / compose 继续使用现有 `MemoEditorPresentation.desktopModal` / `desktopFullscreen` seam；补充 Esc 关闭 focused test，保护桌面 chrome 路径。
- Focused tests 覆盖 memo split layout、detail desktop bounded width、detail mobile fallback、desktop secondary-click menu、editor desktop Esc 关闭。

Manual smoke checklist:

```text
Batch: Memo 主流程
Platforms checked:
- [ ] macOS
- [ ] Windows
- [x] mobile fallback via widget test

Checks:
- [ ] window controls / traffic lights / resize behavior
- [x] menu commands and keyboard shortcuts via focused widget tests
- [x] right-click or context actions via focused widget tests
- [ ] dark mode and inactive window state
- [x] narrow / bounded desktop layout via widget test
- [x] mobile layout still usable via widget test
- [x] no public commercial leakage
- [x] no new forbidden dependency direction
```

### Collections / Resources / Review / AI / Stats 批次 - 2026-05-20

Completed:

- 新增 `collections-resources-review-stats-audit.md`，记录 collections/reader、resources、review/AI/explore、stats 的当前桌面 UI 状态和后续 pending。
- `ResourcesScreen` 迁移到桌面 dense list/table：支持搜索、类型筛选、右键 context menu、Preview/Open memo/Download 操作；移动端继续保留 grouped attachment card grid。
- `AiAnalysisPreviewScreen` 使用 `PlatformBoundedContent`，桌面宽窗口下检索预览和证据片段限制到 `860` 最大宽度，移动端列表流不变。
- `StatsScreen` 桌面数据视图使用 `1180` bounded dashboard，日历视图使用 calendar + selected-day split layout；桌面 selected-day memo 使用 compact row，移动端保留 stacked memo card fallback。
- 390px 移动端 Stats 分段控件和统计标题行不再横向溢出。
- Focused tests 覆盖 resources 桌面搜索/右键和移动 fallback、stats 桌面 dashboard/calendar split 和移动 fallback、AI preview 桌面 bounded content。

Manual smoke checklist:

```text
Batch: Collections / Resources / Review / AI / Stats
Platforms checked:
- [ ] macOS
- [ ] Windows
- [x] mobile fallback via widget test

Checks:
- [ ] window controls / traffic lights / resize behavior
- [ ] menu commands and keyboard shortcuts
- [x] right-click or context actions via Resources focused widget test
- [ ] dark mode and inactive window state
- [x] narrow / bounded desktop layout via focused widget tests
- [x] mobile layout still usable via focused widget tests
- [x] no public commercial leakage
- [x] no new forbidden dependency direction
```

## Batch Working Rules

1. 每次 implementation 只选择一个 migration batch，例如 `Onboarding / Login`、`Settings pilot` 或 `Memo list desktop density`。
2. 每个 batch 开始前先更新本 inventory 的目标行，明确当前状态、目标和验收方式。
3. 每个 batch 必须保持移动端 fallback；桌面 UI 改造不能让 iPhone / Android 关键路径回退。
4. 如果 batch 触碰 `home`、`settings`、`memos`、`core`、`application/desktop` 或 shell code，必须包含至少一个 modularity improvement 或 guardrail tightening。
5. 每个 batch 完成后必须：
   - 更新本 inventory 的状态；
   - 勾选或补充 `tasks.md`；
   - 运行 `flutter analyze`；
   - 运行相关 focused tests / architecture guardrails；
   - 对 macOS / Windows shell 批次记录手动 smoke checklist。

## Smoke Checklist Template

每个涉及 shell、窗口或桌面交互的 batch 应复制并填写：

```text
Batch:
Platforms checked:
- [ ] macOS
- [ ] Windows
- [ ] iPhone / iPad or mobile fallback

Checks:
- [ ] window controls / traffic lights / resize behavior
- [ ] menu commands and keyboard shortcuts
- [ ] right-click or context actions where applicable
- [ ] dark mode and inactive window state
- [ ] narrow window fallback
- [ ] mobile layout still usable
- [ ] no public commercial leakage
- [ ] no new forbidden dependency direction
```
