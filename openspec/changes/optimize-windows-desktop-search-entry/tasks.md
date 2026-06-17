## 1. OpenSpec

- [x] 1.1 创建 `optimize-windows-desktop-search-entry` change。
- [x] 1.2 为 `memo-search` 增加 Windows 桌面搜索入口 delta spec。

## 2. 实现

- [x] 2.1 将 Windows 桌面搜索 presentation 从 header search 改为 standard/content search。
- [x] 2.2 调整 Windows 桌面右上角动作区，只保留搜索按钮。
- [x] 2.3 确保点击搜索按钮进入内容区搜索状态，并聚焦内容区搜索框。
- [x] 2.4 移除或旁路 Windows 顶栏搜索展开路径，避免在顶部命令栏显示搜索输入框。

## 3. 测试

- [x] 3.1 更新 Windows title bar / screen body / memo list tests，覆盖右上角只保留搜索。
- [x] 3.2 覆盖点击搜索后搜索框出现在笔记区域而非顶部命令栏。
- [x] 3.3 覆盖 Windows 搜索快捷键进入内容区搜索状态。
- [x] 3.4 运行 focused Flutter tests。
- [x] 3.5 运行 `flutter analyze`。
- [x] 3.6 运行 `openspec validate optimize-windows-desktop-search-entry --type change --strict --no-interactive`。
