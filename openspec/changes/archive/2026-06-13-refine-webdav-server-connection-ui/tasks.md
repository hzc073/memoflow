## 1. 边界确认

- [x] 1.1 阅读 `proposal.md`、`design.md` 和 `specs/platform-adaptive-ui-system/spec.md`，确认本 change 只覆盖 WebDAV“服务器连接”页面 UI 和文案。
- [x] 1.2 复查 `memos_flutter_app/lib/features/settings/webdav_sync_screen.dart` 中 `_WebDavConnectionScreen`、现有 `_testConnection()`、controller 回调、`_draftSettings()` 和 root path/server URL normalization 路径。
- [x] 1.3 确认不编辑 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、WebDAV service/repository/model、持久化 key、Provider 结构、数据库 schema、private hooks 或商业/paid-feature 相关文件。
- [x] 1.4 确认不修改全局 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension 或主题 token 文件。

## 2. 连接页 UI 整理

- [x] 2.1 将 `_WebDavConnectionScreen` 的可见内容整理为“基础设置”“认证设置”“高级设置”“安全”和底部“保存设置”动作，继续使用 `SettingsPage`、页面内轻量 section wrapper 和 settings semantic rows/actions。
- [x] 2.2 将服务器地址字段右侧测试入口改为明确的“测试”文本 action，保留现有 `_testConnection()`、loading 状态、禁用条件和成功/失败反馈。
- [x] 2.3 保留用户名、密码 controller 绑定和回调，确认密码显示/隐藏图标仍工作，图标颜色继续来自 theme/icon settings。
- [x] 2.4 将认证方式 visible value 从 `BASIC` 调整为“基础认证”，保留 `WebDavAuthMode.basic`、picker 选择和 provider 写入逻辑。
- [x] 2.5 将根路径放入“高级设置”，增加“用于指定 WebDAV 同步目录”说明，保留 `/MemoFlow/settings/v1` 默认值、controller 绑定和 normalization。
- [x] 2.6 将 `ignoreTlsErrors` 的 UI 标题调整为“允许不安全证书”，增加“仅建议在可信内网或测试环境中开启”说明，保留默认值、开关绑定和保存逻辑。
- [x] 2.7 增加底部主按钮“保存设置”，点击只收起键盘并复用现有保存/normalization 收尾，不调用连接测试、不发起同步、不自动启用 WebDAV。
- [x] 2.8 移除或替换连接页普通设置 surface 中新增/触及的硬编码颜色，确保新增视觉只来自 theme/settings/platform seam 或语义色派生。
- [x] 2.9 根据视觉反馈调整连接页背景容器：四个分组使用统一局部外壳，按钮与分组内容同宽，避免通用 inset grouped/plain mobile 分支造成容器层级不一致。
- [x] 2.10 根据视觉反馈调整输入灰框对齐：新增 settings 语义 `SettingsFieldBlock`，让连接页表单字段共享统一左右内边距和上下留白，避免系统 list tile subtitle 布局导致灰色输入背景看起来不齐。

## 3. 测试与守护

- [x] 3.1 更新 `memos_flutter_app/test/features/settings/webdav_conflict_flow_test.dart` 或新增 focused widget test，覆盖“测试”文本 action 仍调用现有连接测试并显示成功反馈。
- [x] 3.2 增加或更新 focused widget test，覆盖“保存设置”按钮存在且点击不会调用连接测试、WebDAV sync、backup、restore 或自动修改 enabled/backup/auto-sync 状态。
- [x] 3.3 增加或更新 focused widget test，覆盖“基础认证”“根路径”说明、“允许不安全证书”说明和密码显示/隐藏入口仍可用。
- [x] 3.4 运行 `flutter test test/features/settings/webdav_conflict_flow_test.dart --reporter expanded`。
- [x] 3.5 运行 `flutter test test/architecture/settings_ui_drift_guardrail_test.dart --reporter expanded`，确认 `webdav_sync_screen.dart` 未引入 settings UI drift。
- [x] 3.6 运行 `flutter test test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded`，确认依赖方向未恶化。

## 4. 最终验证

- [x] 4.1 运行 `openspec validate refine-webdav-server-connection-ui --strict`。
- [x] 4.2 从 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 4.3 从 `memos_flutter_app` 运行 `flutter test`，如环境限制导致无法完成，记录具体失败原因和已通过的 focused checks。
- [x] 4.4 检查最终 diff，确认未修改全局主题文件、API compatibility 文件、WebDAV 协议/service/repository/model、Provider 结构、private hooks、商业/paid-feature 逻辑或新增主题色系统。
- [x] 4.5 记录验证结果和剩余风险，确认“保存设置”按钮只做保存/收尾动作，不做网络测试或同步。
