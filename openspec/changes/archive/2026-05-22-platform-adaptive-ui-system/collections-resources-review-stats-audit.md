# Collections / Resources / Review / AI / Stats 批次审计

日期：2026-05-20

本文件记录 7.x 批次的桌面端 UI 迁移状态。该批次目标不是一次性重写所有低频页面，而是把桌面端最明显的 mobile-expanded 区域收敛到可验证的 adaptive seam，并明确剩余 pending。

## Collections / Reader

状态：`partial-desktop-shell`

已确认：

- `CollectionReaderScreen` / `CollectionReaderShell` 已使用 `showPlatformActionSheet` 承载大量 reader 操作，桌面端不会全部退回原始 mobile bottom sheet。
- Reader 已有独立 overlay、panel、paged/vertical view、style/padding/tip/search/toc sheet 等 feature-owned 组件，业务状态仍留在 collections feature 内，没有新增平台层反向依赖。
- `CollectionsScreen` 的删除确认使用 `showPlatformAlertDialog`，部分列表操作已进入平台 transient seam。

仍需后续批次：

- Collections 列表和 collection detail 仍以单列卡片/list 流为主，桌面端还缺 master-detail 或 preview pane。
- Reader 主阅读区还需要按桌面窗口校准阅读宽度、toolbar command placement、目录/search/settings 的 popover/inspector 形态。
- `collection_editor_screen.dart`、manual collection 管理和 RSS 订阅/预览仍存在 mobile sheet / full-width 表单，需要后续拆分。

本批结论：7.1 完成审计，暂不强行迁移 reader shell，以免在 reader 引擎和分页布局上做大跨度改动。

## Resources

状态：`migrated`

本批完成：

- `ResourcesScreen` 在 macOS / Windows / Linux 下使用桌面 dense table-like list，不再把移动端附件卡片网格直接拉满宽窗口。
- 新增桌面搜索和类型筛选，支持按文件名、类型、memo UID 过滤。
- 桌面行支持 secondary click context menu，提供 Preview / Open memo / Download 操作。
- 桌面预览缩略图使用更紧凑尺寸，避免 row 内图片预览撑高或溢出。
- 移动端保留原有 grouped card grid fallback。

验证：

- `flutter test test/features/resources/resources_screen_test.dart --reporter expanded`

## Review / AI Summary / Explore

状态：`partial-desktop-shell`

本批完成：

- `AiAnalysisPreviewScreen` 使用 `PlatformBoundedContent`，桌面宽窗口下检索预览和证据片段限制到 `860` 最大宽度，避免阅读型内容横向拉满。
- 扩展 `ai_summary_screen_test.dart` 覆盖桌面宽窗口 bounded preview。

已确认：

- `AiSummaryScreen` 已有部分报告/输入区宽度约束，但 template grid、settings dialog 和删除确认仍有 Material dialog / mobile-ish grid 残留。
- `ExploreScreen` 已有桌面 preview pane 判断和部分 side pane 行为，但评论、reaction、筛选等 transient UI 仍存在 mobile sheet / dialog 路径。
- `DailyReviewScreen` / random walk 仍有较多移动端卡片和 dialog 组合，适合后续独立批次处理。

仍需后续批次：

- AI insight settings 使用 adaptive dialog / picker seam 统一桌面 dialog 与移动 sheet 行为。
- Explore reaction/comment/filter transient UI 迁移到 desktop popover/menu 或 side panel。
- Review / Daily Review deck 在桌面端需要更明确的 command placement、阅读宽度和 keyboard/right-click 行为。

验证：

- `flutter test test/features/review/ai_summary_screen_test.dart --reporter expanded --plain-name "preview screen"`

## Stats

状态：`migrated`

本批完成：

- 数据视图在桌面端使用 `PlatformBoundedContent`，最大宽度 `1180`，宽屏下改为 dashboard row / chart layout。
- 日历视图在桌面端使用左日历、右选中日 memo 列的 split layout。
- 桌面选中日 memo 列使用 compact row，避免把完整移动 memo card 塞入窄 side pane。
- 移动端仍保留 stacked calendar + full memo card fallback。
- 修复 390px 移动端统计标题/分段控件溢出风险。
- `statsCalendarDayMemosProvider` 暴露为测试 seam，UI focused test 可稳定验证布局分支而不依赖后台 DB watcher。

验证：

- `flutter test test/features/stats/stats_screen_test.dart --reporter expanded`

## 本批剩余 Pending

- Collections reader shell 仍需单独桌面阅读器批次。
- Review / AI / Explore 仍需单独 transient UI 和 command placement 批次。
- macOS / Windows 真实窗口 smoke 尚未手动执行，本批通过 widget tests 覆盖 desktop width / right-click / mobile fallback。
