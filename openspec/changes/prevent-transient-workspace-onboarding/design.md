## Context

当前问题发生在桌面设置子窗口启动、重建或 refresh session 后。日志显示主窗口本来处于 local workspace，同步也报告 `hasLocalLibrary:true`；随后 settings 子窗口因旧 window id 不存在而重新创建，主窗口收到一次 `desktop.main.reloadWorkspace`，但 payload 中 `hasKey:false`。在同一段时间里 `LocalLibrary` reload 出现 `load_skip_state_changed currentCount:0`，`MainHomePage` 看到 `hasCurrentAccount:false`、`hasLocalLibrary:false` 后立即决定 `destination:onboarding`，而约 0.1 秒后本地库又恢复为 `libraryCount:1`。

当前依赖方向大致为：
- `features/settings/desktop_settings_window_app.dart` 通过 desktop multi-window channel 通知主窗口。
- `application/desktop/desktop_window_manager.dart` 处理主窗口 IPC 和 reload side effects。
- `features/home/main_home_page.dart` 消费 app bootstrap / workspace provider 结果并选择启动、onboarding、login 或 home。
- `state/system/local_library_provider.dart` 和 `state/system/session_provider.dart` 持有 workspace identity 与本地库列表。

该区域触及 `evolve_modularity` 下的 coupling hotspot：`application/desktop`、`features/settings`、`features/home` 和 `state/system`。实现必须保持现有 seam，不新增低层到 feature UI 的依赖，也不得把共享 workspace 判定逻辑散入页面局部 helper。

## Goals / Non-Goals

**Goals:**
- 防止桌面设置子窗口 reload、stale window recovery 或 debug storage 临时读空导致主窗口误入 onboarding 模式选择页。
- 让 settings 子窗口 workspace reload 通知携带可用的 active `currentKey`，使主窗口能恢复 session 后再 reload local libraries。
- 让本地库/session reload 区分“明确持久化为空”和“存储 key 缺失/临时读空”，避免用一次可疑空读清空已有工作区。
- 在 route gate 增加保守保护：`session.currentKey` 非空时，缺失 local library match 应先视为 pending/recoverable，而不是立即视为没有 workspace。
- 增加 focused tests 作为模块化 guardrail，保护 IPC payload、route gate 和 provider reload 语义。

**Non-Goals:**
- 不实现新的 workspace 模型、账号模型或数据库 schema。
- 不修改 Memos API、request/response models、version compatibility、WebDAV 同步协议或 memo 数据同步逻辑。
- 不改变用户主动删除最后一个本地库、退出登录、重新打开 onboarding 的既有行为。
- 不引入商业、订阅、StoreKit、private overlay 或 paid-feature 逻辑。

## Decisions

1. **把 `session.currentKey` 当作 reload 期间的 active workspace identity，而不是只相信当前帧的 `currentLocalLibraryProvider`。**

   `currentLocalLibraryProvider` 是 `session.currentKey` 和 `localLibrariesProvider` 的派生结果；任意一侧短暂为空都会变成 `null`。route gate 应在 `session.currentKey` 仍非空时保持保守，直到 session key 被明确清空，或本地库加载完成并稳定确认该 key 不存在。

   Alternative considered: 只给 onboarding 跳转加 debounce。拒绝原因：debounce 只能降低复现概率，不能定义 reload 状态语义，也无法防止不同设备性能下的更长空窗。

2. **settings 子窗口的 `local_libraries` reload 通知应携带当前 `currentKey`。**

   当前 `_localLibrariesSub` 只发 `reason:'local_libraries'`，主窗口处理时 `hasKey:false`，不会进入恢复 session / set key 分支。变更应复用现有 `desktopMainReloadWorkspaceMethod` payload：当 settings 窗口能读到非空 `session.currentKey` 时，将其作为 `currentKey` 一并发送。主窗口已有 `hasKey:true` 处理路径可先 reload session，再对齐 key，再 reload libraries。

   Alternative considered: 主窗口对所有无 key reload 都强制 reload session。拒绝原因：如果 storage 临时读空，无 key session reload 可能把主窗口 current key 清空，反而扩大问题；携带 key 能让主窗口在读空后仍有 desired key 可恢复。

3. **本地库 reload 对 `StorageReadResult.empty()` 采用保守语义。**

   对已存在的本地库内存状态，storage key 缺失或 debug 临时读空不应等价于用户删除所有本地库。合法删除最后一个本地库会通过 repository 写入显式空列表，或先清空/切换 session key；因此 provider 可以在“previous state non-empty + result.empty”时保留旧状态并记录 warn。必要时同样评估 session reload 对 previous state 的保守保护。

   Alternative considered: 修改所有调用方在删除后手动刷新 UI。拒绝原因：这会把共享 reload 语义扩散到 feature page，违反 checklist `4`。

4. **route gate 使用 pending 状态或 locked content 防止用户可见闪跳。**

   `MainHomePage` 可在 `session.currentKey` 非空、无 account、无 local library match、local library load/reload 未确认时保持 startup placeholder 或已有 home 内容。只有当 session key 明确为空，或 stable reload 确认 key 不存在且不是临时空读，才允许进入 onboarding/login 分支。

   Alternative considered: 让页面先跳 onboarding，再等本地库恢复后自动回 home。拒绝原因：用户可见跳转本身就是 bug，并且 onboarding 可能触发后续偏好/状态操作。

5. **用 focused tests 作为 `evolve_modularity` 改善。**

   本变更不需要新抽象层，但必须新增或加强测试，防止 touched area 继续退化：
   - settings 子窗口本地库变化通知包含 `currentKey`。
   - 主窗口收到带 key 的 workspace reload 会保持/恢复 active workspace。
   - `MainHomePage` 在 transient local library miss 时不渲染 `LanguageSelectionScreen`。
   - 本地库 provider 对 previous non-empty + storage empty 不直接清空。

## Risks / Trade-offs

- [Risk] 保守保留旧本地库状态可能掩盖真实外部存储删除。→ Mitigation: 仅对 `StorageReadResult.empty()` 且 previous state non-empty 保守；显式 JSON 空列表仍表示真实删除，并通过删除流程测试覆盖。
- [Risk] route gate pending 状态可能在损坏 session key 上停留过久。→ Mitigation: 需要以 local library load completion、storage error、明确 session key 清空作为退出条件，并在不可恢复时显示可操作的错误/修复路径而不是无限 splash。
- [Risk] settings 子窗口在自身 session 尚未加载时仍无法携带 key。→ Mitigation: 仅在可获得非空 key 时携带；同时 route gate 和 provider reload 保护承担兜底。
- [Risk] 触碰 `application/desktop` 可能加剧已知 `application -> features` hotspot。→ Mitigation: 复用现有 method channel 和 `AppBootstrapAdapter` seam，不新增 feature UI imports；通过 tests 约束行为。

## Migration Plan

1. 先补 focused failing tests，复现日志中的 `hasKey:false` / transient local library miss 路由问题。
2. 调整 settings 子窗口 workspace reload payload，确保本地库变更通知在可用时携带 `currentKey`。
3. 调整 local library/session reload 空读语义，保留已有工作区或进入 pending/recoverable 状态。
4. 调整 `MainHomePage` route gate，避免把 pending workspace 状态渲染为 onboarding。
5. 运行 focused tests，再运行 `flutter analyze` 和 `flutter test`。

Rollback 策略：该变更不涉及数据迁移。若出现回归，可回退 route gate/provider/IPC 代码和对应测试；持久化数据格式不需要回滚。

## Open Questions

- 是否需要把 session reload 的 `StorageReadResult.empty()` 也统一改成 previous-state 保守语义，还是先只处理本地库 provider 并通过 IPC currentKey 恢复 session？
- route gate 遇到 stable key mismatch 时是否应显示 self-repair/storage error，而不是 onboarding？实现前可根据现有 UX seam 决定。
