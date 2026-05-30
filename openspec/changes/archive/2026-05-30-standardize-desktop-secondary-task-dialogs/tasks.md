## 1. 盘点和范围确认

- [x] 1.1 确认 `openspec/config.yaml` 中当前架构阶段仍为 `evolve_modularity`，并记录本 change 触及模块化清单第 6、8、10 项。
- [x] 1.2 确认本 change 不需要修改 API 相关文件；如果发现必须触碰 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，先暂停并取得用户明确批准。
- [x] 1.3 扫描全项目所有二级页面、pushed routes、`fullscreenDialog`、`Scaffold + AppBar`、`PlatformPage`、`showDialog`、`showModalBottomSheet`、`showWindowsAdaptiveSurface` 和桌面 titlebar/chrome 相关入口，列出每个候选页面的路径、入口、当前呈现方式、是否有未保存保护、是否可能进入桌面窗口控制区域。
- [x] 1.4 在 `openspec/changes/standardize-desktop-secondary-task-dialogs/secondary-page-inventory.md` 产出扫描清单，按 `needs-migration`、`keep-full-page`、`needs-review`、`out-of-scope` 分类，并明确需要修改的页面有哪些。
- [x] 1.5 根据扫描清单确认首批迁移范围；至少包含 `memos_flutter_app/lib/features/collections/collection_editor_screen.dart`，并判断 `manual_collection_manage_screen.dart` 是否同批迁移。

## 2. 共享桌面任务表面

- [x] 2.1 在 `memos_flutter_app/lib/platform/widgets/` 或等价 platform/shared UI 层新增共享桌面二级任务表面 seam，支持标题、关闭/取消、内容区、底部操作、尺寸约束、滚动和结果返回。
- [x] 2.2 让共享 seam 在 macOS、Windows、Linux 桌面使用 bounded dialog/panel 呈现，并在移动端允许调用方继续使用现有 route 或 sheet 行为。
- [x] 2.3 复用或泛化现有 `showWindowsAdaptiveSurface` 的尺寸和动画思路，避免形成互相冲突的 Windows-only 与 cross-desktop 弹窗策略。
- [x] 2.4 确保共享 seam 不导入 `features/*`、`state/*`、`application/*`、`data/*` 或 API 代码，也不包含任何私有、商业、订阅、付费、StoreKit、entitlement、receipt 或 paywall 逻辑。
- [x] 2.5 为共享 seam 添加 widget tests，覆盖 macOS 窗口控制避让、Windows/Linux 默认 spacing、bounded size、小窗口可滚动和关闭 affordance 可见。

## 3. Collections 迁移

- [x] 3.1 将 `CollectionEditorScreen` 的任务内容、底部操作和保存/取消逻辑整理为可嵌入共享任务表面的结构，保留现有 validation、repository 写入、RSS preview、manual memo selection 和 `Navigator.pop(result)` 等行为。
- [x] 3.2 将桌面端 collections 创建/编辑入口改为打开共享桌面任务表面；移动端保持现有 page route 或平台适配行为。
- [x] 3.3 保留并验证未保存修改保护：关闭、取消、Esc、点击外部关闭和父级返回都不得静默丢弃编辑内容。
- [x] 3.4 如果 1.5 确认 `ManualCollectionManageScreen` 属于同批迁移范围，将其迁移到共享桌面任务表面；如果不迁移，在 `secondary-page-inventory.md` 记录原因和后续风险。
- [x] 3.5 更新 `add_to_collection_sheet.dart` 中创建手动合集的入口，使桌面端不会从桌面弹窗再 push 一个会被窗口控制遮挡的完整页面。

## 4. Guardrails 和回归覆盖

- [x] 4.1 增加或更新 architecture guardrail，证明共享桌面任务表面 seam 保持 lower-layer safe，且不使用 feature-specific macOS traffic-light magic padding。
- [x] 4.2 增加 collections widget tests，覆盖桌面端打开创建合集、标题和关闭 affordance 可见、不会出现被系统窗口按钮遮挡的 top-left AppBar back、保存后返回结果。
- [x] 4.3 增加未保存确认测试，覆盖创建/编辑合集在桌面任务表面关闭时仍执行确认逻辑。
- [x] 4.4 增加或更新 guardrail，使已迁移的 collections task-like secondary flows 不再回退为 page-local `Scaffold + AppBar` 桌面二级任务页面。
- [x] 4.5 检查 public/private split：确认新增和修改文件没有加入商业、订阅、付费、entitlement、receipt、paywall、StoreKit、private overlay 或 `AccessDecision.source` 业务分支。

## 5. 验证

- [x] 5.1 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 5.2 从 `memos_flutter_app` 运行 focused platform/widget tests，至少覆盖新增共享任务表面和 collections 创建/编辑入口。
- [x] 5.3 从 `memos_flutter_app` 运行相关 architecture guardrails，包括 desktop window chrome safe-area、platform UI、modularity dependency 和新增/更新的 task surface guardrails。
- [x] 5.4 运行 `openspec validate standardize-desktop-secondary-task-dialogs --strict`。
- [x] 5.5 运行 `git diff --check`。
- [x] 5.6 手动验证 Windows、macOS、Linux 桌面端创建/编辑合集：任务表面居中或按平台规则呈现，标题和关闭/取消清晰可见，保存/取消/未保存确认都符合预期；移动端创建/编辑合集仍保持原有可用导航。
