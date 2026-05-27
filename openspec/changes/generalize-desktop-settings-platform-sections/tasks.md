## 1. Preparation

- [ ] 1.1 Audit current references with `rg WindowsRelatedSettingsScreen|windows_related|msg_windows_related_settings|msg_configure_windows_desktop_shortcuts` and decide whether to delete the old screen or keep a thin compatibility wrapper.
- [ ] 1.2 Confirm current desktop target handling in `settings_screen.dart`, `desktop_settings_window_app.dart`, `platform_target.dart`, and existing settings UI seams before editing.

## 2. Desktop Settings Surface

- [ ] 2.1 Create or rename the Windows-related settings page to a desktop settings surface using `SettingsPage`, `SettingsSection`, `SettingsNavigationRow`, and `SettingsToggleRow`.
- [ ] 2.2 Implement platform-section composition for shared desktop, Windows, macOS, and Linux fallback states without introducing lower-layer feature imports.
- [ ] 2.3 Keep desktop shortcut navigation in the shared desktop section for supported desktop targets and remove Windows-only copy from that shared row.
- [ ] 2.4 Keep `windowsCloseToTray` visible and mutable only in the Windows section, using the existing `devicePreferencesProvider` owner.

## 3. Entry Points And Localization

- [ ] 3.1 Update the main settings page so desktop targets use the “桌面设置” semantic entry instead of a Windows-only entry.
- [ ] 3.2 Update `DesktopSettingsWindowApp` pane enum, label, icon, and route mapping so the independent settings window renders the same desktop settings surface.
- [ ] 3.3 Add or replace i18n keys for desktop settings and desktop shortcut copy while preserving truly Windows-specific permission/lifecycle strings.
- [ ] 3.4 Regenerate localization output and verify no stale user-visible “Windows related settings” label remains in desktop settings entry points.

## 4. Guardrails And Tests

- [ ] 4.1 Move the migrated desktop settings page out of the settings UI drift legacy allowlist and into migrated coverage.
- [ ] 4.2 Add focused widget tests for Windows, macOS, and Linux/fallback desktop settings sections.
- [ ] 4.3 Add or update tests covering the main settings entry and desktop settings window pane label/route consistency.
- [ ] 4.4 Check that touched public settings files do not introduce commercial terms, paid-feature branching, or `AccessDecision.source` business logic.

## 5. Verification

- [ ] 5.1 Run focused settings and architecture tests from `memos_flutter_app`.
- [ ] 5.2 Run `flutter analyze` from `memos_flutter_app`.
- [ ] 5.3 Run `flutter test` from `memos_flutter_app` or document any environment blocker.
- [ ] 5.4 Manually smoke Windows and macOS desktop settings entry points when platform access is available; document Linux as not fully adapted.
