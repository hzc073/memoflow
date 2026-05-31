# desktop-share-task-window Specification

## Purpose
TBD - created by archiving change add-desktop-share-task-window. Update Purpose after archive.
## Requirements
### Requirement: Desktop share preview SHALL use a dedicated task-window model when supported

桌面端分享预览 SHALL use a dedicated one-shot share task window when the current desktop platform supports the required window, IPC, and share capture capabilities.

#### Scenario: Supported desktop platform receives a preview share payload
- **WHEN** a share payload requiring preview/capture is received on a supported desktop platform
- **THEN** the app SHALL open a dedicated share task window for the share preview
- **AND** it SHALL NOT push the share preview as a normal main-window secondary route
- **AND** the share task window SHALL own only that share task.

#### Scenario: Desktop share task window is unsupported or fails to open
- **WHEN** a share payload requiring preview/capture is received on desktop
- **AND** the current platform does not support share task windows or the share window fails to open
- **THEN** the app SHALL fall back to the existing main-window share flow
- **AND** the fallback SHALL preserve existing share capture, link-only, save, attachment, and composer behavior.

#### Scenario: macOS is enabled before other desktop platforms
- **WHEN** the desktop share task window model is implemented incrementally
- **THEN** macOS MAY be enabled first
- **AND** Windows and Linux SHALL remain behind explicit capability gates until their sub-window runtime requirements are verified
- **AND** the implementation SHOULD still use shared desktop share window seams rather than macOS-only APIs in business logic.

### Requirement: Share task window SHALL use native close semantics

Share task windows SHALL rely on native desktop window close controls for canceling the share task, rather than App-owned generic close/cancel controls.

#### Scenario: User closes the share task window natively
- **WHEN** the user closes the share task window through native close controls, `Cmd+W`, `Alt+F4`, Window menu Close, or taskbar close where applicable
- **THEN** the current share task SHALL be canceled
- **AND** the main window SHALL remain open
- **AND** the app SHALL NOT treat the close request as a main-window route pop.

#### Scenario: Share preview is the task root
- **WHEN** the share preview is displayed as the root of a share task window
- **THEN** it SHALL NOT render an App-owned generic close button
- **AND** it SHALL NOT render an App-owned generic cancel button
- **AND** it SHALL NOT render a main-window back affordance merely because the share preview used to be a secondary route.
- **AND** it SHALL consume the shared desktop window chrome safe-area rule when native window controls can overlap top-level Flutter content.

#### Scenario: Share window opens an internal child page
- **WHEN** the share task window opens an internal child page such as a video preview
- **THEN** that child page MAY render App-level Back navigation
- **AND** Back SHALL return to the share task root inside the share window
- **AND** Back SHALL NOT close the whole share task window unless explicitly documented for that child task.

### Requirement: Share task result SHALL be handed off to the main window

Successful share task actions SHALL send a structured result to the main window. The main window SHALL own opening the existing composer/editing flow.

#### Scenario: Share task completes successfully
- **WHEN** the user chooses a successful share action from the share task window
- **THEN** the share window SHALL send a `ShareComposeRequest` or equivalent structured result to the main window
- **AND** the main window SHALL foreground/focus itself before opening the existing composer flow
- **AND** the share task window SHALL close after the result handoff is accepted
- **AND** the share task state associated with that window SHALL be released so later clipboard-detected clipping attempts are not blocked by stale active-task state.

#### Scenario: Share task is canceled
- **WHEN** the share task window is closed without a successful result
- **THEN** no composer SHALL be opened
- **AND** any share task state associated with that window SHALL be discarded
- **AND** other active share task windows SHALL NOT be affected
- **AND** the canceled task SHALL NOT continue suppressing later clipboard-detected clipping attempts.

#### Scenario: Multiple share windows are active
- **WHEN** multiple share task windows are open at the same time
- **THEN** each window SHALL carry an independent request id or equivalent correlation key
- **AND** result handoff SHALL NOT mix payloads, results, attachments, or user messages between windows
- **AND** completing or canceling one task SHALL NOT release global share-flow suppression while another share task remains active.

### Requirement: Desktop share task window capability SHALL be platform gated

Desktop share task window support SHALL be enabled per platform only after required sub-window runtime capabilities are known.

#### Scenario: Required WebView/capture capability works in a desktop sub-window
- **WHEN** `ShareCaptureInAppWebViewEngine` or its replacement is verified inside the platform's share sub-window runtime
- **THEN** share task window support MAY be enabled for that platform
- **AND** the implementation SHALL keep a fallback path for launch or runtime failures.

#### Scenario: Required WebView/capture capability is unavailable or unstable
- **WHEN** the required WebView/capture capability is unavailable or unstable in a platform sub-window
- **THEN** share task window support SHALL remain disabled for that platform
- **AND** the app SHALL use the existing main-window share flow or another explicitly documented fallback.

#### Scenario: Sub-window plugin registration is changed
- **WHEN** platform runner sub-window plugin registration is changed to support share task windows
- **THEN** the registration SHALL remain explicit and reviewed
- **AND** it SHALL NOT blindly call full main-window plugin registration if that would reintroduce known multi-window instability.

### Requirement: Desktop share task window implementation SHALL preserve boundaries

Desktop share task window support SHALL reuse approved desktop window and share seams without changing settings-window behavior or introducing new reverse dependencies.

#### Scenario: Desktop share window launcher is added or extended
- **WHEN** the desktop share window launcher, capability, or IPC seam is added or extended
- **THEN** shared desktop/window code SHALL NOT import feature UI directly from lower layers such as `core`
- **AND** share payload/result serialization SHALL stay in an approved feature/application seam
- **AND** settings window behavior SHALL remain unchanged.

#### Scenario: Existing main-window share fallback remains
- **WHEN** a platform uses the fallback main-window share flow
- **THEN** the fallback SHALL keep existing behavior equal or better
- **AND** fallback code SHALL be documented as a capability fallback, not as a second permanent product model.

#### Scenario: Public desktop shell code is changed
- **WHEN** desktop share task window, startup, runner, or window-channel code is changed in the public repository
- **THEN** it MUST NOT include StoreKit, subscription, buyout, entitlement, receipt, product ID, price, paywall, billing, App Store Connect, signing secret, notarization, TestFlight, or private release automation logic.

