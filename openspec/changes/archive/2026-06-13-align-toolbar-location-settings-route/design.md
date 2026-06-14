## Context

编辑工具栏的定位入口统一复用 `showLocationPickerSheetOrDialog()`。当前该函数在定位未启用、provider key 缺失或 provider 不可用时，会显示提示弹窗，并在“打开设置”按钮里直接 `MaterialPageRoute` 到 `LocationSettingsScreen`。

这带来两个问题：

- 页面承载不一致：用户从设置首页进入的是“功能组件 -> 定位”的 settings composition，而工具栏提示进入的是孤立的旧路由。
- 模块边界偏紧：`features/location_picker/show_location_picker.dart` 直接 import `features/settings/location_settings_screen.dart`，把 picker 的 provider 校验流程和 settings 页面构造绑定在一起。

现有桌面设置窗口已经支持 `DesktopSettingsWindowTarget.location`，会进入 `Components` pane 并打开 `LocationSettingsScreen`。`LocationSettingsScreen` 本体也已经通过 `SettingsPage`、`SettingsSection` 等 semantic settings seams 迁移，因此本变更重点是路由承载和边界整理，而不是重做定位设置 UI。

Architecture phase 为 `evolve_modularity`。本变更触碰 checklist `6.`、`8.`、`10.`，需要让被触碰区域至少不比现状更耦合，并补充 focused verification。

## Goals / Non-Goals

**Goals:**

- 工具栏定位失败提示的“打开设置”进入与“设置 -> 功能组件 -> 定位”一致的定位设置 surface。
- 桌面端优先通过 `DesktopSettingsWindowTarget.location` 打开或聚焦独立设置窗口。
- 桌面设置窗口不可用或打开失败时，主窗口 fallback 到可见的 `LocationSettingsScreen`。
- `showLocationPickerSheetOrDialog()` 不再直接构造 settings 页面或直接拥有旧 `MaterialPageRoute`。
- 覆盖 note input、memo editor、inline compose、desktop quick input 等当前定位入口。

**Non-Goals:**

- 不改变定位 enabled/provider/key/precision 的数据模型、repository、provider 或持久化格式。
- 不改变 device location permission、geocoder、map provider adapter、location picker panel 交互或 reverse geocode 行为。
- 不修改 API route/version compatibility、WebDAV config transfer、private hooks、commercial/paywall 逻辑。
- 不重新设计 `LocationSettingsScreen` 的字段、文案或 settings row 样式。

## Decisions

### Decision 1: `showLocationPickerSheetOrDialog()` 接收 settings opener seam

`showLocationPickerSheetOrDialog()` SHALL 通过一个显式 callback、typedef 或等价 seam 打开定位设置。该 seam 由调用方传入，picker 只在 provider requirements 校验失败时调用它。

Before:

```text
features/location_picker/show_location_picker.dart
  └── imports features/settings/location_settings_screen.dart
      └── Navigator.push(MaterialPageRoute(LocationSettingsScreen))
```

After:

```text
compose / quick-input caller
  └── passes openLocationSettings callback
      └── showLocationPickerSheetOrDialog(...)
            └── prompt calls callback only
```

Rationale: picker 的职责是选择位置和展示 provider readiness prompt，不应决定 settings 页面所属 pane、desktop window target 或 fallback route。

Alternatives considered:

- 只把 `MaterialPageRoute` 换成 `buildPlatformPageRoute`：移动端样式会改善，但桌面仍绕过独立 settings window，且 picker 仍直接依赖 settings screen。
- 在 picker 内直接调用 `openDesktopSettingsWindow(target: location)`：行为接近目标，但会让 picker 同时知道 desktop application seam 和 settings screen fallback，耦合继续扩大。

### Decision 2: 提供 settings-owned location settings opener

实现层 SHOULD 提供一个 settings/navigation composition helper，例如 `openLocationSettingsSurface(BuildContext context)` 或等价函数。该 helper 的责任是：

- 在支持 desktop settings window 的平台调用 `openDesktopSettingsWindow(feedbackContext: context, target: DesktopSettingsWindowTarget.location)`。
- 如果结果为 `opened`，不再在当前 navigator 上 push fallback。
- 如果结果为 `unsupported` 或 `failed`，且 `context.mounted`，使用 `buildPlatformPageRoute` 打开 `LocationSettingsScreen`。

Dependency ownership:

```text
settings-owned opener
  ├── may know DesktopSettingsWindowTarget.location
  ├── may construct LocationSettingsScreen fallback
  └── owns target/fallback composition

location_picker
  └── knows only callback contract
```

Rationale: target-to-widget mapping 和 fallback page construction 留在 settings UI composition 附近，符合现有 desktop settings window 设计。

### Decision 3: 更新所有 runtime 定位入口，而不是只修某一个 toolbar

当前多个 compose surface 通过同一 picker 入口发起定位。如果只修 note input 或 memo editor，会留下行为分叉。因此本变更 SHOULD 更新所有直接调用 `showLocationPickerSheetOrDialog()` 的 runtime call sites，让它们传入同一个 opener。

Rationale: 用户看到的是“工具栏定位”，但实际共享入口包括：

- note input sheet
- memo editor screen
- memos list inline compose coordinator
- desktop quick input window

### Decision 4: 用 focused tests 锁定行为和边界

Verification SHOULD 覆盖：

- provider 不 ready 时，prompt 的“打开设置”调用传入的 opener。
- picker 文件不再直接 import `features/settings/location_settings_screen.dart`。
- settings window location target 仍能进入 `Components` pane 并打开 `LocationSettingsScreen`。
- fallback page 使用平台路由或等价 settings route seam，而不是旧的裸 `MaterialPageRoute` 分支。

Rationale: 现有测试已经覆盖 `LocationSettingsScreen` 的 semantic seams 和 `DesktopSettingsWindowTarget.location`，但没有覆盖 location picker prompt 的设置路由，因此迁移后需要补上缺口。

## Risks / Trade-offs

- [Risk] 给 `showLocationPickerSheetOrDialog()` 增加 required callback 会触碰多个 call sites。→ Mitigation: 使用集中 helper 和 focused compile/test verification，确保所有调用点一次性迁移。
- [Risk] 桌面 settings window 打开失败时用户可能看不到任何设置页。→ Mitigation: helper 必须保留 unsupported/failed fallback，并在 `context.mounted` 后 push 可见 page。
- [Risk] 调用方导入 settings opener 仍是 feature-to-feature collaboration。→ Mitigation: 导入单一 settings-owned navigation seam，而不是分散导入 `LocationSettingsScreen` 或复制 target/fallback 逻辑；picker 本身移除直接 settings screen 依赖。
- [Risk] 桌面 quick input 子窗口上下文打开主设置窗口时平台行为存在差异。→ Mitigation: 保持 `openDesktopSettingsWindow` 的现有 public seam 和 fallback semantics，不在 quick input 内复制 sub-window routing。
