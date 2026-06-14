## ADDED Requirements

### Requirement: Desktop submit shortcut binding SHALL submit memo content

桌面端 memo 输入面 SHALL 使用 `desktopShortcutBindings[DesktopShortcutAction.publishMemo]` 作为直接提交/发送 memo 的可配置快捷键。该快捷键的语义是提交当前可提交内容，而不是只保存草稿。

#### Scenario: Configured submit binding submits focused editor content

- **GIVEN** app 运行在支持 desktop shortcuts 的 Windows 或 macOS
- **AND** 用户已为 `DesktopShortcutAction.publishMemo` 配置一个有效快捷键
- **AND** 支持该 action 的 memo 输入面处于 focused editor 状态且内容可提交
- **WHEN** 用户按下配置的 `publishMemo` 快捷键
- **THEN** 系统 SHALL 触发该输入面的直接提交/发送路径
- **AND** SHALL NOT 仅保存草稿或只更新 draft persistence

#### Scenario: Default binding remains primary Enter

- **WHEN** 用户未自定义 `DesktopShortcutAction.publishMemo`
- **THEN** 默认提交快捷键 SHALL 继续解析为 primary + `Enter`
- **AND** primary modifier SHALL follow existing desktop shortcut platform mapping: Windows 使用 `Ctrl`，macOS 使用 `Cmd`

### Requirement: Plain Enter SHALL remain multiline editor input

桌面端 memo 输入面在 text editor 聚焦时 SHALL preserve plain `Enter` as multiline editing input or existing smart-enter behavior. Plain `Enter` MUST NOT become a submit/send command.

#### Scenario: Plain Enter inserts or preserves line-break editing behavior

- **GIVEN** 一个桌面 memo 输入面的 text editor 已聚焦
- **WHEN** 用户按下 plain `Enter`
- **THEN** 该输入面 SHALL keep multiline editing ownership of the key press
- **AND** SHALL NOT submit/send the memo
- **AND** SHALL NOT navigate away from the focused editor

#### Scenario: Selected memo navigation does not steal focused editor Enter

- **GIVEN** 桌面首页有 selected memo 可通过 plain `Enter` 打开
- **AND** 首页 inline compose editor 已聚焦
- **WHEN** 用户按下 plain `Enter`
- **THEN** key press SHALL remain owned by the editor
- **AND** selected memo navigation SHALL NOT run

### Requirement: Submit shortcut matching SHALL be shared and testable

桌面提交快捷键匹配 SHALL be implemented through the existing desktop shortcut seam or an equivalent focused helper. Screen/widget files SHALL NOT each reimplement platform primary modifier semantics or hard-code `Ctrl+Enter` for submit/send behavior.

#### Scenario: Surfaces consume shared matching semantics

- **WHEN** `MemoEditorScreen`、home inline compose、`NoteInputSheet`、或 desktop quick input window handles submit shortcuts
- **THEN** each surface SHALL consume normalized `DesktopShortcutAction.publishMemo` matching semantics from a shared helper or existing shortcut delegate seam
- **AND** each surface SHALL keep submit side effects in its existing surface-owned save or submit callback unless a separate approved change moves that ownership

#### Scenario: Lower layers do not import feature UI

- **WHEN** shared submit shortcut matching is implemented
- **THEN** `core` helper code SHALL NOT import `features/*`, `state/*`, `application/*`, `data/*`, or API code
- **AND** `state`, `application`, and `core` SHALL NOT add new imports from memo feature screens for this behavior

### Requirement: Shortcut setting persistence SHALL remain compatible

桌面提交快捷键配置 SHALL continue to use the existing `desktopShortcutBindings` storage schema and `DesktopShortcutAction.publishMemo` action key.

#### Scenario: Existing stored binding remains valid

- **GIVEN** user preferences already contain a stored `publishMemo` desktop shortcut binding
- **WHEN** app loads device preferences
- **THEN** the binding SHALL remain valid without migration
- **AND** supported desktop memo input surfaces SHALL use that binding for submit/send

#### Scenario: Setting a new submit shortcut persists and affects runtime behavior

- **WHEN** 用户在 desktop shortcuts settings 中为 `publishMemo` 捕获新的有效快捷键
- **THEN** the app SHALL persist that binding through `DevicePreferencesController`
- **AND** subsequent shortcut dispatch in supported desktop memo input surfaces SHALL use the new binding
