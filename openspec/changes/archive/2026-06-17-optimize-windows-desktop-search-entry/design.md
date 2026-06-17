## Context

现有桌面首页有两类标题栏路径：

- `WindowsDesktopCommandBar`：渲染顶部命令栏和系统窗口控制按钮。
- `MemosListMacosDesktopTitleBar`：渲染 macOS 原生交通灯安全区、顶部标题栏和 app actions。
- `MemosListScreen` / `MemosListScreenBody`：注入搜索框、快捷按钮、右上角动作和搜索状态。

Windows 曾使用 `MemosListDesktopSearchPresentation.header`，macOS 仍有 `searching` 分支把搜索框渲染到原生标题栏。两者都应改为内容区搜索，保证桌面端交互一致。

## Decisions

### 1. Windows/macOS 搜索承载改为 content search

Windows 和 macOS 桌面搜索应使用与标准搜索一致的内容区搜索状态。点击搜索或触发桌面搜索快捷键时，调用现有 `openSearch` seam，使 `MemosListScreenBody` 渲染搜索模式下的 `SliverAppBar`、搜索框、快捷搜索条和 search landing。

### 2. 顶栏保留排序和搜索入口

Windows 和 macOS 桌面顶部 app action 区保留原有排序入口，并新增/保留搜索按钮。预览面板仍可通过 memo 交互和其它已有逻辑使用，但不再作为右上角命令栏按钮暴露；添加笔记、通知、设置入口也从该动作区移除。

### 3. 保留显式提交搜索语义

搜索页继续复用 `MemosListHeaderController` 的 `draft query` / `submitted query` 规则。输入只更新 draft；点击搜索、键盘 Search/Enter、选择历史或推荐标签才更新 submitted query 并触发结果。

### 4. 模块边界

本次变更只调整 `features/memos` 的 UI/controller 连接和桌面 presentation 策略。不得让 `state/memos`、`application` 或 `core` 新增到 `features` 的反向依赖；不得触碰 API 层。

## Risks / Trade-offs

- 移除右上角添加笔记、通知、设置会降低这些入口在桌面顶部 chrome 的显性程度；本次按需求接受该取舍。
- 移除右上角预览按钮后，依赖该按钮开关预览面板的测试和用户路径需要改为验证排序、搜索入口，以及保留 memo 交互打开预览的现有路径。
- 将桌面搜索统一为 content search 会影响桌面快捷键搜索焦点路径，需要用 controller 或 route delegate 测试覆盖。
