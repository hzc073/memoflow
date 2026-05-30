## Why

桌面端部分二级任务页面仍使用普通 `Scaffold + AppBar`，在 macOS 无边框主窗口中容易让返回按钮、标题或首个操作控件进入系统红黄绿按钮区域。创建/编辑合集这类任务更接近“临时编辑任务”，继续作为完整页面推进会放大窗口 chrome、安全区和返回语义差异。

当前架构阶段为 `evolve_modularity`，本 change 触及平台 UI 和桌面二级页面 chrome 规则，主要关联模块化清单第 6、8、10 项；通过抽取共享桌面任务表面和 guardrail，避免继续在 feature 页面里手写平台分支或 magic padding。

## What Changes

- 新增桌面二级任务表面规则：桌面端任务型二级流程优先使用统一的居中任务弹窗或等价桌面任务面板，而不是普通完整页面 `AppBar`。
- 明确分类边界：创建/编辑合集、管理合集条目、重排、导入/配置等短任务可迁移到任务弹窗；合集详情、阅读器、文章流、附件预览等阅读/浏览型页面继续保持完整页面。
- 提供共享容器 seam，承载标题、关闭/取消、底部操作栏、滚动内容、未保存确认、桌面尺寸约束和窗口 chrome 避让。
- 首批迁移范围限定为 collections 相关任务页面，优先覆盖 `CollectionEditorScreen`，并评估 `ManualCollectionManageScreen` 是否纳入同批。
- 增加测试或 guardrail，防止新迁移的桌面任务页面回退为 page-local `Scaffold + AppBar` 或手写 macOS traffic-light padding。
- 不改变 API、数据库、同步协议、付费/私有扩展边界，也不把阅读器或详情页强制弹窗化。

## Capabilities

### New Capabilities

- `desktop-secondary-task-surfaces`: 定义桌面端二级任务流程的统一任务弹窗/面板呈现、关闭语义、尺寸约束、未保存确认和可验证行为。

### Modified Capabilities

- `secondary-page-navigation`: 补充 full-page 二级页面与 task-like secondary surface 的分类规则，避免把所有二级流程都强制表现为完整页面返回 AppBar。
- `desktop-window-chrome-safe-area`: 补充桌面任务弹窗/面板参与窗口控制避让的要求，确保任务表面不与 macOS traffic lights 或其他平台窗口控制区域重叠。
- `platform-adaptive-ui-system`: 补充任务型流程在桌面端使用 dialog/panel、移动端保留页面或 sheet 的平台适配规则。
- `desktop-titlebar-navigation-context`: 补充桌面任务弹窗不属于主窗口 titlebar pushed route 的规则，避免把任务关闭语义放进系统窗口控制区。

## Impact

- 主要代码范围：`memos_flutter_app/lib/platform/widgets/`、`memos_flutter_app/lib/features/collections/collection_editor_screen.dart`、可能的 `memos_flutter_app/lib/features/collections/manual_collection_manage_screen.dart` 和 collections 入口路由。
- 测试范围：platform widget tests、collections 相关 widget tests、desktop window chrome safe-area guardrail、必要的 architecture guardrails。
- 架构影响：新增或复用 platform 层共享 seam，feature 页面只表达任务内容和操作，不直接处理 macOS traffic-light 坐标；该 seam MUST NOT import `features/*`、`state/*`、`application/*` 或 `data/*`。
