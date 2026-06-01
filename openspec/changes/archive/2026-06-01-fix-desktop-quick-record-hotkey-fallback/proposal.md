## Why

桌面快速记录的系统级热键可能因为系统占用、权限或插件注册错误而注册失败；当前主窗口快捷键分发只根据 tray/status-area support 判断是否委托给系统热键，导致注册失败时主窗口内按同一快捷键也可能没有实际处理者。

这个 change 需要把系统热键注册结果纳入 fallback 决策，让“后台可用”和“主窗口内可兜底”两个语义同时成立。

## What Changes

- 为 `quickRecord` 系统热键注册维护可读的注册状态，区分注册成功、注册失败和未尝试/不可用。
- 当系统热键注册成功时，主窗口内 `quickRecord` 仍可标记为 delegated，后台/隐藏到菜单栏场景继续由 system hotkey 处理。
- 当系统热键注册失败时，主窗口内按 `quickRecord` SHALL fallback 到窗口内快速记录入口，不再误判为 delegated。
- fallback 只覆盖主窗口可接收 `HardwareKeyboard` 事件的前台/可见窗口场景；App 已隐藏到菜单栏或后台且系统热键注册失败时，没有键盘事件来源，不能承诺兜底触发。
- 保留已有日志记录，并补充 focused tests 覆盖注册成功、注册失败、托盘/status-area 支持和非支持平台路径。
- 当前架构阶段为 `evolve_modularity`。本 change 触及 `application/desktop` 与 `features/memos` 的桌面快捷键分发边界，实现 SHALL 不新增 `application -> features`、`state -> features` 或 `core -> higher layer` 依赖；通过把注册状态暴露为桌面 application-owned seam，避免 feature 层自行推断系统热键能力。

## Capabilities

### New Capabilities
- `desktop-quick-record-hotkey-fallback`: 定义桌面快速记录系统热键注册结果与主窗口 fallback 分发语义，确保注册失败时主窗口内快捷键仍可触发快速记录。

### Modified Capabilities
- 无。

## Impact

- Flutter/Dart：`memos_flutter_app/lib/application/desktop/desktop_quick_input_controller.dart`、`memos_flutter_app/lib/features/memos/memos_list_desktop_shortcut_delegate.dart`、`memos_flutter_app/lib/features/memos/memos_list_screen.dart`，以及必要的 application/desktop 或 feature-level focused tests。
- 平台行为：Windows 和 macOS 的 `quickRecord` system hotkey 注册成功路径保持不变；注册失败时仅改善主窗口内 fallback，不承诺后台触发。
- 测试：更新快捷键分发测试，新增或调整系统热键注册状态相关测试，确保 fallback 条件可验证。
- Public/private boundary：本 change 仅涉及公共桌面快捷键与快速记录 runtime，不得引入 subscription、billing、entitlement、StoreKit、paywall、private overlay 或 `AccessDecision.source` business branching。
