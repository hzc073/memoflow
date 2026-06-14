## ADDED Requirements

### Requirement: Desktop memo editor SHALL use configured submit shortcut

Desktop memo editor surface SHALL use the configured `DesktopShortcutAction.publishMemo` binding for direct submit/save of the current memo content. It MUST NOT hard-code `Ctrl+Enter` as the only desktop submit shortcut.

#### Scenario: Configured submit binding saves desktop editor

- **GIVEN** app 运行在支持 desktop shortcuts 的平台
- **AND** desktop memo editor surface 以 centered modal 或 fullscreen mode 打开
- **AND** editor text field 已聚焦且内容可保存
- **AND** `DesktopShortcutAction.publishMemo` 已配置为有效快捷键
- **WHEN** 用户按下配置的 `publishMemo` 快捷键
- **THEN** the editor SHALL run the existing memo save path exactly once
- **AND** the editor SHALL close or call `onSaved` according to existing save behavior

#### Scenario: Plain Enter keeps desktop editor multiline editing

- **GIVEN** desktop memo editor surface 已打开
- **AND** editor text field 已聚焦
- **WHEN** 用户按下 plain `Enter`
- **THEN** the editor SHALL keep the existing multiline or smart-enter editing behavior
- **AND** it SHALL NOT save, close, or leave the editor solely because plain `Enter` was pressed

#### Scenario: macOS primary submit uses Cmd

- **GIVEN** app 运行在 macOS
- **AND** `DesktopShortcutAction.publishMemo` 使用默认 primary + `Enter` binding
- **WHEN** 用户在 focused desktop memo editor 中按下 `Cmd+Return`
- **THEN** the editor SHALL run the existing memo save path
- **AND** `Ctrl+Return` SHALL NOT be the only supported configured submit shortcut on macOS

#### Scenario: Configured numpad Enter remains equivalent when supported

- **GIVEN** desktop memo editor supports a configured submit binding whose key is `Enter`
- **WHEN** 用户按下 semantically equivalent `NumpadEnter` with the same configured modifiers
- **THEN** the editor SHALL treat it as the same submit intent when the platform reports it distinctly
- **AND** plain `NumpadEnter` without the configured modifiers SHALL preserve multiline editing behavior
