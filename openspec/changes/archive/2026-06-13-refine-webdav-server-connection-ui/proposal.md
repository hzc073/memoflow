## Why

WebDAV 的“服务器连接”页已经迁移到 settings semantic UI seam，但当前视觉层级仍不够清晰：测试入口是图标、认证方式展示偏技术化，高级/安全配置混在同一区域，且页面底部缺少明确的保存收尾动作。

这次变更需要在不改主题颜色体系、不改 WebDAV 业务逻辑的前提下，让该二级设置页更符合移动端设置表单体验。

## What Changes

- 调整 `_WebDavConnectionScreen` 的信息结构，将内容整理为“基础设置”“认证设置”“高级设置”“安全”和底部主按钮。
- 将服务器地址右侧测试入口从含义较弱的图标调整为明确的“测试”文本操作，并继续复用现有连接测试逻辑。
- 将认证方式展示文案从 `BASIC` 调整为面向用户的“基础认证”，保留内部 `WebDavAuthMode.basic` 业务值。
- 将根路径归入“高级设置”，并增加“用于指定 WebDAV 同步目录”的辅助说明，不改变默认值、规范化和保存逻辑。
- 将“忽略 TLS 错误”面向用户展示为“允许不安全证书”，并增加“仅建议在可信内网或测试环境中开启”的辅助说明，不改变 `ignoreTlsErrors` 状态绑定。
- 增加底部主按钮“保存设置”。该按钮只作为表单保存/完成动作，不测试连接、不发起同步、不自动启用 WebDAV。
- 保持页面所有颜色来自现有主题、`settingsPageTokens`、`Theme.of(context).colorScheme`、平台/settings seam 或已有设计 token，不修改 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors` 或 ThemeExtension。
- 收敛连接页局部警告/提示视觉到主题或 settings seam，避免为普通设置 surface 新增硬编码颜色。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 细化 WebDAV 连接设置页的分组、文案、底部保存动作、主题颜色约束和行为保持要求。

## Impact

- 主要影响 `memos_flutter_app/lib/features/settings/webdav_sync_screen.dart` 的 `_WebDavConnectionScreen` 展示层。
- 可能更新 `memos_flutter_app/test/features/settings/webdav_conflict_flow_test.dart`，覆盖“测试”文本操作、“保存设置”按钮、认证文案、安全开关文案和现有连接测试行为。
- 可能更新或补充 settings UI drift/architecture guardrail 相关验证，但不扩大 allowlist。
- 不修改 WebDAV protocol、sync/backup service、repository、data model、持久化 key、Provider 结构、API adapters 或数据库 schema。
- 不修改全局主题文件、主题 token、商业/private hooks 或 paid-feature 逻辑。
- 当前架构阶段为 `evolve_modularity`。本 change 触及 settings 页面展示区域，应保持已迁移的 settings semantic seam 使用方式，不引入新的 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖；对应模块化清单重点关联 7、8、9、10，并保持 critical checklist 1-4 不恶化。
