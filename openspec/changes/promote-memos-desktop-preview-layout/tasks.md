## 1. OpenSpec

- [x] 1.1 创建 `promote-memos-desktop-preview-layout` change artifacts
- [x] 1.2 记录 active architecture phase、modularity 影响和非目标

## 2. Desktop memo list behavior

- [x] 2.1 将 `MemosListAnimatedMemoItem` 卡片限宽从 Windows-only 提升为 desktop target 行为
- [x] 2.2 将 `shouldUseDesktopPreviewPaneLayout` 从 Windows-only 提升为 desktop target helper
- [x] 2.3 调整 `MemosListScreen` preview interaction gate，避免 macOS 被 Windows layout spec 挡住
- [x] 2.4 保持 Windows 现有 preview pane 阈值和默认行为不变
- [x] 2.5 将 memo 图片/媒体网格的高度受限方形 tile 行为从 Windows-only 提升为 desktop target 行为，避免 macOS 图片区域被压成长条

## 3. Tests and guardrails

- [x] 3.1 增加 macOS layout state 测试，覆盖 wide desktop preview pane 支持
- [x] 3.2 增加 desktop card width 测试，覆盖 macOS memo card bounded width
- [x] 3.3 更新 `platform_layout_test`，覆盖 macOS desktop preview helper
- [x] 3.4 增加 macOS media grid 回归测试，覆盖高度受限时 tile 仍保持方形且网格不横向拉伸

## 4. Verification

- [x] 4.1 运行 focused Flutter tests
- [x] 4.2 运行 `flutter analyze`
- [x] 4.3 记录 macOS manual smoke 风险：需要实际点击 memo card 确认右侧 preview pane 和图片网格比例
