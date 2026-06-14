## Why

当前编辑工具栏点击“定位”后，如果定位未启用或 provider 配置缺失，提示弹窗中的“打开设置”会直接 push `LocationSettingsScreen` 的旧承载路由，绕过现在“设置 -> 功能组件 -> 定位”的页面上下文与桌面设置窗口 target。用户从工具栏进入定位设置时看到的外层样式和设置体系不一致，需要把该入口对齐到现有 settings composition。

## What Changes

- 将定位选择器的“打开设置”动作从硬编码 push `LocationSettingsScreen` 改为通过一个可注入或等价的 navigation seam 发起。
- 桌面端打开定位设置时优先使用 `openDesktopSettingsWindow(target: DesktopSettingsWindowTarget.location)`，使独立设置窗口选中 `Components` pane 并打开定位页。
- 非桌面或桌面设置窗口不可用/失败时，fallback 到当前平台路由承载的 `LocationSettingsScreen`，保持页面本体使用已迁移的 `SettingsPage` / `SettingsSection` 样式。
- 覆盖所有复用 `showLocationPickerSheetOrDialog()` 的工具栏定位入口，包括 note input、memo editor、inline compose 和 desktop quick input。
- 增加 focused widget tests 或等价 guardrail，防止定位选择器继续直接使用旧 `MaterialPageRoute` 路由打开设置页。
- 保持定位数据模型、provider、repository、permission、geocoder、map picker、API compatibility、private hooks 和商业逻辑不变。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 约束工具栏定位失败提示的“打开设置”必须进入已迁移的定位设置 surface，移动端使用平台路由，避免旧承载路由造成样式漂移。
- `macos-settings-window`: 约束桌面工具栏定位设置入口应复用 `DesktopSettingsWindowTarget.location` target routing，并保留可见 fallback。

## Impact

- Affected runtime code:
  - `memos_flutter_app/lib/features/location_picker/show_location_picker.dart`
  - 复用 `showLocationPickerSheetOrDialog()` 的 compose/quick-input 调用点
  - 可能新增一个轻量 navigation seam 或等价回调类型，用于打开定位设置
- Affected tests:
  - 新增或更新 location picker/settings routing focused tests
  - 视实现触碰范围运行 settings window / settings UI guardrail 相关测试
- Architecture phase: `evolve_modularity`
- Modularity checklist touched:
  - `6.` Feature-to-feature collaboration prefers boundary/registry/provider seams over direct screen imports
  - `8.` Architecture guardrail tests protect the highest-risk dependency directions
  - `10.` Every change touching a coupled area leaves that area equal or better structured than before
- Scoped modularity improvement:
  - 定位选择器不再直接拥有“设置页 widget 构造 + 旧路由 push”的决策，改由调用方或 settings/navigation seam 负责目标选择与 fallback。
