# desktop-memo-editor-surface Specification

## Purpose
TBD - created by archiving change unify-desktop-memo-editor-surface. Update Purpose after archive.
## Requirements
### Requirement: Desktop wide memo editing SHALL use one editor surface

桌面宽布局中，所有明确表示“编辑已有笔记”的入口 SHALL resolve through a single desktop memo editor intent and SHALL render the same editor surface model.

#### Scenario: Preview pane edit opens unified editor

- **GIVEN** app 运行在支持 desktop preview pane 的宽布局
- **AND** 用户已在 preview pane 中选中一条 memo
- **WHEN** 用户点击 preview pane 的 edit action
- **THEN** the app SHALL open the selected memo through the desktop memo editor intent
- **AND** the editor SHALL appear as the unified desktop editor surface
- **AND** the preview pane SHALL remain a read-only preview surface rather than hosting a second editor UI.

#### Scenario: Detail edit delegates to unified editor

- **GIVEN** 用户从桌面 memo list 打开 memo detail
- **WHEN** 用户在 detail surface 触发 edit action
- **THEN** the edit request SHALL delegate to the desktop memo editor intent when an eligible desktop host exists
- **AND** it SHALL NOT push a separate `MemoEditorScreen` page with a different desktop UI.

#### Scenario: Memo card edit actions use the same presentation

- **GIVEN** app 运行在 desktop wide memo list
- **WHEN** 用户通过 card action menu、supported edit shortcut、或被产品定义为 edit 的 double tap gesture 触发编辑
- **THEN** each entry SHALL open the same desktop editor surface for the target memo
- **AND** no entry SHALL open a distinct editor route solely because it originated from a different UI element.

### Requirement: Desktop editor surface SHALL support centered and fullscreen modes

桌面 editor surface SHALL support a centered modal mode and a fullscreen mode using the same editor target and state.

#### Scenario: Centered modal is the default desktop wide editor

- **GIVEN** app 运行在 desktop wide layout
- **WHEN** 用户打开完整 memo editor for edit or create
- **THEN** the editor SHALL open as a home-contained centered modal by default
- **AND** the modal SHALL be visually centered in the desktop workspace
- **AND** background memo list or preview content SHALL NOT be interactive while the modal is active.

#### Scenario: Fullscreen keeps editor state

- **GIVEN** a desktop centered editor modal is open
- **AND** 用户已输入 text、添加 attachments、修改 visibility、选择 location、或 linked memos
- **WHEN** 用户切换到 fullscreen editor
- **THEN** the editor SHALL keep the same in-progress state
- **AND** it SHALL NOT recreate the editor as an unrelated route
- **AND** restoring from fullscreen SHALL return to the centered surface with the same state.

#### Scenario: Fullscreen prioritizes memo content

- **GIVEN** the desktop editor is in fullscreen mode
- **THEN** the memo editing content SHALL be the primary visible workspace
- **AND** unrelated memo list, preview pane, drawer, or destination content SHALL NOT be visible as competing surfaces
- **AND** required save、close、restore、and metadata controls MAY remain available as minimal editor chrome.

### Requirement: macOS desktop editor SHALL avoid native chrome overlap

macOS desktop editor surfaces SHALL account for native titlebar and traffic light areas.

#### Scenario: macOS centered editor avoids titlebar overlap

- **GIVEN** app 运行在 macOS desktop wide layout
- **WHEN** the desktop centered editor surface opens
- **THEN** editor controls, text field, and toolbar SHALL NOT overlap the macOS traffic lights or native titlebar hit area
- **AND** the editor SHALL respect the active desktop shell chrome/safe-area policy.

#### Scenario: macOS fullscreen editor avoids titlebar overlap

- **GIVEN** app 运行在 macOS
- **WHEN** 用户 expands the desktop editor to fullscreen
- **THEN** the fullscreen editor SHALL NOT place interactive editor controls underneath the native titlebar or traffic lights
- **AND** any content that extends into titlebar space SHALL use an explicit desktop window chrome safe-area policy.

#### Scenario: macOS menu new memo uses safe presentation

- **WHEN** 用户通过 macOS app menu 触发 New Memo
- **THEN** the app SHALL prefer an eligible current desktop home editor surface
- **AND** if no eligible home surface exists, the fallback editor SHALL still use a presentation that avoids native titlebar overlap
- **AND** it SHALL NOT fall back to a bare page presentation known to overlap macOS window chrome.

### Requirement: Desktop create memo MAY share the editor surface without replacing quick capture

桌面宽布局中，显式 create memo actions SHOULD use the same desktop editor intent for full compose, while desktop inline compose SHALL remain available as quick capture.

#### Scenario: Desktop create action opens full editor surface

- **GIVEN** app 运行在 desktop wide layout
- **WHEN** 用户触发明确的 create memo action that requests the full editor
- **THEN** the app SHOULD open the desktop memo editor intent with a new memo target
- **AND** it SHOULD use the same centered/fullscreen surface behavior as editing an existing memo.

#### Scenario: Inline compose remains quick capture

- **GIVEN** desktop inline compose is available in the memo list
- **WHEN** the desktop editor surface is unified
- **THEN** inline compose SHALL remain available for quick capture according to existing desktop inline compose rules
- **AND** inline compose SHALL NOT be required to edit existing memos
- **AND** opening or closing the full desktop editor SHALL NOT silently clear unrelated inline compose draft state.

#### Scenario: Mobile add button remains unchanged

- **GIVEN** app 运行在 phone layout
- **WHEN** 用户点击 add/create memo action
- **THEN** the app SHALL keep the existing mobile compose experience
- **AND** it SHALL NOT show the desktop centered modal surface.

### Requirement: Platform fallback behavior SHALL remain scoped

统一 desktop editor surface SHALL NOT force non-desktop or narrow layouts to adopt desktop UI.

#### Scenario: Mobile edit behavior remains unchanged

- **GIVEN** app 运行在 phone layout
- **WHEN** 用户编辑 existing memo
- **THEN** the app SHALL keep the existing mobile edit presentation
- **AND** the desktop editor modal/fullscreen rules SHALL NOT apply.

#### Scenario: Desktop narrow layout may keep existing fallback

- **GIVEN** app 运行在 desktop platform with a narrow window
- **WHEN** 用户 opens full memo editor
- **THEN** the app MAY keep an existing narrow dialog, fullscreen, sheet, or page fallback
- **AND** the fallback SHALL preserve memo editor state and avoid platform chrome overlap.

#### Scenario: API and commercial boundaries are preserved

- **WHEN** desktop editor surface rules are implemented
- **THEN** implementation SHALL NOT modify Memos server API request/response models, route adapters, or version compatibility logic
- **AND** it SHALL NOT add subscription, billing, entitlement, paywall, StoreKit, private overlay, paid-feature branching, or other commercial logic to public runtime files.

### Requirement: Editor opening policy SHALL preserve architecture boundaries

Desktop memo editor opening policy SHALL be owned by feature-local navigation/presenter seams and SHALL NOT introduce new lower-layer dependencies on UI features.

#### Scenario: Opening logic is centralized

- **WHEN** desktop memo editor opening paths are changed
- **THEN** edit/create route decisions SHALL be centralized in a focused intent, route delegate, presenter, or equivalent seam
- **AND** individual entry widgets SHALL delegate editor opening instead of each pushing their own `MemoEditorScreen` route.

#### Scenario: Lower layers do not depend on features

- **WHEN** editor opening policy is implemented
- **THEN** `state`, `application`, and `core` SHALL NOT add new imports from `features/*`
- **AND** shared editor opening rules SHALL NOT be hidden inside a low-level model or persistence service.

#### Scenario: Touched coupled areas improve or preserve modularity

- **WHEN** implementation touches home/memos/navigation coupling hotspots
- **THEN** it SHALL leave the touched area equal or better structured than before
- **AND** it SHALL add or tighten focused tests or guardrails that prevent editor entry points from diverging again.

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
