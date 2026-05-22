## Verification

- `openspec validate promote-memos-desktop-preview-layout --strict`: passed
- `flutter analyze`: passed
- `flutter test`: passed
- Focused Flutter tests: passed
  - `test/core/platform_layout_test.dart`
  - `test/features/memos/memos_list_screen_view_state_test.dart`
  - `test/features/memos/widgets/memos_list_screen_body_test.dart`
  - `test/features/memos/memos_list_screen_test.dart`
  - `test/features/memos/memo_media_grid_test.dart`
  - `test/features/memos/memos_list_memo_card_container_test.dart`

## Manual Smoke Risk

尚未在真实 macOS desktop app 中手动点击验证。自动化已覆盖 macOS wide layout 下 memo card 点击打开 desktop preview pane、memo card 宽度不超过 shared desktop max width、layout helper 支持 macOS preview pane，并覆盖 macOS media grid 高度受限时 tile 保持方形、不被压成长条。

后续手动 smoke 建议：

- macOS 宽窗口打开主页，确认 memo card 两侧有留白且不横向拉伸。
- 打开包含多张图片的 memo card，确认图片 tile 保持方形比例，不出现横向短条拉伸。
- 点击 memo card，确认右侧 preview pane 打开并显示选中的笔记。
- 点击另一张 memo card，确认 preview pane 切换内容。
- 关闭 preview pane 后再次点击 memo card，确认可以重新打开。
