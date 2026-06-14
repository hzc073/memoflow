## 1. Preflight and Existing State

- [x] 1.1 确认当前 worktree 中与本 change 无关的用户改动，避免覆盖既有 `memos_flutter_app/lib/features/memos`、`features/settings`、`i18n` 和 OpenSpec 文件改动。
- [x] 1.2 修复或同步当前 i18n generated output 阻断，使 `preferences_settings_screen.dart` 引用的 localization getter 能通过编译，或在实现说明中记录无法运行相关 widget tests 的具体阻断。
- [x] 1.3 复核 `DesktopShortcutAction.publishMemo` 当前 default binding、settings capture、device preference persistence、quick record hotkey registration refresh path，确认不需要 storage schema migration。

## 2. Shared Shortcut Matching Seam

- [x] 2.1 在 `memos_flutter_app/lib/core/desktop/shortcuts.dart` 或同层 focused helper 中增加可复用 action matching helper，基于 `normalizeDesktopShortcutBindings` 和 `matchesDesktopShortcut` 处理 `DesktopShortcutAction.publishMemo`。
- [x] 2.2 为 helper 增加 focused unit tests，覆盖 Windows `Ctrl+Enter`、macOS `Cmd+Return`、自定义 modifier binding、`NumpadEnter` 等价行为、plain `Enter` 不匹配提交。
- [x] 2.3 确认 helper 不导入 `features/*`、`state/*`、`application/*`、`data/*` 或 API code，保持 desktop common layer 纯函数边界。

## 3. Surface Wiring

- [x] 3.1 更新 `MemoEditorScreen` 的 desktop modal/fullscreen shortcut handling，让 save/submit 使用配置的 `DesktopShortcutAction.publishMemo` binding，移除或隔离硬编码 `Ctrl+Enter` 提交路径。
- [x] 3.2 保持 `MemoEditorScreen` plain `Enter` multiline/smart-enter behavior，并确保 configured submit shortcut 只触发一次 save path。
- [x] 3.3 让 `NoteInputSheet` 的 desktop editor shortcut path 使用 shared matching helper，保持 `_submitOrVoice()`、draft cleanup、attachments、visibility、location 和 sync 行为不变。
- [x] 3.4 让 desktop quick input window 的 editor shortcut path 使用 shared matching helper，保持 `_submit()`、formatting shortcuts、window close shortcuts 和 existing logging behavior。
- [x] 3.5 复核 `MemosListDesktopShortcutDelegate` / 首页 inline compose 使用同一匹配语义，保留 `Shift+Enter` fallback 且不让 selected memo plain `Enter` navigation 抢占 focused editor。
- [x] 3.6 如需调整 settings/overview 文案，将 `publishMemo` 的用户可见 label 收敛为“提交/发送记录”语义，同时不改变 enum name 或 storage key。

## 4. Tests

- [x] 4.1 增加或更新 `test/core/desktop/shortcuts_test.dart`，覆盖 shared helper、platform primary modifier 和 binding label expectations。
- [x] 4.2 增加 settings focused widget/provider test，验证 `DesktopShortcutsSettingsScreen` 捕获 `publishMemo` 新快捷键后写入 `DevicePreferencesController` 并持久化。
- [x] 4.3 更新 `memo_editor_screen_edit_draft_test.dart`，覆盖 desktop editor plain `Enter` 不保存、默认/custom submit binding 保存、macOS primary binding 行为、只保存一次。
- [x] 4.4 更新 `memos_list_desktop_shortcut_delegate_test.dart` 或 `memos_list_screen_test.dart`，覆盖 inline compose configured submit binding、`Shift+Enter` fallback、plain `Enter` 不打开 selected memo。
- [x] 4.5 增加或更新 `NoteInputSheet` 相关 focused tests，覆盖 configured submit binding 和 plain `Enter` 编辑行为。
- [x] 4.6 增加或更新 desktop quick input focused tests，覆盖 configured submit binding、formatting shortcut 不回归、plain `Enter` smart-enter behavior。
- [x] 4.7 保留 quick record system hotkey tests，确认 `DesktopQuickInputController` 在 shortcut binding 变化后仍重新注册 `quickRecord`，且提交快捷键改动不影响 system hotkey boundary。

## 5. Guardrails and Verification

- [x] 5.1 运行 focused tests：`flutter test test/core/desktop/shortcuts_test.dart test/features/memos/memos_list_desktop_shortcut_delegate_test.dart test/features/memos/memo_editor_screen_edit_draft_test.dart test/application/desktop/desktop_quick_input_controller_test.dart --reporter expanded`。
- [x] 5.2 运行新增 settings、note input、desktop quick input focused tests。
- [x] 5.3 运行相关 architecture guardrails，确认未新增 `state -> features`、`application -> features`、`core -> higher layer` 依赖，且 helper 保持 dependency-free。
- [x] 5.4 运行 `flutter analyze`；如当前 worktree 的无关改动仍阻断，记录具体文件和错误。
- [x] 5.5 运行 `flutter test` 或至少说明未运行全量测试的阻断原因。
- [x] 5.6 运行 `openspec validate unify-desktop-submit-shortcut-bindings --strict`。
- [x] 5.7 复核本 change 未编辑 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，未引入 subscription、billing、entitlement、paywall、StoreKit、private overlay 或 `AccessDecision.source` business branching。
