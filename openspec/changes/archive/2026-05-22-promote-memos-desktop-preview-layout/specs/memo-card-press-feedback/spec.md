## MODIFIED Requirements

### Requirement: Memo card interactions remain unchanged

The memo list card press feedback SHALL preserve the existing memo card interaction semantics.

#### Scenario: Desktop memo card tap can open preview pane
- **WHEN** a user taps a memo card in a desktop layout that supports the preview pane
- **THEN** the tap MUST select the memo and open or update the preview pane
- **AND** desktop preview interaction MUST NOT be limited to Windows when the target platform otherwise supports the shared desktop preview layout
