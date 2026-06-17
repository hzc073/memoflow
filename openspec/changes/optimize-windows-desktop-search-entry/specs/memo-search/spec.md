## ADDED Requirements

### Requirement: Windows desktop search opens in the memo content area

Windows 桌面首页 SHALL 将搜索作为内容区搜索页面呈现，而不是顶部命令栏内联展开搜索框。点击 Windows 桌面右上角搜索按钮或触发等价桌面搜索快捷键时，系统 MUST 进入主笔记列表搜索状态，并在笔记内容区域显示搜索输入、快捷搜索、最近搜索、推荐标签和搜索结果状态。

#### Scenario: Search button opens content search
- **GIVEN** 用户正在 Windows 桌面首页查看笔记列表
- **WHEN** 用户点击右上角搜索按钮
- **THEN** 系统 MUST 在笔记内容区域显示搜索输入框
- **AND** 顶部命令栏 MUST NOT 展开或显示搜索输入框

#### Scenario: Desktop search shortcut opens content search
- **GIVEN** 用户正在 Windows 桌面首页查看笔记列表
- **WHEN** 用户触发桌面搜索快捷键
- **THEN** 系统 MUST 进入与点击右上角搜索按钮相同的内容区搜索状态

#### Scenario: Search landing keeps existing affordances
- **GIVEN** Windows 桌面首页已进入搜索状态
- **AND** 当前 `submitted query` 为空
- **WHEN** 搜索页渲染
- **THEN** 系统 SHALL 显示快捷搜索入口
- **AND** 系统 SHALL 显示最近搜索和推荐标签

### Requirement: Windows desktop command bar keeps search as the only app action

Windows 桌面首页右上角动作区 SHALL 只保留搜索按钮作为 app-level action，并继续保留系统窗口控制按钮。预览、添加笔记、通知和设置入口 MUST NOT 出现在该动作区。

#### Scenario: Only search appears before window controls
- **GIVEN** 用户正在 Windows 桌面首页查看笔记列表
- **WHEN** 顶部命令栏渲染
- **THEN** 右上角 app-level action MUST include a search button
- **AND** 右上角 app-level action MUST NOT include preview, add memo, notifications, or settings buttons
- **AND** 系统窗口最小化、最大化/还原和关闭按钮 SHALL remain available

### Requirement: Windows desktop search preserves explicit submit semantics

Windows 桌面内容区搜索 MUST preserve existing `draft query` / `submitted query` semantics. Editing the search field MUST NOT trigger keyword search until the user explicitly submits the draft query.

#### Scenario: Typing in Windows content search does not query
- **GIVEN** Windows 桌面首页已进入内容区搜索状态
- **WHEN** 用户在搜索框输入文本但尚未提交
- **THEN** 系统 MUST only update `draft query`
- **AND** 系统 MUST NOT start a new keyword search provider query

#### Scenario: Submitting in Windows content search queries
- **GIVEN** Windows 桌面首页已进入内容区搜索状态
- **AND** 搜索框中的 `draft query` trimmed 后非空
- **WHEN** 用户点击搜索 action 或按 Search/Enter
- **THEN** 系统 MUST update `submitted query`
- **AND** 系统 MUST execute keyword search using `submitted query`
