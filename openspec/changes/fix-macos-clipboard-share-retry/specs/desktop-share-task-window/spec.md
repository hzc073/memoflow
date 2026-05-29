## MODIFIED Requirements

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
