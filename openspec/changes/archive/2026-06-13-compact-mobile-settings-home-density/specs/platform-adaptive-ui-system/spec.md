## ADDED Requirements

### Requirement: Mobile settings home density SHALL stay compact within the home hierarchy
手机端设置首页 SHALL 支持 home-only compact density treatment，用于降低普通功能入口行高、顶部快捷入口高度、分组间距和 profile 内边距，同时保持 `enhance-mobile-settings-home-hierarchy` 建立的 profile card、quick shortcut tiles、grouped function sections 和 row divider 层级模型。

#### Scenario: Phone home ordinary function rows use compact density
- **WHEN** 手机端设置首页渲染 `SettingsHomeSection` 中的普通单行 function entries，例如使用指南、账号与安全、偏好设置、AI 设置、应用锁、实验室、功能组件、反馈、充电站、导入 / 导出、关于或 equivalent entries
- **THEN** Material phone single-line rows SHALL use 48 logical pixels as the compact target height through settings-owned home density tokens 或 approved settings/platform seam
- **AND** rows with descriptions, multiline content, larger text scale, or platform accessibility constraints MAY grow beyond 48 logical pixels to preserve readable content
- **AND** the compact row treatment SHALL NOT be hardcoded in `settings_screen.dart`

#### Scenario: Phone home hierarchy tokens use the first compact values
- **WHEN** `settingsPageTokens(context).homeHierarchy` resolves for phone form factor
- **THEN** quick shortcut tile height SHALL be 80 logical pixels
- **AND** section spacing SHALL be 12 logical pixels
- **AND** profile padding SHALL be 16 logical pixels
- **AND** these values SHALL be resolved through `settings_ui.dart` or an approved settings-owned seam

#### Scenario: Compact density preserves grouped section hierarchy
- **WHEN** 手机端设置首页渲染普通功能入口
- **THEN** ordinary entries SHALL remain inside grouped sections with row dividers where applicable
- **AND** ordinary entries SHALL NOT be forced into separate cards unless they are explicit quick shortcut tiles or approved special entries
- **AND** profile and quick shortcut entries SHALL preserve existing navigation, haptic, avatar rendering, icon/label semantics, and tap behavior

#### Scenario: Compact density does not affect secondary settings pages
- **WHEN** 用户从设置首页进入二级或三级 settings pages
- **THEN** those pages SHALL continue to use standard `SettingsPage`、`SettingsSection`、settings semantic rows, and platform row density
- **AND** mobile settings home compact row height, shortcut tile height, profile padding, and section spacing SHALL NOT automatically apply to those pages

#### Scenario: Desktop settings remains dense and work-focused
- **WHEN** 设置首页运行在 macOS、Windows 或 Linux desktop experience
- **THEN** desktop presentation SHALL preserve existing bounded, dense, work-focused settings layout
- **AND** it SHALL NOT be forced to use phone-only 48dp home rows, 80dp shortcut tiles, phone profile padding, or phone section spacing

#### Scenario: Home density is guarded and boundary-safe
- **WHEN** settings home density, settings UI seam, or platform list row seam code is modified
- **THEN** verification SHALL cover phone home compact row density, shortcut tile height, section spacing, profile padding, grouped sections, and secondary-page isolation
- **AND** implementation SHALL NOT introduce new `state -> features`、`application -> features`、`core -> state|application|features` dependencies or `platform/` imports from higher layers
- **AND** public code MUST NOT include subscription、billing、entitlement、receipt、paywall、StoreKit、private overlay 或 paid-feature branching logic
