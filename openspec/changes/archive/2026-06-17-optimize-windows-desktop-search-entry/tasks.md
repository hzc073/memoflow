## 1. OpenSpec

- [x] 1.1 创建 `optimize-windows-desktop-search-entry` change。
- [x] 1.2 为 `memo-search` 增加 Windows/macOS 桌面搜索入口 delta spec。

## 2. 实现

- [x] 2.1 将 Windows/macOS 桌面搜索统一为 standard/content search。
- [x] 2.2 调整桌面顶部 app action 区，保留排序和搜索按钮，移除预览、添加笔记、通知、设置入口。
- [x] 2.3 确保点击搜索按钮进入内容区搜索状态，并聚焦内容区搜索框。
- [x] 2.4 移除或旁路 Windows/macOS 顶栏搜索展开路径，避免在顶部命令栏或原生标题栏显示搜索输入框。

## 3. 测试

- [x] 3.1 更新 Windows/macOS title bar / screen body / memo list tests，覆盖顶部保留排序和搜索。
- [x] 3.2 覆盖点击搜索后搜索框出现在笔记区域而非顶部命令栏。
- [x] 3.3 覆盖 Windows/macOS 搜索入口进入内容区搜索状态。
- [x] 3.4 运行 focused Flutter tests。
- [x] 3.5 运行 `flutter analyze`。
- [x] 3.6 运行 `openspec validate optimize-windows-desktop-search-entry --type change --strict --no-interactive`。
