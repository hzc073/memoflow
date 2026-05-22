## Why

macOS 上点击设置后用户期待出现可见的设置界面，但当前设置入口要么被桌面设置子窗口分支吞掉，要么只回退到主窗口内页面，无法满足 macOS “设置/偏好设置窗口”体验。现在需要把设置入口、子窗口运行时和失败回退整理成明确规则，避免再次出现“点击无反馈”。

## What Changes

- 为 macOS 引入明确的设置窗口能力：设置按钮、`Cmd+,`、应用菜单和窗口菜单应打开或聚焦一个可见的设置窗口。
- 复用现有 `DesktopSettingsWindowApp` 和设置页面能力，不新增 `features_macos/` 或完整 Apple 专用页面树。
- 修正 macOS Flutter 子窗口运行时要求，确保子窗口 engine 注册设置窗口实际需要的插件，并能通过健康检查。
- 将设置窗口打开动作改为可感知成功/失败的流程；失败时必须回退到主窗口内 `SettingsScreen` 或其他可见设置界面。
- 为 macOS 设置入口、子窗口插件注册、失败回退和公共商业边界增加测试或守卫。
- 不加入 StoreKit、订阅、权益、价格、receipt、paywall 或任何商业化运行时逻辑。

## Capabilities

### New Capabilities

- `macos-settings-window`: 约束 macOS 设置窗口的打开、聚焦、运行时插件注册、失败回退、入口一致性和公共仓边界。

### Modified Capabilities

- `macos-app-menu`: 明确 macOS 菜单中的 Settings / Open Settings Window 命令必须通过应用命令缝合层打开或聚焦可见设置界面，并在子窗口失败时回退。
- `apple-platform-ui-adaptation`: 明确 macOS 设置体验属于高感知 Apple UI 区域，必须复用平台适配层和现有业务页面，不复制整套页面树。

## Impact

- 受影响代码主要在 `memos_flutter_app`：
  - `lib/application/desktop/desktop_settings_window.dart`
  - `lib/features/memos/memos_list_route_delegate.dart`
  - `lib/application/desktop/desktop_window_manager.dart`
  - `lib/core/drawer_navigation.dart`
  - `lib/app.dart`
  - `lib/features/settings/desktop_settings_window_app.dart`
  - `macos/Runner/MainFlutterWindow.swift`
  - 相关 macOS 菜单资源和测试
- 不触碰 API 请求/响应、路由适配、版本兼容逻辑或 `memos_flutter_app/lib/data/api`。
- 当前架构阶段为 `evolve_modularity`。本变更触及 `application/desktop`、`core/drawer_navigation`、`features/settings`、`features/memos` 等耦合热点，因此需要把 macOS 设置窗口打开流程集中到明确的桌面窗口缝合层，并增加守卫，避免新增 `state -> features`、`application -> features` 或 `core -> features` 的反向依赖。
