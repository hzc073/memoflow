## 1. macOS titlebar behavior design

- [x] 1.1 确认 macOS 主窗口采用 hybrid titlebar，而不是全 frameless / Windows-style window controls
- [x] 1.2 定义 traffic-light safe inset、title、pill row、search/sort actions 的布局优先级和窄宽度降级规则
- [x] 1.3 明确 `Cmd+W`、Window menu、close/minimize/zoom/fullscreen 继续由系统窗口语义处理

## 2. Window chrome seam

- [x] 2.1 在 macOS Runner 或平台窗口 seam 中集中设置 full-size content / transparent titlebar 等必要原生窗口属性
- [x] 2.2 确保原生窗口属性仅作用于 macOS main window，不影响 Windows/Linux、不影响 quick input 或 settings sub-window
- [ ] 2.3 验证 traffic lights 仍可见、可点击，并保持系统 hover / inactive 状态

## 3. Flutter titlebar composition

- [x] 3.1 为 macOS 主页添加独立 titlebar composition，复用 `MemosListPillRow` 和现有 quick action 数据
- [x] 3.2 将 macOS 下的三个快捷胶囊从内容 header 移到 titlebar，避免重复显示
- [x] 3.3 保留 Windows 现有 `MemosListWindowsDesktopTitleBar` 行为，不照搬 Windows 右侧窗口控制到 macOS
- [x] 3.4 确保 `DragToMoveArea` 不截获 pill/action buttons 的点击

## 4. Modularity and guardrails

- [x] 4.1 保持 quick action state 与业务逻辑在现有 owners 中，不新增 macOS-only duplicate state
- [x] 4.2 避免 `core` / `application/desktop` 新增 `features/memos` 依赖；如需复用，通过 UI child injection 或 feature-owned composition 完成
- [x] 4.3 增加或更新 guardrail，防止 macOS titlebar 引入 Windows-style self-drawn close/minimize/zoom buttons 或商业化逻辑

## 5. Verification

- [x] 5.1 运行 `flutter analyze`
- [x] 5.2 运行相关 focused widget tests，覆盖 macOS titlebar 显示 pills、Windows 行为不变、窄宽度降级
- [ ] 5.3 在 macOS smoke test 中验证：traffic lights 可用、titlebar 可拖动、pill buttons 可点击、搜索/排序可用、主窗口关闭/最小化/缩放行为正常
- [ ] 5.4 截图检查 light/dark/inactive 状态下标题栏内容不与 traffic lights 或窗口边界重叠
