## ADDED Requirements

### Requirement: Toolbar location settings entry SHALL reuse desktop settings target routing

当 desktop runtime 中的 memo compose 工具栏定位入口需要打开定位设置时，系统 SHALL 复用 `DesktopSettingsWindowTarget.location` target routing，使入口落到独立 settings window 的 `Components` owner surface 和定位页。

#### Scenario: Desktop toolbar prompt opens location target

- **WHEN** 用户在支持 desktop settings window 的 runtime 中从 compose toolbar 点击定位
- **AND** location provider requirements 校验失败
- **AND** 用户在提示弹窗中选择打开设置
- **THEN** 系统 SHALL open or focus the desktop settings window with `DesktopSettingsWindowTarget.location`
- **AND** the settings window SHALL switch to the `Components` pane
- **AND** the pane navigator SHALL show `LocationSettingsScreen`
- **AND** the route SHALL match the settings window target behavior used by other location settings entry points

#### Scenario: Desktop toolbar prompt keeps visible fallback

- **WHEN** toolbar location settings opener requests `DesktopSettingsWindowTarget.location`
- **AND** the desktop settings window is unsupported, cannot be opened, cannot be focused, cannot be routed, or reports failure
- **THEN** the caller SHALL open a visible fallback `LocationSettingsScreen` in the current main navigation context when that context remains mounted
- **AND** the failed settings window request SHALL NOT silently leave the user on the provider-not-ready prompt without a settings path

#### Scenario: Target routing boundary remains safe

- **WHEN** toolbar location settings routing is added or changed
- **THEN** target-to-widget mapping SHALL remain in `features/settings/desktop_settings_window_app.dart` or an equivalent settings UI composition point
- **AND** lower layers SHALL pass stable target values only
- **AND** implementation MUST NOT add new `application -> features/settings` or `core -> features/settings` imports to resolve `LocationSettingsScreen`
- **AND** no commercial/private behavior SHALL be introduced into public desktop settings routing
