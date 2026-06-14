## Context

`WebDavSyncScreen` 已经在历史迁移中纳入 `platform-adaptive-ui-system`，并被 `settings_ui_drift_guardrail_test.dart` 作为 migrated settings file 管控。当前 `_WebDavConnectionScreen` 已使用 `SettingsPage`、`SettingsFormFieldRow`、`SettingsInlineTextFieldRow`、`SettingsNavigationRow`、`SettingsToggleRow` 和 `SettingsAction` 等 settings seam，连接测试也已有 `_testConnection()` 调用 `desktopSyncFacadeProvider.testWebDavConnection(...)`。

这次变更不是重新设计 WebDAV 设置，也不是新增同步能力，而是对已迁移连接页做二次信息架构和文案整理。实现必须保持现有 controller、provider 写入、root path normalization、auth picker、TLS toggle 和 connection test 调用路径。

依赖方向保持不变：

- Before: `features/settings/webdav_sync_screen.dart` 作为 UI 层读取 settings/sync providers，并通过现有回调和 provider notifier 写入 WebDAV settings。
- After: 仍由同一 UI surface 组合现有 settings semantic seams，不新增 `state -> features`、`application -> features` 或 `core -> features` 依赖。

当前架构阶段为 `evolve_modularity`，本 change 触及 settings 展示热点。模块化改进策略是继续缩小页面局部视觉实现：优先直接使用 `SettingsSectionHeader`、`SettingsFormFieldRow`、`SettingsNavigationRow`、`SettingsToggleRow`、`SettingsAction`/`PlatformPrimaryAction` 等 seam，避免为普通 row/section 引入新的 page-local card、palette、button style 或颜色系统。

## Goals / Non-Goals

**Goals:**

- 将 `_WebDavConnectionScreen` 整理为“基础设置”“认证设置”“高级设置”“安全”和底部“保存设置”动作。
- 使用明确文本“测试”呈现服务器地址连接测试入口，并继续复用现有 `_testConnection()`。
- 将 `WebDavAuthMode.basic` 的 UI 展示改为“基础认证”，不改变 enum 或持久化值。
- 将 `ignoreTlsErrors` 的 UI 文案改为“允许不安全证书”，并补充使用风险说明，不改变字段名、状态绑定或保存行为。
- 为根路径增加简短说明，继续使用现有默认值和 `normalizeWebDavRootPath` 行为。
- 为底部“保存设置”定义清晰语义：只完成当前设置保存/表单收尾，不测试连接、不启动同步、不自动启用 WebDAV。
- 保持所有颜色来自现有 theme/settings/platform seam；不修改全局主题或新增硬编码颜色。
- 将连接页背景容器收敛为页面内局部轻量 section wrapper，使分组卡片、输入框和底部按钮在移动端更对齐、更稳定。
- 更新 focused widget tests，覆盖文案、底部动作和连接测试仍可用。

**Non-Goals:**

- 不修改 WebDAV protocol、sync/backup/restore/Vault service、repository、data model、secure storage key 或数据库 schema。
- 不修改 `webDavSettingsProvider` 的状态结构或 provider ownership。
- 不引入新的校验系统；只保留现有 username/password mismatch、server URL 为空时测试不可用等轻量规则。
- 不改变 WebDAV 是否启用、自动同步、备份配置或连接测试结果处理语义。
- 不修改 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或主题 token。
- 不处理 WebDAV 备份设置页、日志页或 Vault 安全状态页的额外视觉改版。

## Decisions

### Decision 1: 使用窄范围连接页 section wrapper，并继续委托给 settings semantic seams

`_WebDavConnectionScreen` 应继续由 `SettingsPage` 承载页面 chrome，但连接页的四个分组可以使用页面内局部 `_ConnectionSection` 统一背景容器、圆角、边框和分割线。该 wrapper 只负责视觉外壳，颜色必须来自 `settingsPageTokens(context)` 或 `Theme.of(context).colorScheme`。连接页输入字段使用 settings 语义 `SettingsFieldBlock`，避免系统 list tile subtitle 布局造成输入灰框与外层容器不齐；选择行使用 `SettingsNavigationRow`，安全开关使用 `SettingsToggleRow`，底部动作使用 `SettingsAction`。

Rationale: `webdav_sync_screen.dart` 已被 migrated guardrail 管控。连接页需要解决移动端背景容器和按钮对齐问题，但不应把输入、按钮、切换开关等控件重新实现一遍。局部 wrapper 可以解决分组外壳不稳定的问题，同时继续保留 settings seam 的行为和守护。

Alternative considered: 在连接页新增 `_SettingsCard`、`_TextFieldBlock` 等完整页面私有组件。该方案能局部塑形，但会增加 drift 风险，并可能绕开已有 settings UI guardrail；因此仅允许很窄的页面私有 wrapper，并且 wrapper 必须委托到 settings semantic components。

### Decision 2: “保存设置”是表单收尾动作，不承担连接行为

底部主按钮文案为“保存设置”。点击时应收起键盘，并复用当前已有的 URL/root path normalization 或 provider 写入收尾。它不得调用 `_testConnection()`，不得发起 `syncCoordinator` request，亦不得自动修改 `enabled`、`backupEnabled` 或 `autoSyncAllowed`。

Rationale: 当前输入变化已经通过 controller 回调写入 `webDavSettingsProvider`。把底部按钮定义为连接动作会和用户澄清相冲突，也容易把测试/同步副作用混进视觉整改。

Alternative considered: 使用“保存并连接”并测试 WebDAV 可达性。该方案会改变功能语义，容易被误解为自动启用同步或发起网络连接，因此不采用。

### Decision 3: 连接测试保留为服务器地址字段内的明确文本操作

服务器地址字段右侧保留测试入口，但展示为“测试”文本按钮或等价 settings action，而不是仅显示 `network_check` 图标。禁用规则继续复用当前 `canTestConnection`：服务器地址为空或 username/password 只填一项时不可测试，测试中显示轻量 loading 状态。

Rationale: 这满足用户“不要只放含义不清的图标”的要求，同时不改变 `_testConnection()` 的调用、toast 和 result presentation。

### Decision 4: 文案只改 UI 展示，不改业务值

认证展示应由页面局部 label 函数或同等映射负责：`WebDavAuthMode.basic` 显示“基础认证”，`WebDavAuthMode.digest` 可继续显示 `Digest` 或使用现有本地化文案。安全开关标题显示“允许不安全证书”，但内部仍读写 `_ignoreTlsErrors` / `ignoreTlsErrors`。

Rationale: 用户问题是字段含义不清，业务值和持久化结构无需改变。

### Decision 5: 颜色约束优先落在 theme/settings token 层

连接页新增或调整的文字、按钮、警告提示、分割、边框和背景应使用 `Theme.of(context).colorScheme`、`settingsPageTokens(context)`、`SettingsRowTitle`、`SettingsRowDescription`、`SettingsAction` 或平台控件默认样式。若需要语义警告色，应从 `colorScheme.error` / `errorContainer` 等语义色派生，不新增固定 hex 颜色。

Rationale: 本 change 的硬性约束是保留当前 App 主题颜色体系。局部派生透明度可以增强层级，但不能成为新的颜色系统。

## Risks / Trade-offs

- [Risk] “保存设置”按钮看似会执行额外保存，但当前字段已经即时写入 provider。→ Mitigation: 把按钮实现为明确的完成/收尾动作，并在测试中确认它不调用连接测试或同步服务。
- [Risk] 改中文文案影响英文测试或多语言一致性。→ Mitigation: 使用 `context.tr` 或既有 i18n key，focused test 使用当前 locale 下的期望文本；必要时仅对新增中文用户文案使用 inline localized copy。
- [Risk] 新的底部按钮在小屏上遮挡内容或造成无意义空白。→ Mitigation: 继续使用 `SettingsPage` bounded content 和 SafeArea/底部 padding，按钮随内容滚动或按现有 settings action 习惯布局，避免自定义 overlay。
- [Risk] 视觉整改引入 page-local raw colors 或 button styles，触发 drift guardrail。→ Mitigation: 使用 settings semantic seams 和 theme-derived colors，并运行 settings UI drift guardrail。
- [Risk] 连接测试入口从图标变为文本后原有测试找不到 tooltip。→ Mitigation: 更新 focused widget test，让它以“测试”文本和成功 toast 验证同一 `_testConnection()` 路径。
