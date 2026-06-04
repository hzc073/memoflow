## Why

打开或重新创建桌面设置子窗口时，主窗口可能在 workspace reload 的短暂空窗内把 `hasLocalLibrary` 误判为 `false`，从正常本地工作区跳到 onboarding 模式选择页。日志显示本地库随后又恢复为 `libraryCount:1`，说明这是状态同步和路由判定时序问题，不是用户数据被删除。

现在需要为这个问题建立明确规则：当 `session.currentKey` 仍指向本地 workspace 时，桌面子窗口同步、本地库 reload、debug storage 临时读空都不得让主窗口把“未确认状态”当成“没有 workspace”。

## What Changes

- 新增 workspace 路由稳定性规则：`MainHomePage` 或等价 app route gate 在存在非空 `session.currentKey` 时，MUST NOT 因本地库列表短暂为空而直接显示 `LanguageSelectionScreen` / 模式选择页。
- 修改桌面设置窗口规则：`DesktopSettingsWindowApp` 向主窗口发送 workspace reload 通知时，若可获得当前 workspace key，MUST 随通知携带 `currentKey`，避免主窗口走 `hasKey:false` 的不完整刷新路径。
- 明确本地库/session 存储 reload 的语义：已有内存 workspace 状态遇到 storage key 缺失或 debug 临时读空时，SHOULD 保守保留旧状态或进入可恢复等待状态，而不是立即清空工作区。
- 增加 focused tests，覆盖桌面设置子窗口本地库变更通知、主窗口 route gate、本地库 reload 空读保护。
- 保持实现边界：不修改 Memos API、WebDAV 同步协议、数据库 schema、商业/private hooks，且不得引入新的 `state -> features`、`application -> features` 或 `core -> features` 依赖。

## Capabilities

### New Capabilities
- `workspace-route-stability`: 约束 app shell 和 workspace state 在本地库/session reload 短暂不一致时保持路由稳定，防止误进入 onboarding。

### Modified Capabilities
- `macos-settings-window`: 桌面设置窗口与主窗口之间的 workspace reload 通知必须保留 active workspace identity，避免 settings 子窗口启动或重建时 destabilize 主窗口路由。

## Impact

- Affected code:
  - `memos_flutter_app/lib/features/home/main_home_page.dart`
  - `memos_flutter_app/lib/features/settings/desktop_settings_window_app.dart`
  - `memos_flutter_app/lib/application/desktop/desktop_window_manager.dart`
  - `memos_flutter_app/lib/state/system/local_library_provider.dart`
  - 可能涉及 `memos_flutter_app/lib/state/system/session_provider.dart` 和 debug-only `EphemeralSecureStorage` 的错误/空读语义
- Affected tests:
  - `memos_flutter_app/test/features/home/main_home_page_test.dart`
  - `memos_flutter_app/test/features/settings/desktop_settings_window_app_test.dart`
  - `memos_flutter_app/test/application/desktop/desktop_window_manager_test.dart`
  - 需要时补充 `state/system` provider focused tests
- Architecture phase: `evolve_modularity`.
- Modularity checklist impact:
  - 触及 checklist `2` 的风险区域：`application/desktop` 已是已知 coupling hotspot，变更 MUST NOT 增加新的 `application -> features` 反向依赖。
  - 触及 checklist `4` 的风险区域：workspace route 判定和 reload 语义 MUST 保持在 provider / app shell seam / desktop window coordinator 中，不得把共享工作区逻辑散落进页面 widget。
  - 满足 checklist `8`、`10`：通过 focused tests 保护 settings IPC、route gate 和本地库 reload 语义，让 touched area equal or better structured。
