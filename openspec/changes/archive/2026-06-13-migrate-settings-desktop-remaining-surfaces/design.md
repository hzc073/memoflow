## Context

Settings UI migration 已经覆盖普通 settings pages、AI settings pages、WebDAV、import/export、migration、shortcuts/toolbar、utility 和 security/account surfaces。当前剩余 allowlist 是：

- `desktop_shortcuts_overview_screen.dart`: 普通快捷键总览页面，仍是 page-local `Scaffold` / card / palette。
- `desktop_settings_window_app.dart`: 独立桌面设置窗口 app/workbench。它包含 theme setup、workspace reload、method channel、settings target routing、pane navigator 和 sidebar nav。

当前架构阶段为 `evolve_modularity`。本 change 触碰 desktop settings hotspot，必须只迁移 visual drift，不改桌面窗口行为 owner。

## Decisions

### Decision 1: Shortcut overview is a normal settings page

`DesktopShortcutsOverviewScreen` SHALL use `SettingsPage` and `SettingsSection` or equivalent settings seams. Shortcut rows can remain file-local presentation helpers if they consume `settingsPageTokens` / `ColorScheme` and no longer use direct `Scaffold` / `MemoFlowPalette`.

Rationale: 它只是一个可滚动的快捷键总览子页，不需要特殊 window shell。

### Decision 2: Desktop settings window app keeps composition-root theme apply

`DesktopSettingsWindowApp` may keep `MemoFlowPalette.applyThemeColor(...)` because it is the independent settings window composition root applying user theme preferences before building `MaterialApp`. This SHALL be documented as a narrow guardrail allowance. Other visual palette usage in the file, especially sidebar nav tile colors, SHALL move to `ThemeData.colorScheme` or settings/platform tokens.

Rationale: 强行移除 theme apply 会改变全局主题行为；但侧栏 nav tile palette usage 是普通 visual drift，可以迁移。

### Decision 3: No desktop lifecycle or routing behavior changes

This change SHALL NOT modify method channel handlers, window manager setup, workspace snapshot reload, AI target routing, pane navigator behavior, or close/visibility behavior.

Rationale: settings UI drift cleanup should not take ownership of desktop lifecycle behavior.

## Risks / Trade-offs

- [Risk] Over-tightening guardrail breaks legitimate composition-root theme setup. Mitigation: add a narrow `palette: 1` allowance only for `desktop_settings_window_app.dart` with comment.
- [Risk] Shortcut overview row migration changes labels or shortcut rendering. Mitigation: keep `normalizeDesktopShortcutBindings`, action labels, and binding label construction unchanged.
- [Risk] Desktop settings sidebar color changes affect contrast. Mitigation: use `ColorScheme.primary`, `surfaceContainerHighest`, `onSurfaceVariant`, and existing selected/hover alpha behavior.

## Migration Plan

1. Migrate `DesktopShortcutsOverviewScreen` root to `SettingsPage`, group rows through `SettingsSection`, and switch row/group colors to settings tokens.
2. Update `_DesktopPaneNavTile` to use `ColorScheme` instead of `MemoFlowPalette`.
3. Update `settings_ui_drift_guardrail_test.dart`: move shortcut overview to `migratedFiles`, keep desktop window app allowlisted only with `palette: 1`.
4. Run focused desktop settings/shortcut tests, settings drift guardrail, modularity guardrail, `flutter analyze`, and `openspec validate`.
