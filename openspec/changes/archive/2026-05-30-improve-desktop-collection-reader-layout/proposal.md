## Why

桌面宽屏下合集连续阅读器会把正文拉得过宽，行长过长导致阅读负担上升；同时纵向阅读、分页阅读、提示栏和控制区域之间缺少统一的桌面阅读版心。现在已经完成合集二级任务弹窗和 macOS 标题栏安全区处理，适合继续把桌面阅读体验收敛成更稳定、可验证的布局能力。

## What Changes

- 为桌面端合集连续阅读器引入居中的阅读版心，正文在宽屏下不再横向拉满，背景仍保持全窗口铺满。
- 让纵向阅读和分页阅读共享同一套桌面阅读版心，分页计算、页面渲染和交互命中区域保持一致。
- 增加阅读内容宽度设置，至少支持窄、标准、宽、跟随窗口等选项，并在桌面端使用更适合阅读的默认值。
- 调整桌面阅读器顶部/底部提示栏、底部控制栏和翻页交互区域，使其与阅读版心协调，避免宽屏下控件过度分散。
- 保留移动端现有阅读布局，不把桌面版心规则强行套到手机宽度。
- 不改动 Memos API 兼容层，不引入订阅、付费、商业或私有扩展逻辑。

## Capabilities

### New Capabilities
- `desktop-collection-reader-layout`: 覆盖桌面端合集连续阅读器的宽屏版心、分页测量、内容宽度设置、提示栏/控制栏对齐和交互区域行为。

### Modified Capabilities
- 无。

## Impact

- 主要影响 `memos_flutter_app/lib/features/collections/collection_reader_shell.dart`、`collection_reader_vertical_view.dart`、`collection_reader_paged_view.dart`、`collection_reader_page_engine.dart`、`collection_reader_style_sheet.dart`、`collection_reader_tip_sheet.dart` 及相关 reader 设置模型。
- 可能需要调整或新增 `DevicePreferences` 中的合集阅读显示配置字段，并通过既有偏好迁移路径提供默认值；不涉及服务器 API、数据库同步协议或 `memos_flutter_app/lib/data/api`。
- 测试影响包括合集阅读 widget tests、分页引擎 tests、桌面标题栏安全区 guardrail，以及必要的偏好序列化/迁移测试。
- 当前架构阶段为 `evolve_modularity`。本 change 触及 `features/collections` 的阅读器布局热点，但不应新增 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖；若抽取共享布局策略，应放在 feature-local pure helper 或稳定的 platform/core seam，并增加守护测试防止边界变差。
