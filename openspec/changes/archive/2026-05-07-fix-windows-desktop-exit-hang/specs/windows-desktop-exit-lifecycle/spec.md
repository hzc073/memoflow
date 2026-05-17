## ADDED Requirements

### Requirement: Windows full exit uses graceful native window teardown

The system SHALL terminate the main Windows desktop window through the normal native close lifecycle when a user requests a full app exit. The primary full-exit path MUST NOT bypass `WM_CLOSE` / `WM_DESTROY` with direct `PostQuitMessage` semantics.

#### Scenario: Tray exit follows graceful teardown

- **GIVEN** the app is running as the primary Windows desktop instance
- **WHEN** the user chooses the tray menu exit action
- **THEN** the app SHALL enter the shared full-exit coordinator
- **AND** the coordinator SHALL disable close prevention before terminating the main window
- **AND** the main window SHALL be terminated through the normal close lifecycle rather than direct `PostQuitMessage`

#### Scenario: Window close can enter full exit

- **GIVEN** the app is running as the primary Windows desktop instance
- **AND** `windowsCloseToTray` is disabled
- **WHEN** the user closes the main window
- **THEN** the app SHALL enter the same full-exit coordinator used by tray exit
- **AND** the main window SHALL use the graceful native close lifecycle

#### Scenario: Flutter controller teardown precedes COM uninitialization

- **WHEN** Windows full exit terminates the main window
- **THEN** the native lifecycle SHALL allow `FlutterWindow::OnDestroy()` or an equivalent teardown hook to release the Flutter controller before process COM uninitialization

### Requirement: Close-to-tray remains non-destructive

When Windows close-to-tray is enabled, closing the main window SHALL hide the window to the tray instead of performing a full process exit.

#### Scenario: Window close hides to tray

- **GIVEN** the app is running as the primary Windows desktop instance
- **AND** `windowsCloseToTray` is enabled
- **WHEN** the user closes the main window
- **THEN** the app SHALL hide the main window to the tray
- **AND** the app SHALL NOT run the full-exit cleanup sequence
- **AND** the process SHALL remain available for tray restore

#### Scenario: Tray exit still exits when close-to-tray is enabled

- **GIVEN** the app is running as the primary Windows desktop instance
- **AND** `windowsCloseToTray` is enabled
- **WHEN** the user chooses the tray menu exit action
- **THEN** the app SHALL run the full-exit cleanup sequence
- **AND** the process SHALL terminate after graceful cleanup or fallback timeout

### Requirement: Full-exit cleanup is bounded and ordered

The Windows full-exit coordinator SHALL perform required cleanup in a bounded order and MUST NOT rely on Dart cleanup steps after the final process-termination signal has already been sent.

#### Scenario: Required cleanup happens before final main-window termination

- **WHEN** Windows full exit begins
- **THEN** sub-window close requests, hotkey unregister, tray disposal, and owned database/write cleanup SHALL be attempted before the final main-window termination step
- **AND** each cleanup step SHALL have a bounded timeout or be safe to skip during forced fallback

#### Scenario: Fallback remains active through complete exit

- **WHEN** Windows full exit begins
- **THEN** the force-exit fallback SHALL remain active until required cleanup and main-window termination either complete or time out
- **AND** the fallback SHALL NOT be cancelled before a later required cleanup step that can still hang

#### Scenario: Repeated exit requests are idempotent

- **GIVEN** Windows full exit is already in progress
- **WHEN** another tray, window, storage, legal, or update flow requests full exit
- **THEN** the app SHALL NOT start a second cleanup sequence
- **AND** the caller SHALL await or observe the existing exit operation

### Requirement: Exit suppresses new delayed sync work

Once Windows full exit begins, the app SHALL avoid scheduling new delayed WebDAV sync or backup work that can contend with shutdown.

#### Scenario: Settings-triggered WebDAV sync is ignored during exit

- **GIVEN** Windows full exit is in progress
- **WHEN** a settings change or pending callback requests `SyncRequestKind.webDavSync` with `SyncRequestReason.settings`
- **THEN** the app SHALL NOT schedule a new delayed WebDAV auto-sync timer
- **AND** any existing delayed WebDAV auto-sync timer SHALL be cancelled or ignored

#### Scenario: Exit-time sync suppression does not affect normal runtime

- **GIVEN** Windows full exit is not in progress
- **WHEN** a valid settings change requests WebDAV sync
- **THEN** the existing delayed WebDAV sync scheduling behavior SHALL remain unchanged

### Requirement: Desktop exit preserves architecture boundaries

The Windows desktop exit fix SHALL preserve current architecture boundaries and MUST NOT introduce new lower-layer dependencies on feature UI code.

#### Scenario: No new reverse dependencies are introduced

- **WHEN** the exit lifecycle fix is implemented
- **THEN** `state`, `application`, and `core` layers SHALL NOT add new imports from `features/*`
- **AND** reusable exit lifecycle logic SHALL remain owned by `application/desktop` or an injected composition-root seam

#### Scenario: Exit guardrails protect lifecycle semantics

- **WHEN** desktop exit tests are executed
- **THEN** they SHALL fail if the Windows primary full-exit termination action regresses to direct `destroy` / `PostQuitMessage` semantics
- **AND** they SHALL fail if required cleanup is placed after the final main-window termination signal without a bounded fallback
