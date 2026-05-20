## macOS Settings Window Smoke Test

日期：2026-05-19

## 已完成验证

- `flutter analyze` 通过。
- `flutter test test/application/desktop/desktop_settings_window_test.dart test/features/memos/memos_list_route_delegate_test.dart test/architecture/macos_public_shell_guardrail_test.dart --reporter expanded` 通过。
- 已按 debug 分发路径复制到 `/tmp/MemoFlow_debug.app`，手动临时代签并启动成功。

## macOS build 结果

- 已执行 `flutter build macos --debug` 并成功完成。
- 第一次尝试先完成工具链下载和 Xcode 编译，但在 codesign 阶段因 `resource fork, Finder information, or similar detritus not allowed` 失败。
- 通过对 `build/macos/Build/Products/Debug/MemoFlow.app` 执行 `xattr -cr` 清除扩展属性后，重新构建成功。
- 构建结果显示 Runner 代码与新加入的 macOS 子窗口插件注册可以通过 macOS Debug 编译链路。
- 后续再次执行 `flutter build macos --debug` 时仍可能在 Flutter 内部 codesign 步骤遇到同类资源叉问题；可以使用最新 `build/macos/Build/Products/Debug/MemoFlow.app` 作为源，通过 `ditto --norsrc` 复制到 `/tmp/MemoFlow_debug.app` 后执行 `xattr -cr` 和 `codesign --force --deep --sign -`。
- 用户确认初版运行后设置仍无可见效果后，已进一步调整打开顺序为先 `show()` 设置窗口，再执行带超时的 refresh / focus / ping；同时补充 `cryptography_flutter` 到 macOS 子窗口插件注册清单。
- 已重新生成 `/tmp/MemoFlow_debug.app` 并启动，当前运行进程路径为 `/private/tmp/MemoFlow_debug.app/Contents/MacOS/MemoFlow`。

## 后续手动 smoke test

若未来再次遇到同类问题，可先执行：

- `xattr -cr build/macos/Build/Products/Debug/MemoFlow.app`

然后再执行：

- `flutter build macos --debug`
- 或启动 macOS debug app 后验证：
  - 点击主界面设置按钮会打开或聚焦设置窗口。
  - 使用 `Cmd+,` 会打开或聚焦设置窗口。
  - Window 菜单中的 Open Settings Window 会打开或聚焦设置窗口。
  - 设置子窗口不可用时，主窗口会打开可见 `SettingsScreen` fallback。
