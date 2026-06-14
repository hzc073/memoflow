## Context

当前桌面快捷键模型集中在 `core/desktop/shortcuts.dart`，`DesktopShortcutAction.publishMemo` 默认绑定为 primary + `Enter`。设置页会把捕获到的快捷键写入 `devicePreferencesProvider.desktopShortcutBindings`，并由多个编辑入口读取。

实际行为存在分叉：

- `MemosListDesktopShortcutDelegate` 在首页 inline compose active 时读取配置的 `publishMemo`，并保留 `Shift+Enter` fallback。
- `NoteInputSheet` 和 desktop quick input window 也读取配置的 `publishMemo`。
- `MemoEditorScreen` 的 desktop modal/fullscreen path 仍硬编码 `Ctrl+Enter` / `Ctrl+NumpadEnter`，没有读取 `desktopShortcutBindings`。在 macOS 上，这也与 shortcut label 的 primary modifier 语义不一致，因为 primary 应优先表示 `Cmd`。

本 change 不改变 memo mutation、draft persistence、sync、API route 或 storage schema，只统一桌面输入 surface 的键盘提交语义。

架构阶段为 `evolve_modularity`。本 change 触及 `features/memos`、`features/desktop/quick_input` 和 `features/settings` 的快捷键/编辑器耦合区，需要让 touched area equal or better structured。当前依赖方向允许 feature UI 消费 `core/desktop/shortcuts.dart` 和 `state/settings/device_preferences_provider.dart`；实现不得新增 `state -> features`、`application -> features` 或 `core -> higher layer` 依赖。

## Goals / Non-Goals

**Goals:**

- 让所有桌面 memo 输入面使用同一份 `DesktopShortcutAction.publishMemo` binding 作为直接提交/发送快捷键。
- 保证 plain `Enter` 在输入框聚焦时继续换行或执行现有 smart-enter 编辑行为，不触发提交、导航或关闭。
- 让 macOS 的 primary submit shortcut 遵循 existing desktop shortcut primary modifier 规则，即配置中的 primary 在 macOS 对应 `Cmd`，Windows 对应 `Ctrl`。
- 保留当前 `Shift+Enter` submit fallback，并用测试明确它不依赖设置持久化。
- 补齐设置页捕获/持久化和配置生效的 focused tests。
- 在 `evolve_modularity` 下收敛硬编码：把配置化提交快捷键匹配封装到 focused helper 或现有 desktop shortcut seam，避免 screen 文件各自解释 primary/shift/alt/key。

**Non-Goals:**

- 不改变 `desktopShortcutBindings` 的 JSON schema、默认 action key 或迁移策略。
- 不把“提交发送”改成“保存草稿”；草稿保存仍由现有 draft persistence path 处理。
- 不重做所有快捷键设置 UI，也不新增快捷键 profile、多绑定或禁用 action 能力。
- 不新增 system-wide hotkey；除既有 `quickRecord` 外，提交发送快捷键只在 app/window 可接收键盘事件时生效。
- 不修改 Memos server API、data/api、sync payload、数据库 schema 或商业/private hooks。

## Decisions

### Decision: Reuse `publishMemo` as the submit/send action

继续使用 `DesktopShortcutAction.publishMemo` 作为提交发送 action，不新增 `saveMemo` 或 `submitMemo` enum 值。

Rationale:

- 现有 storage key 是 action enum name；新增或重命名 enum 会引入偏好迁移和兼容风险。
- 用户需求中的“保存”已确认语义是直接提交发送，与当前 `publishMemo` 行为一致。
- UI 文案可以后续微调为“提交记录/发送记录”而不改变 storage contract。

Alternative considered:

- 新增 `submitMemo` action 并迁移旧 `publishMemo`。该方案语义更准确，但会扩大迁移、设置页兼容和 overview 文案范围，不适合本次 scoped fix。

### Decision: Centralize shortcut matching before wiring surfaces

实现阶段应在 `core/desktop/shortcuts.dart` 或同层 focused helper 中提供 reusable 匹配能力，例如围绕 `matchesDesktopShortcut`/`normalizeDesktopShortcutBindings` 提供“按 action 解析并匹配”的小 helper。各输入 surface 只传入 active bindings、event、pressedKeys 和 action，不再自行散落 primary/shift/alt/key 判断。

Rationale:

- 当前 `MemoEditorScreen`、`NoteInputSheet`、quick input window 和 `MemosListDesktopShortcutDelegate` 都有相似判断。把 common matching 收敛到 desktop shortcut seam 可减少重复和分叉。
- `core/desktop/shortcuts.dart` 已经是 dependency-free desktop common layer，向 feature UI 提供纯函数不会引入反向依赖。
- 这满足 `evolve_modularity` 的局部改善要求：shared shortcut behavior 不继续隐藏在 screen/widget 文件中。

Alternative considered:

- 只在 `MemoEditorScreen` 里读取 provider 并复制现有 `matches` 函数。该方案最小，但会保留重复逻辑，未来容易再次出现配置生效不一致。

### Decision: Keep submit side effects owned by each surface

共享 seam 只负责判断“这个 KeyEvent 是否匹配 submit action”，不负责调用 `_save()`、`_submitInlineCompose()`、`_submitOrVoice()` 或 `_submit()`。

Rationale:

- 各输入 surface 的提交路径不同：full editor save、inline compose submit、note input submit-or-voice、quick input submit 都有自己的 busy state、toast、draft cleanup、sync orchestration。
- 把 side effect 抽到 lower layer 会引入 feature dependency 或过宽 callback abstraction，反而恶化边界。

### Decision: Plain Enter remains editor-owned

普通 `Enter` 在 text editor 聚焦时必须继续交给编辑器：插入换行、执行 smart-enter，或保持当前平台现有输入行为。只有匹配配置 submit binding 或 `Shift+Enter` fallback 时才直接提交发送。

Rationale:

- 用户明确要求“输入时回车换行没问题”，这应成为回归测试。
- 现有 `windows-home-inline-compose-keyboard` 已规定 inline compose 聚焦时 plain `Enter` 不打开选中 memo；本 change 不改变该 navigation guard。

### Decision: Treat settings persistence and runtime effect as separate tests

实现阶段应分别覆盖：

- 设置页 capture dialog 产生 binding 并写入 `DevicePreferencesController`。
- `DevicePreferencesController.setDesktopShortcutBinding` 持久化 binding。
- 各输入 surface 使用已经存在的 binding 触发提交。

Rationale:

- 用户看到的“不生效”可能来自 UI capture、落盘、运行时读取或某个 surface 硬编码。拆开测试能定位 future regressions。

## Risks / Trade-offs

- [Risk] `MemoEditorScreen` 可能存在 `FocusNode.onKeyEvent` 和 `CallbackShortcuts` 两条保存路径，调整不完整会导致同一快捷键双触发或只在部分 focus state 生效。Mitigation: focused widget test 覆盖 desktop modal editor 在 text field focused 时配置 submit binding 只保存一次，并验证 plain `Enter` 仍换行。
- [Risk] macOS test environment 里 `HardwareKeyboard.logicalKeysPressed` 与 `SingleActivator(meta: true)` 行为可能不同。Mitigation: 尽量把匹配逻辑放到纯函数单元测试，并补一个 macOS widget smoke for configured binding if stable。
- [Risk] `Shift+Enter` fallback 与用户自定义 binding 可能重复。Mitigation: 如果 binding 本身就是 `Shift+Enter`，dispatch reason 可以仍记录为 binding 或 fallback，但回调必须只触发一次。
- [Risk] 快捷键设置页当前是“按下即保存”，用户可能仍期待显式保存按钮。Mitigation: 本 change 先保证行为生效，并可在 UI 文案中明确 “Press the new shortcut” 后立即应用；不新增独立保存按钮。
- [Risk] 当前工作树存在 i18n generated file 与 YAML 不同步时，广泛 widget tests 会被无关编译错误阻断。Mitigation: 实现前先同步 i18n generation 或修复 generated artifact，再运行 focused tests。

## Migration Plan

1. 不做数据迁移，继续读取和写入 `desktopShortcutBindings.publishMemo`。
2. 先新增/调整 helper 和 focused tests，确认当前 `publishMemo` default 仍为 primary + `Enter`。
3. 将 `MemoEditorScreen` 的硬编码 `Ctrl+Enter` 替换为配置化匹配，同时保留 `NumpadEnter` 等价行为。
4. 复核 `NoteInputSheet`、quick input window、inline compose delegate 是否可复用 helper；若行为已正确，优先改为 helper 调用并补测试。
5. 若实现出现回归，可回退到原硬编码路径；无 storage migration rollback requirement。

## Open Questions

- 是否需要把 UI label 从 `Publish memo` / `发布记录` 调整为 `Submit memo` / `提交记录`？本 change 不要求改 enum，但文案可在实现中同步优化。
- 是否继续在 overview 中把 `publishMemo` 展示为 “configured binding / Shift+Enter”？建议保留，以符合现有 fallback。
