## ADDED Requirements

### Requirement: Desktop quick record hotkey teardown SHALL avoid disposed UI state writes

桌面快速记录 hotkey 注销 SHALL 区分正常运行时状态更新与 app teardown 资源释放。App/widget dispose 期间释放 system hotkey 时，系统 SHALL NOT read or write Riverpod provider state through a disposed `WidgetRef`.

#### Scenario: Runtime unregister clears active state
- **WHEN** `DesktopQuickInputController.unregisterHotKey()` is called during normal runtime
- **THEN** the registered system hotkey SHALL be unregistered when present
- **AND** `desktopQuickRecordHotKeyRegistrationStatusProvider` SHALL be set to unavailable
- **AND** main-window quick record fallback MAY treat the system hotkey as inactive

#### Scenario: App dispose releases hotkey without provider write
- **WHEN** the app widget is being disposed or torn down by a widget test
- **THEN** the desktop quick record hotkey release path SHALL attempt to unregister any registered system hotkey
- **AND** it SHALL clear the controller's tracked hotkey reference
- **AND** it SHALL NOT read or write provider state through the disposed widget `ref`

#### Scenario: Teardown preserves registration failure diagnostics
- **WHEN** normal hotkey registration fails outside app teardown
- **THEN** the controller SHALL continue to expose failed or unavailable registration state through the existing provider path
- **AND** teardown-only behavior SHALL NOT swallow normal runtime status updates
