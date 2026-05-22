## Why

macOS 桌面窗口启用了透明 / full-size titlebar 后，Flutter 内容可以绘制到系统 traffic lights 区域，导致设置窗口、主窗口左上角标题或按钮与系统自带窗口控件重叠。这个问题属于 `platform-adaptive-ui-system` 完成后的窗口 chrome 补洞：桌面端不仅要避免移动端控件拉伸，也必须尊重平台原生窗口安全区。

当前架构阶段为 `evolve_modularity`，基线 modularity score 为 `4/10`。本变更会触及 `home`、`settings`、desktop shell 和 macOS Runner 的平台外壳区域，应通过统一的 window chrome safe-area seam 收敛，而不是在 feature pages 中散落 magic padding。

## What Changes

- 为桌面窗口 chrome 建立可验证的 safe-area 规则：在 macOS full-size / transparent titlebar 下，页面标题、导航、工具栏按钮和主要交互控件不得进入 traffic lights 保留区。
- 修复主窗口 macOS shell 与独立设置窗口的左上角布局，使左侧标题 / 导航 / command content 避开原生窗口控件。
- 将 titlebar / window-control 避让逻辑放在 desktop shell、platform adapter 或窗口 frame 层，而不是业务 feature 页面内部。
- 保持 Windows / Linux / mobile 现有布局语义不回退；Windows frameless 自绘窗口仍走自己的 window-control 规则。
- 增加 focused tests 或 guardrail，覆盖 macOS titlebar safe inset 与 settings subwindow 左上角不重叠。
- 不改变 API、数据模型、同步逻辑、商业 / private overlay 边界。

## Capabilities

### New Capabilities

- `desktop-window-chrome-safe-area`: 约束桌面窗口内容如何避开 macOS traffic lights、Windows caption controls、透明 titlebar 和自绘窗口 chrome。

### Modified Capabilities

- `apple-platform-ui-adaptation`: macOS Apple shell 必须把 native traffic lights 视为 window chrome reserved area，并通过集中 seam 避让。
- `desktop-shell-host-boundary`: 桌面 shell host 必须承载 titlebar / window-control safe-area 策略，feature pages 不应直接依赖具体平台 shell 或自行猜测窗口控件位置。
- `desktop-layering-governance`: titlebar、toolbar、window controls、traffic-light 避让属于平台外壳工作；可复用的 safe-area 计算可放在桌面通用层，但不得反向依赖 feature/state/application/data。

## Impact

- 主要影响 `memos_flutter_app` 的桌面 UI / shell 层：
  - `lib/features/home/desktop/**`
  - `lib/features/settings/desktop_settings_window_app.dart`
  - `lib/platform/**` 或 `lib/core/desktop/**` 中必要的 safe-area helper
  - `macos/Runner/MainFlutterWindow.swift` 仅在需要确认或补充窗口 chrome 配置时触及
  - 相关 widget tests / architecture tests
- 不修改 `memos_flutter_app/lib/data/api`、route adapters、request/response models 或 `test/data/api`。
- 不引入 StoreKit、subscription、entitlement、receipt、paywall、product ID、price 或 `AccessDecision.source` 业务分支。
- 不创建完整平台专属 feature tree，例如 `features_macos/` 或 `features_windows/`。
