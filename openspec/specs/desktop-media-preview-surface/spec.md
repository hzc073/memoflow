# desktop-media-preview-surface Specification

## Purpose
TBD - created by archiving change desktop-media-preview-surface. Update Purpose after archive.
## Requirements
### Requirement: Desktop media previews SHALL open through a dedicated media surface

桌面端图片、视频和可预览附件 SHALL 通过独立媒体查看 surface 打开，而不是作为主窗口里的普通 full-page secondary route 显示。该 surface SHALL avoid ordinary page chrome and SHALL preserve the main workspace.

#### Scenario: Desktop image preview opens media surface
- **WHEN** 用户在桌面端从 memo 图片网格、memo detail、memo reader、memo editor 或 inline compose 中打开图片预览
- **THEN** the app SHALL open the image through the desktop media preview surface
- **AND** the main window workspace SHALL remain available after the media surface is closed
- **AND** the app SHALL NOT render a normal `AppBar` with App-level Back for that desktop media preview.

#### Scenario: Desktop video or mixed attachment preview opens media surface
- **WHEN** 用户在桌面端打开视频预览或包含图片/视频的附件预览
- **THEN** the app SHALL route the preview through the same desktop media preview surface model
- **AND** it SHALL NOT keep a separate desktop-only full-page `AttachmentGalleryScreen` or video route that renders ordinary page back chrome.

#### Scenario: Desktop media window is unavailable
- **WHEN** desktop media sub-window capability is unsupported or fails to open
- **THEN** the app SHALL fall back to an immersive media viewer that does not render ordinary `Back + Page Title` AppBar chrome
- **AND** the fallback SHALL still provide a safe close path such as `Esc` and a viewer-specific close affordance.

#### Scenario: Mobile media preview keeps existing route behavior
- **WHEN** 用户在 phone 或 tablet layout 打开图片、视频或可预览附件
- **THEN** the app SHALL keep the existing fullscreen media preview route
- **AND** the route SHALL preserve platform-appropriate back button, system back, or gesture behavior.

### Requirement: Desktop media surface SHALL use native and keyboard close semantics

桌面媒体查看 surface SHALL rely primarily on native window close controls and `Esc` for closing the viewer. Closing the media viewer SHALL NOT close the main window or silently pop unrelated main-window routes.

#### Scenario: Native close closes only the media surface
- **WHEN** 用户通过 macOS red close、Windows/Linux window close、`Cmd+W`、`Alt+F4` 或等价系统窗口关闭动作关闭桌面媒体 surface
- **THEN** only the media surface SHALL close
- **AND** the main MemoFlow window SHALL remain open
- **AND** the app SHALL NOT treat the native media-window close as a main-window route pop.

#### Scenario: Escape closes the active media surface
- **WHEN** a desktop media surface is focused
- **AND** 用户 presses `Esc`
- **THEN** the active media surface SHALL close
- **AND** unrelated memo drafts, pending attachments, preview pane selection, or editor state SHALL NOT be cleared solely because the viewer closed.

#### Scenario: Fallback close remains viewer-specific
- **WHEN** the desktop immersive fallback viewer is used inside the main window
- **THEN** its visible close affordance, if present, SHALL be viewer-specific
- **AND** it SHALL NOT be rendered as ordinary secondary page Back navigation.

### Requirement: Desktop media chrome SHALL be media-specific and window-control safe

桌面媒体查看 surface SHALL render only media-viewer chrome such as page count, navigation, zoom, download, edit/replace, loading, and error states. These controls SHALL avoid native window controls and SHALL NOT recreate ordinary page titlebar navigation.

#### Scenario: Media viewer omits ordinary page chrome
- **WHEN** a desktop media surface renders its root view
- **THEN** it SHALL NOT render a normal `AppBar`
- **AND** it SHALL NOT render App-level Back
- **AND** it SHALL NOT render a `Back + Page Title` header merely because the old media preview was a pushed route.

#### Scenario: Media controls remain available
- **WHEN** a desktop media request contains multiple items or permitted actions
- **THEN** the media surface SHALL expose expected media controls such as current index, previous/next navigation, zoom/reset, download, and edit/replace according to the request capabilities
- **AND** those controls SHALL remain usable by pointer and keyboard where the existing viewer supports keyboard navigation.

#### Scenario: macOS media controls avoid traffic lights
- **WHEN** a desktop media surface runs on macOS with native traffic lights visible
- **THEN** any top-leading media controls, status, title, or hit areas SHALL be laid out outside the traffic-light reserved area
- **AND** the implementation SHALL use shared desktop chrome safe-area policy or an equivalent shell-level wrapper rather than feature-local hardcoded padding.

### Requirement: Media request and result handling SHALL preserve source ownership

Desktop media preview SHALL preserve current media sources, authentication context, and edit/replace result ownership. The media surface MAY view and produce a result, but the feature owner that opened the viewer SHALL remain responsible for applying mutations.

#### Scenario: Current attachment source is used
- **WHEN** a memo media item has current local file, private attachment, remote URL, thumbnail, mime type, dimensions, or auth metadata
- **THEN** the desktop media request SHALL use the current preview-relevant metadata
- **AND** it SHALL NOT reuse stale queued-upload or deleted source metadata.

#### Scenario: Edit or replace result returns to owner
- **WHEN** a desktop media surface edits or replaces an image
- **THEN** it SHALL return a structured result such as `ImagePreviewEditResult` or an equivalent request-correlated payload
- **AND** the main window or original feature owner SHALL apply the replacement, update pending attachments, and show user feedback
- **AND** the media surface SHALL NOT directly mutate memo state through hidden cross-window callbacks.

#### Scenario: Closing without result does not mutate state
- **WHEN** a desktop media surface is closed without a download, edit, replace, or explicit result action
- **THEN** no memo, pending attachment, draft, sync, or local library state SHALL be changed solely by closing the viewer.

### Requirement: Desktop media opening policy SHALL preserve architecture boundaries

Desktop media preview opening policy SHALL be centralized in an approved feature-level presenter, launcher, route delegate, or desktop window seam. Implementation SHALL NOT add lower-layer dependencies on feature UI or spread desktop window decisions across individual media tiles.

#### Scenario: Entry widgets delegate to centralized media opening
- **WHEN** a memo image tile, markdown inline image, attachment tile, video tile, editor preview, or pending attachment preview opens media on desktop
- **THEN** the widget SHALL delegate to the centralized media preview opening seam
- **AND** it SHALL NOT independently push `ImagePreviewGalleryScreen`, `AttachmentGalleryScreen`, or a video preview route for desktop behavior.

#### Scenario: Lower layers do not import feature UI
- **WHEN** desktop media preview window support is implemented
- **THEN** `state`, `application`, and `core` SHALL NOT add new imports from `features/*` UI files
- **AND** desktop window/channel helpers SHALL communicate through serializable requests, callbacks owned by the feature layer, or existing approved seams.

#### Scenario: Public boundaries remain free of commercial logic
- **WHEN** desktop media preview surface code is added or changed
- **THEN** it SHALL NOT add subscription, billing, entitlement, receipt, paywall, StoreKit, private overlay, paid-feature branching, or other commercial logic to public runtime files.

#### Scenario: Focused guardrails protect media entry convergence
- **WHEN** media preview entry points are migrated
- **THEN** focused tests or architecture guardrails SHALL verify that desktop media preview entry points use the centralized seam
- **AND** they SHALL prevent reintroducing desktop `AppBar` Back chrome for media preview routes.
