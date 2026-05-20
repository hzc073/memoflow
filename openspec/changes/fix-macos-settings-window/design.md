## Context

当前设置入口存在两层问题：

- 入口语义不一致：主界面设置按钮、抽屉设置、macOS 菜单、托盘设置入口都可能触发设置，但并不共享一个可感知成功/失败的打开结果。
- macOS 子窗口运行时不完整：项目已有 `DesktopSettingsWindowApp`，但 macOS Runner 目前没有像 Windows Runner 一样为 `desktop_multi_window` 子窗口 engine 注册设置窗口所需插件。直接启用 macOS 子窗口可能导致窗口不可见、空白或健康检查失败。

当前架构阶段为 `evolve_modularity`。本变更会触及 `application/desktop`、`core/drawer_navigation`、`features/memos`、`features/settings` 和 `app.dart` 等耦合区域；设计目标是把设置窗口行为收敛到桌面窗口缝合层，并通过测试/守卫防止耦合恶化。

简化后的目标流：

```text
设置入口
  │
  ▼
统一设置打开 seam
  │
  ├─ macOS / Windows / Linux 支持子窗口
  │     │
  │     ├─ 创建或聚焦 DesktopSettingsWindowApp
  │     ├─ show + focus + ping
  │     └─ 成功返回 opened
  │
  └─ 不支持或失败
        │
        ▼
     打开主窗口 SettingsScreen fallback
```

## Goals / Non-Goals

**Goals:**

- macOS 点击设置必须出现可见设置界面；优先打开或聚焦独立设置窗口。
- `Cmd+,`、应用菜单 Settings、Window 菜单 Open Settings Window、主界面设置按钮、抽屉设置和托盘设置入口的行为保持一致。
- 复用现有 `DesktopSettingsWindowApp` 和现有设置页面，不复制 Apple 专用 feature 页面树。
- 子窗口打开流程必须返回可判断结果，调用方能在失败时执行可见 fallback。
- macOS 子窗口 engine 注册必要插件，并通过健康检查确认可响应。
- 增加聚焦测试和守卫，覆盖入口回退、macOS Runner 子窗口注册和公共商业边界。

**Non-Goals:**

- 不设计订阅、付费、StoreKit、receipt、entitlement、paywall 或私有商业化能力。
- 不重写设置页业务逻辑，不迁移设置数据模型，不触碰 API 兼容层。
- 不新增 `features_macos/`、`features_ios/` 或整套 Apple 专属页面。
- 不把 Windows 外壳直接泛化成 macOS 最终 UI；本变更只解决设置窗口可见性和入口一致性。

## Decisions

### 1. 复用 `DesktopSettingsWindowApp`，不新建一套 Apple 设置页

`DesktopSettingsWindowApp` 已经承载设置窗口专用导航、会话刷新、主窗口通信和设置页组合。macOS 问题更像是运行时和入口结果处理缺失，而不是缺少一套设置功能。

备选方案：

- 新建 `MacosSettingsWindowApp`：可以更贴近 macOS，但会复制大量设置组合逻辑，后续维护成本高。
- 只打开主窗口 `SettingsScreen`：实现简单，但不满足用户对 macOS 独立设置窗口的预期。

结论：先复用 `DesktopSettingsWindowApp`，必要时让窗口 frame、标题栏、视觉 chrome 根据 macOS 做轻量分支。

### 2. 设置打开 API 返回显式结果

当前 `openDesktopSettingsWindowIfSupported()` 同步返回 `true/false`，但真正打开窗口是异步 `unawaited`。这会把“开始尝试打开”误认为“已经成功打开”，导致失败时没有 fallback。

设计上应引入或等价实现一个异步结果：

```text
unsupported  -> 调用方 fallback
opened       -> 调用方结束
failed       -> 调用方 fallback，并可显示日志/toast
```

这会改变入口代码的形态，但不改变业务数据流。

### 3. macOS 子窗口插件注册在 Runner 层完成

`desktop_multi_window` 的 macOS 示例通过 `FlutterMultiWindowPlugin.setOnWindowCreatedCallback` 为子窗口 engine 注册额外插件。项目 Windows Runner 已有同类模式。macOS Runner 应添加一个精简的子窗口插件注册函数，只注册设置窗口实际需要的插件，避免直接调用完整 `RegisterGeneratedPlugins` 造成主窗口重新绑定或 multi-window channel 不稳定。

子窗口最低需求以 `DesktopSettingsWindowApp` 当前能力为准，包括但不限于：

- `window_manager`
- `path_provider`
- `sqflite`
- `flutter_secure_storage`
- `package_info_plus`
- `url_launcher`
- `file_selector` / `file_picker` 类设置页可能触达的文件能力
- `desktop_multi_window` 内部已经注册的窗口通信能力不重复完整注册

实现时应以编译结果和 focused tests 校准最终清单。

### 4. fallback 由入口附近保留，但打开判断集中到桌面窗口 seam

`application/desktop` 当前已经存在到 `features/settings` 的耦合历史。为了不扩大耦合，本变更不让底层窗口工具直接构造 `SettingsScreen`。窗口 seam 只返回打开结果，具体 fallback 页面仍由 `app.dart`、route delegate 或导航入口在 UI 层决定。

依赖方向目标：

```text
UI 入口(features/app/core composition)
   │
   ▼
desktop settings window seam(application/desktop)
   │
   ▼
desktop_multi_window / native Runner

fallback SettingsScreen 仍在 UI 入口层完成
```

这比让 `application/desktop` 直接 import 更多 feature 页面更可控。

### 5. 入口覆盖采用少量集中测试

需要测试的不是所有视觉细节，而是“入口不会吞掉失败”。重点覆盖：

- macOS 平台下设置入口会尝试子窗口，失败时 fallback。
- macOS 菜单 Settings 命令不能只 fire-and-forget 子窗口打开。
- macOS Runner 包含子窗口插件注册 hook。
- 公共仓守卫继续阻止商业逻辑进入 Apple/macOS 公共 shell。

## Risks / Trade-offs

- [Risk] macOS 子窗口插件清单不足，窗口仍然空白或运行时报 MissingPluginException。  
  → Mitigation：先注册设置窗口实际触达的插件，运行 `flutter build macos --debug` 或手动 smoke test，失败时补齐最小清单。

- [Risk] 直接完整注册 `RegisterGeneratedPlugins` 可能重新 attach 主窗口或破坏 multi-window 通信。  
  → Mitigation：参考 Windows Runner，使用精简注册函数，避免重复注册 `FlutterMultiWindowPlugin.register`。

- [Risk] 把打开 API 改成异步会影响多个入口。  
  → Mitigation：一次性梳理主界面、抽屉、菜单、托盘入口，并用 focused tests 锁住 fallback 行为。

- [Risk] macOS 独立窗口视觉仍偏 Windows。  
  → Mitigation：本变更先解决可见性和行为一致性；视觉精修只做轻量窗口尺寸/标题栏调整，更多 macOS 设置布局可后续独立 change。

## Migration Plan

1. 引入可感知结果的设置窗口打开 seam。
2. macOS Runner 增加子窗口插件注册 hook。
3. 重新允许 macOS 使用设置子窗口，并校准窗口尺寸/标题行为。
4. 更新主界面、抽屉、macOS 菜单、托盘等入口，失败时打开可见 fallback。
5. 增加或更新 focused tests 与守卫。
6. 执行 `flutter analyze`、focused tests，条件允许时执行 macOS debug build 或手动 smoke test。

回滚策略：如果 macOS 子窗口运行时仍不稳定，可以保留异步结果 seam 和 fallback 测试，将 macOS 支持开关临时关闭为 fallback 主窗口设置页；不影响 Windows/Linux 设置窗口。

## Open Questions

- macOS 设置窗口最终是否必须使用原生 titled window 和 traffic lights，还是允许 Flutter 自绘圆角窗口壳？
- macOS 设置窗口默认尺寸是否采用现有 `1260x820`，还是调整为更接近系统设置的紧凑尺寸？
- 托盘设置入口在 macOS 上失败时是否应该显示主窗口并打开 `SettingsScreen`，还是只聚焦主窗口后由用户手动进入设置？
