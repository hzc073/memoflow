## Context

当前问题来自桌面端二级任务流程的呈现方式不统一：有些流程已经通过 `PlatformPage` 或桌面 shell seam 处理窗口控制避让，有些流程仍直接使用 `Scaffold + AppBar`。在 macOS 主窗口允许 Flutter 内容延伸到 titlebar 的情况下，普通 `AppBar` 的返回按钮、标题或首个操作控件可能进入红黄绿按钮区域。

`CollectionEditorScreen` 是当前暴露问题的入口：它从 collections 首页 push 进入，用 `PopScope` 保护未保存修改，用 `bottomNavigationBar` 承载保存动作，并在 `AppBar.leading` 上提供返回按钮。这个页面本质是创建/编辑任务，不是阅读或浏览内容页，适合在桌面端改为统一任务弹窗或等价任务面板。

当前架构阶段为 `evolve_modularity`。本 change 触及 platform UI seam 和 collections feature 页面，主要关联模块化清单第 6、8、10 项。改动应把平台窗口避让和任务表面规则放到 platform/shared seam，避免在 collections 页面里复制 macOS traffic-light padding。

## Goals / Non-Goals

**Goals:**

- 建立桌面端二级任务流程的统一容器规则，支持标题、关闭/取消、底部操作、滚动内容、未保存确认、尺寸约束和窗口 chrome 避让。
- 首批迁移 collections 里的任务型二级页面，至少覆盖 `CollectionEditorScreen`。
- 在实现前扫描全项目二级页面，产出需要迁移、暂不迁移、需人工判断的页面清单。
- 保持移动端现有页面或 sheet 行为，不为了桌面弹窗改写移动导航。
- 通过测试或 guardrail 防止新迁移页面继续手写 `Scaffold + AppBar` 和 macOS magic padding。

**Non-Goals:**

- 不把合集详情、合集阅读器、文章流、附件预览、memo 详情等阅读/浏览型页面统一改成弹窗。
- 不修改 API、数据库、同步协议、repositories 或 providers 的业务语义。
- 不引入订阅、付费、商业、StoreKit、entitlement 或私有 overlay 行为。
- 不在本 change 中一次性迁移所有设置页和所有历史二级页面；扫描结果可产生后续迁移范围。

## Decisions

### 1. 任务型二级流程使用共享桌面任务表面

桌面端创建、编辑、管理、导入、重排、配置等短任务 SHOULD 使用共享任务表面，例如 `PlatformSecondaryTaskSurface` / `showPlatformSecondaryTaskSurface` 一类 seam。该 seam 位于 `memos_flutter_app/lib/platform/widgets/` 或等价 platform/shared UI 层。

理由：任务型流程的目标是完成或取消一个短任务，居中弹窗/任务面板比完整页面更符合桌面使用预期，也能避开主窗口左上角系统按钮冲突。

备选方案：

- 只给 `CollectionEditorScreen` 的 `AppBar.leading` 增加 macOS 左侧避让。范围小，但会延续 page-local 修补。
- 把所有二级页面都弹窗化。更统一但风险过大，会伤害阅读、详情和预览体验。

### 2. full-page 二级页面和 task surface 明确分类

实现阶段先扫描二级页面，并按以下类型分类：

- `task-surface candidate`：创建/编辑/配置/管理/导入/重排等短任务，可迁移到桌面任务表面。
- `full-page secondary`：详情、阅读、预览、长内容浏览、沉浸工作流，保留完整页面，但必须走安全的 page chrome seam。
- `needs-review`：行为混合或入口复杂，需要人工确认。

理由：统一不等于一刀切。分类先行可以减少误迁移，避免把阅读器、文章流等大面积内容塞进弹窗。

### 3. 首批迁移限定在 collections 任务路径

首批目标至少包括 `CollectionEditorScreen`。`ManualCollectionManageScreen` 是否同批迁移由扫描清单决定：若它主要承担短任务管理，且桌面窗口中存在相同 AppBar/chrome 风险，则纳入同批；否则记录为后续任务。

理由：当前用户反馈来自“合集 -> 创建合集”，优先关闭真实问题，同时用扫描清单为后续范围提供依据。

### 4. 关闭语义由任务表面承载

桌面任务表面不再显示左上 AppBar 返回键。它应提供明确的关闭/取消 affordance，并复用原页面的未保存确认逻辑。保存成功后返回任务结果，取消或关闭时不应误触发应用窗口关闭。

移动端继续保留平台适配页面、sheet 或原有导航语义。若同一 widget 同时服务桌面和移动端，任务内容应尽量抽成可嵌入 body，外层容器按平台选择。

### 5. seam 保持层级安全并增加 guardrail

新增 platform/shared seam MUST NOT import `features/*`、`state/*`、`application/*` 或 `data/*`。collections 页面可以传入内容、标题、actions、关闭回调和结果处理，但不应在 feature 文件中手写 macOS traffic-light 宽度或窗口控制坐标。

依赖方向：

- Before：`features/collections/*` 直接拥有 `Scaffold + AppBar` 和部分桌面返回显示判断。
- After：`features/collections/*` 只提供任务内容和业务回调；桌面任务表面、尺寸、关闭 chrome、窗口控制避让由 `platform/widgets` 或等价 seam 负责。

## Risks / Trade-offs

- [Risk] `CollectionEditorScreen` 内容较长，弹窗高度不足可能影响编辑效率。
  Mitigation：任务表面提供 `maxWidth`、`maxHeightFactor`、内部滚动和固定底部操作栏；小窗口下允许接近全屏但仍保留任务边界。

- [Risk] 迁移后 `ScaffoldMessenger`、`Navigator.pop(result)`、未保存确认上下文变化导致提示或返回结果丢失。
  Mitigation：先抽内容层，再迁移入口；用 widget tests 覆盖保存、取消、未保存确认和返回结果。

- [Risk] 扫描全项目二级页面可能发现范围过大。
  Mitigation：本 change 只要求产出清单并迁移 collections 首批目标；其他页面按清单记录为后续变更。

- [Risk] 统一桌面弹窗可能和现有 Windows adaptive surface 重叠。
  Mitigation：复用或泛化现有 `showWindowsAdaptiveSurface` 思路，避免同时维护两套不一致的大弹窗策略。

## Migration Plan

1. 扫描全项目二级页面入口和 `Scaffold + AppBar` 用法，产出 `secondary-page-inventory.md`。
2. 新增共享桌面任务表面 seam 和基础测试。
3. 抽取 `CollectionEditorScreen` 的可嵌入内容/底部操作，保留业务状态和保存逻辑。
4. 将 desktop collections 创建/编辑入口改为打开任务表面；移动端保持原有 route 或平台适配行为。
5. 根据扫描清单决定是否同批迁移 `ManualCollectionManageScreen`。
6. 增加 collections widget tests、platform tests 和 guardrail。
7. 运行 focused tests、`flutter analyze`、相关 architecture guardrails 和 `openspec validate`。

Rollback 策略：若弹窗迁移导致严重回归，可保留共享 seam 和扫描清单，暂时将 collections 入口切回原 route；已新增 guardrail 可调整为仅覆盖已迁移页面。

## Open Questions

- `ManualCollectionManageScreen` 是否与 `CollectionEditorScreen` 同批迁移，需以扫描清单和实际桌面交互风险确认。
- 桌面任务表面首版是否直接泛化 `showWindowsAdaptiveSurface`，还是新增独立 `PlatformSecondaryTaskSurface` 并逐步替换旧 Windows-only API。
