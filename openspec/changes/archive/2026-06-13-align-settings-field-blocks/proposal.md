## Why

WebDAV“服务器连接”页暴露出一个更通用的问题：部分设置页的 filled 输入框嵌在 list row 的 subtitle 区域里，外层 section、系统 row padding 和输入框 surface 三层布局叠加后，在移动端会出现灰色输入背景不齐、贴边或层级过重的观感。现在已经有 `SettingsFieldBlock` 这类更扁平的字段块方向，适合把该修正沉淀到 settings form seam，而不是继续逐页打补丁。

当前架构阶段是 `evolve_modularity`。本 change 触及 `features/settings/settings_ui.dart` 和若干 settings migrated files，应通过收敛共享表单布局、更新 guardrail 来让 settings 展示热点结构更好，而不是扩散页面私有字段组件。

## What Changes

- 将长文本、密码/密钥、多行文本等完整宽度输入的视觉对齐规则收敛到 settings-owned seam，避免字段继续依赖 `PlatformListSectionRow` subtitle 布局造成灰色输入框错位。
- 让 `SettingsFormFieldRow`、`SettingsMultilineFieldRow` 或其等价实现复用统一的 field block padding、label、helper/error 和 filled field surface。
- 评估并迁移已知高感知设置页中的长输入字段，包括 AI proxy、image bed、location provider key、自定义通知、AI user profile、export logs 等。
- 保留短文本/短数字 inline 输入语义；仅在窄屏 fallback 或长/敏感字段场景使用完整 field block。
- 更新 `settings_ui_drift_guardrail_test.dart`，防止 migrated settings files 回退到页面私有表单灰框或 subtitle-based misaligned form field。
- 不改变任何设置业务逻辑、provider 状态、持久化 key、API adapter、WebDAV 协议、同步/备份行为或全局主题色。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `platform-adaptive-ui-system`: 明确 settings form field seam 需要提供统一的 field block 对齐、触区、灰色输入 surface 和 theme-derived styling。
- `settings-subpage-platformization`: 明确 migrated settings subpages 中的长输入、密钥、密码和多行字段需要走 settings-owned field seam，并保持业务语义不变。

## Impact

- 主要影响 `memos_flutter_app/lib/features/settings/settings_ui.dart`。
- 可能触及以下 settings/settings-adjacent 页面以替换或复用统一 field block：
  - `memos_flutter_app/lib/features/settings/ai_proxy_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/image_bed_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/location_settings_screen.dart`
  - `memos_flutter_app/lib/features/settings/ai_user_profile_screen.dart`
  - `memos_flutter_app/lib/features/settings/export_logs_screen.dart`
  - `memos_flutter_app/lib/features/reminders/custom_notification_screen.dart`
- 测试影响：
  - 更新或新增 settings UI seam focused tests。
  - 更新 settings UI drift guardrail。
  - 运行相关 focused widget tests、`flutter analyze`、必要的 architecture guardrails。
- 不修改 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、全局 `ThemeData`、`ColorScheme`、`MemoFlowPalette`、`AppColors`、ThemeExtension、private hooks 或商业/paid-feature 逻辑。
