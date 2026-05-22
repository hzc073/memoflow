## Window Chrome Smoke Checklist

### macOS 主窗口

- 打开主窗口后，左侧 sidebar / rail 的首个可见内容不与 red / yellow / green traffic lights 重叠。
- 在 rail 宽度和 expanded sidebar 宽度之间 resize，toolbar title / quick actions 不进入 traffic-light 区域。
- 页面包含 secondary pane 或 modal surface 时，顶部 chrome 避让仍保持稳定。
- dark mode 下 titlebar / sidebar 背景和分隔线没有异常错位。
- 窗口背景拖拽仍可移动窗口，不被纯布局 padding 破坏。

### macOS Settings Subwindow

- 从主窗口打开设置独立窗口后，“设置”标题显示在 traffic lights 右侧。
- 点击右上应用内关闭按钮仍能隐藏 settings subwindow。
- 设置窗口 resize 到最小宽度附近时，标题可正常 ellipsis，sidebar 和内容区域不互相覆盖。
- dark mode 下标题栏、左侧导航和右侧内容区域边界清晰。

### Windows / Non-macOS 回归

- Windows frameless settings window 不获得 macOS leading traffic-light inset。
- Windows desktop command bar / caption controls 保持原位置。
- 移动端 / web 不出现额外 desktop titlebar padding。
