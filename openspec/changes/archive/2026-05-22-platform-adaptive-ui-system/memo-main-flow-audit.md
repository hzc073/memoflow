# Memo 主流程桌面 UI 审计

Last updated: 2026-05-20

本审计对应任务 6.1，用于记录 `memos_list_screen.dart` 及 Memo 主流程相关 widget 中已有的 desktop preview、editor、shortcut、context action 状态，并明确哪些平台行为应继续沉淀到 feature-owned seam，而不是散落在页面主干中。

## 当前状态概览

| 区域 | 当前状态 | 结论 |
| --- | --- | --- |
| Memo list shell | `MemosListScreenBody` 根据 layout state 组合移动 drawer、macOS titlebar、Windows `DesktopShellHost` 和非 Windows desktop side pane | 需要继续保留 feature ownership，但把桌面 split/preview 组合从主 body 抽到 memo-owned seam |
| Windows desktop shell | Windows 宽布局通过 `DesktopShellHost` 提供 navigation、command bar、resizable secondary pane、modal editor surface | 接受为当前桌面主路径；后续 polish 应通过 `DesktopShellHost` / `DesktopHomePaneState` 继续 |
| macOS / 非 Windows desktop split | 之前在 `MemosListScreenBody` 内直接手写 drawer + list + animated preview pane Row | 本批次已抽为 `MemosListDesktopSplitLayout`，降低主 body 中的平台布局分支密度 |
| Preview pane | `MemosListDesktopPreviewPane` 已负责 preview loading/reveal/cache、close/edit actions、音频播放与 MemoDocument 渲染 | 继续作为 memo-owned preview seam；不迁到 shared `platform/`，因为它依赖 memo document state |
| Memo card density/hover/selection | `MemoListCard` 已按 Windows desktop 使用更小 radius/padding、hover/focus color、selected surface/border/shadow | 当前行为可接受；本批次通过列表 body / full screen tests 保护 preview selection |
| Right-click / context menu | Windows desktop memo card 使用 secondary pointer 调 `showMemoCardContextMenu`；detail 新增 secondary tap 调 `showMemoDetailActionPopover` | 列表右键已存在，detail 右键本批次补齐；macOS 列表右键后续可按平台细化 |
| Keyboard navigation / shortcuts | `MemosListDesktopShortcutDelegate` 负责全局 shortcut overview/search/quick input/record/publish/format/page navigation/sidebar/settings 等；主页面补充 Escape、Enter、Ctrl/Cmd+C、Ctrl/Cmd+E 等 selection shortcut | 当前 shortcut seam 已 feature-owned；本批次不重写，只记录并补 editor focused test |
| Primary compose action | 移动端继续 FAB；桌面端宽布局使用 inline compose 或 Windows command bar add action；窄 Windows 可退回 desktop dialog | 当前行为已明显区别移动端；后续需要继续收敛 macOS command placement |
| Detail reading | 原 detail 正文在宽桌面窗口中按移动 ListView 拉满 | 本批次新增 desktop bounded document width，移动端保持全宽流 |
| Detail actions / media | iPhone/iPad/macOS 使用平台 more menu；Windows/Material 展开 actions；image/video preview 仍走已有 `ImagePreviewLauncher` / media grid | 本批次只补 desktop read width 与 right-click；media preview 后续可继续 polish |
| Editor / compose | `MemoEditorPresentation` 已区分页、embedded pane、desktop modal、desktop fullscreen；desktop surface 有 header、fullscreen toggle、close、Esc、Ctrl/Cmd+Enter save | 当前已具备桌面 modal/fullscreen seam；本批次补 Esc focused test，后续再迁移 toolbar/attachments 细节 |
| Mobile fallback | `NoteInputSheet`、page editor fullscreen、mobile drawer swipe/FAB 保持现有路径 | 本批次新增 mobile detail full-width test，并保留 body mobile drawer/floating action tests |

## 本批次收敛点

1. 新增 `features/memos/widgets/memos_list_desktop_split_layout.dart`：
   - 持有非 Windows desktop drawer/list/preview pane 的动画和宽度策略；
   - `MemosListScreenBody` 只决定是否使用该 seam，不再内联整段桌面 Row；
   - 该 seam 留在 `features/memos` 内，避免 `platform/` 反向依赖 memo document / preview state。

2. `MemoDocumentBody` 增加 `boundDesktopReadWidth`：
   - 桌面 detail route 使用 `820` 最大阅读宽度并居中；
   - embedded preview pane 不启用该限制，避免 preview pane 内容被二次压缩；
   - iPhone / Android / mobile fallback 不启用 bounded document key，保持原全宽流。

3. Detail 右键入口：
   - detail 正文支持 secondary tap down，并复用现有 `showMemoDetailActionPopover`；
   - 移动端长按菜单继续保留。

4. Editor focused test：
   - 现有 `MemoEditorPresentation.desktopModal` / `desktopFullscreen` 继续作为桌面 modal/fullscreen seam；
   - 新增 Esc 关闭测试，保护桌面 chrome 路径不退回移动 page fullscreen action。

## 后续剩余工作

- macOS 列表右键和 toolbar command placement 仍可继续细化；当前 Windows 列表右键已覆盖高频路径。
- `MemoListCard` 的 desktop density 目前主要 Windows-specific；如果 macOS 也要更接近原生列表密度，需要单独调整视觉 token。
- Editor toolbar / attachments 在桌面 modal 内仍沿用移动 toolbar 语义，需要后续做更细的 command bar / attachment rail 设计。
- Detail image/video preview 已复用现有 preview launcher；桌面独立 inspector 或 hover controls 尚未做。

## 验收记录

Focused tests:

- `flutter test test/features/memos/widgets/memos_list_screen_body_test.dart --reporter expanded`
- `flutter test test/features/memos/memo_detail_screen_test.dart --reporter expanded`
- `flutter test test/features/memos/memo_editor_screen_edit_draft_test.dart --reporter expanded`

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
