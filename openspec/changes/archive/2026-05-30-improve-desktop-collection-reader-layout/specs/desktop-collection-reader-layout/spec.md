## ADDED Requirements

### Requirement: Desktop collection reader uses a centered readable width
桌面端合集连续阅读器 SHALL 使用居中的可读内容宽度，避免在宽屏窗口中把正文横向拉满；阅读背景、亮度遮罩和整体触摸/鼠标容器 SHALL 继续覆盖整个阅读窗口。

#### Scenario: Wide desktop window shows centered content
- **GIVEN** 用户在桌面端打开合集连续阅读器
- **AND** 窗口宽度大于标准阅读版心宽度
- **WHEN** 阅读正文显示
- **THEN** 正文内容 SHALL 被限制在标准阅读版心内
- **AND** 正文内容 SHALL 在可用窗口中居中
- **AND** 阅读背景 SHALL 继续铺满整个窗口

#### Scenario: Narrow desktop window falls back to available width
- **GIVEN** 用户在桌面端打开合集连续阅读器
- **AND** 窗口宽度小于标准阅读版心宽度
- **WHEN** 阅读正文显示
- **THEN** 正文内容 SHALL 使用可用宽度
- **AND** 页面 SHALL NOT 产生横向溢出

#### Scenario: Mobile reader keeps existing width behavior
- **GIVEN** 用户在手机或窄移动视口打开合集连续阅读器
- **WHEN** 阅读正文显示
- **THEN** 正文内容 SHALL 保持移动端现有宽度行为
- **AND** 桌面版心限制 SHALL NOT 让移动端正文异常变窄

### Requirement: Reader modes share the same desktop readable viewport
纵向阅读和分页阅读 SHALL 共享同一套桌面可读视口计算，分页测量、页面渲染和阅读交互区域 SHALL 与实际显示宽高一致。

#### Scenario: Vertical reader uses desktop readable width
- **GIVEN** 用户在桌面宽屏窗口使用纵向阅读
- **WHEN** 正文列表渲染
- **THEN** 每篇内容 SHALL 使用桌面可读宽度
- **AND** 章节分隔、正文、图片和 RSS 内容 SHALL 与该可读宽度对齐

#### Scenario: Paged reader measures with desktop readable width
- **GIVEN** 用户在桌面宽屏窗口使用分页阅读
- **WHEN** 系统计算章节页数
- **THEN** 分页引擎 SHALL 使用桌面可读宽度和可读高度
- **AND** 渲染出的页面内容 SHALL NOT 按整窗宽度重新排版

#### Scenario: Paged reader interactions use visible page bounds
- **GIVEN** 用户在桌面宽屏窗口使用分页阅读
- **WHEN** 用户点击、拖拽、滚轮或键盘翻页
- **THEN** 翻页命中区域和动画预览 SHALL 与可见分页内容的边界一致
- **AND** 中心区域唤醒菜单 SHALL 仍然可用

### Requirement: Reader content width is user configurable
合集连续阅读器 SHALL 提供可持久化的内容宽度设置，至少支持窄、标准、宽、跟随窗口四种选择；桌面默认 SHALL 使用适合长文阅读的标准宽度。

#### Scenario: User changes content width
- **GIVEN** 用户打开合集阅读器样式或更多设置
- **WHEN** 用户选择窄、标准、宽或跟随窗口
- **THEN** 阅读正文 SHALL 按所选宽度重新布局
- **AND** 选择 SHALL 持久保存到合集阅读偏好中

#### Scenario: Existing preferences have no content width
- **GIVEN** 用户已有旧版本阅读偏好
- **AND** 偏好数据没有内容宽度字段
- **WHEN** 应用读取合集阅读偏好
- **THEN** 系统 SHALL 使用标准宽度作为默认值
- **AND** 旧偏好 SHALL NOT 读取失败

#### Scenario: Full width mode preserves current wide layout
- **GIVEN** 用户选择跟随窗口
- **WHEN** 用户在桌面宽屏窗口阅读
- **THEN** 正文 SHALL 可以接近当前跟随窗口的宽度行为
- **AND** macOS 标题栏安全区 SHALL 仍然生效

### Requirement: Desktop reader chrome aligns with readable content
桌面端合集连续阅读器的提示栏、底部控制栏、进度条和浮动操作区 SHALL 与阅读版心协调布局，避免在宽屏窗口中过度分散；背景遮罩和菜单拦截层 SHALL 继续覆盖整个窗口。

#### Scenario: Tip bars align with readable content
- **GIVEN** 用户在桌面宽屏窗口启用页眉或页脚提示栏
- **WHEN** 提示栏显示
- **THEN** 提示栏文字 SHALL 与阅读版心对齐或使用不超过控制区最大宽度的布局
- **AND** 提示栏 SHALL NOT 横跨整窗造成阅读信息分散

#### Scenario: Bottom controls remain reachable on wide desktop
- **GIVEN** 用户在桌面宽屏窗口唤醒阅读菜单
- **WHEN** 底部控制栏和进度条显示
- **THEN** 控制栏 SHALL 保持居中且易于扫视
- **AND** 主要按钮 SHALL NOT 被推到远离正文的窗口边缘

#### Scenario: macOS native window controls remain unobstructed
- **GIVEN** 用户在 macOS 主窗口中打开合集连续阅读器
- **WHEN** 正文或阅读菜单显示
- **THEN** 正文、菜单首个交互控件和提示栏 SHALL 避开原生窗口按钮区域
- **AND** 系统 SHALL NOT 通过隐藏 macOS 原生窗口按钮来解决遮挡

### Requirement: Desktop collection reader layout preserves architecture boundaries
桌面合集阅读布局 SHALL 使用 feature-local pure helper 或现有稳定 platform/core seam 表达布局策略，并 SHALL NOT 引入新的反向依赖或把可复用布局规则继续散落在大型 widget 中。

#### Scenario: Layout policy is implemented
- **WHEN** 桌面合集阅读版心计算被实现
- **THEN** 版心、可读视口和控制区宽度规则 SHALL 位于可单元测试的 helper 或等价 seam 中
- **AND** `state`、`application`、`core` 层 SHALL NOT import `features/collections` UI 文件

#### Scenario: Reader layout is tested
- **WHEN** 桌面合集阅读布局实现完成
- **THEN** 系统 SHALL 包含覆盖桌面宽屏、窄窗口、移动端、macOS 标题栏安全区和分页测量一致性的测试
- **AND** guardrail SHALL 防止 feature 文件重新硬编码 macOS traffic-light padding 或绕开共享 safe-area seam

#### Scenario: API compatibility area remains untouched
- **WHEN** 本 change 被实现
- **THEN** `memos_flutter_app/lib/data/api` 和 `memos_flutter_app/test/data/api` SHALL NOT 被修改，除非用户另行明确批准
- **AND** 公共仓库 SHALL NOT 新增订阅、付费、entitlement、receipt、paywall、StoreKit 或其他商业逻辑
