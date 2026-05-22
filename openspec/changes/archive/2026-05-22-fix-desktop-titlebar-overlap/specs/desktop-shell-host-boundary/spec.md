## ADDED Requirements

### Requirement: 桌面外壳宿主 SHALL own window chrome safe-area composition
桌面外壳宿主 SHALL 在平台外壳层组合 titlebar、toolbar、navigation 和 window-control safe-area，而不是要求功能页面自行处理系统窗口控件避让。

#### Scenario: 功能页面进入桌面 titlebar 区域
- **WHEN** 某个功能页面向桌面外壳提供 title、leading action、trailing action、command bar 或 navigation content
- **THEN** 桌面外壳宿主必须负责将这些内容放置在对应平台的 window chrome safe area 之外

#### Scenario: 子窗口复用桌面 chrome 规则
- **WHEN** 独立桌面子窗口（例如 settings window）使用自定义 frame、transparent titlebar 或平台窗口控件
- **THEN** 该子窗口必须复用桌面 window chrome safe-area 规则或等价 shell seam，而不是在子页面中重复 hard-coded padding

