## ADDED Requirements

### Requirement: Existing memo editor prompts before closing unsaved edits
When the user edits an existing sent memo and the editor contains unsaved changes, the app SHALL ask what to do before closing the editor. The choices MUST allow the user to continue editing, discard changes, or add the edit draft to Draft Box.

#### Scenario: Closing an edited sent memo asks for a decision
- **GIVEN** the user is editing an existing sent memo
- **AND** the editor content, visibility, location, or attachments differ from the original memo state
- **WHEN** the user attempts to close the editor through back, close, or Escape
- **THEN** the app displays a confirmation dialog with continue editing, discard changes, and add to Draft Box choices

#### Scenario: Closing an unchanged sent memo does not prompt
- **GIVEN** the user is editing an existing sent memo
- **AND** the editor state matches the original memo state
- **WHEN** the user attempts to close the editor
- **THEN** the editor closes without creating or updating a visible Draft Box entry

#### Scenario: Continue editing keeps the editor open
- **GIVEN** the unsaved-edit close confirmation is visible
- **WHEN** the user chooses to continue editing
- **THEN** the editor remains open
- **AND** no visible edit draft is created or updated

#### Scenario: Discard changes closes without keeping the edit draft
- **GIVEN** the unsaved-edit close confirmation is visible
- **WHEN** the user chooses to discard changes
- **THEN** the editor closes without applying those changes to the original memo
- **AND** any active visible edit draft for that editor session is removed or left absent

### Requirement: Sent memo edit drafts are visible Draft Box entries
When the user chooses to add unsaved edits for an existing sent memo to Draft Box, the system SHALL persist a visible edit draft bound to the original memo. Saving that draft later MUST update the original memo rather than create a new memo.

#### Scenario: Add unsaved sent memo edit to Draft Box
- **GIVEN** the user is editing an existing sent memo with unsaved changes
- **WHEN** the user chooses add to Draft Box from the close confirmation
- **THEN** the system saves a visible Draft Box entry marked as an edit draft
- **AND** the draft is bound to the original memo uid
- **AND** the editor closes without applying the changes to the original memo

#### Scenario: Edit draft preserves supported editor state
- **GIVEN** an existing sent memo edit contains changed content, visibility, location, removed existing attachments, or newly added pending attachments
- **WHEN** the user adds the edit to Draft Box
- **THEN** the edit draft stores the supported changed editor state needed to restore that edit session
- **AND** existing memo attachments are represented separately from pending local attachments

#### Scenario: One original memo has one edit draft
- **GIVEN** Draft Box already contains an edit draft bound to memo A
- **WHEN** the user edits memo A again and chooses add to Draft Box
- **THEN** the existing edit draft for memo A is updated
- **AND** Draft Box does not contain a second edit draft bound to memo A

#### Scenario: No memo menu action is added
- **WHEN** the memo card or memo detail action menu is shown
- **THEN** the menu does not expose a new add-to-Draft-Box action for sent memos

### Requirement: Restored sent memo edit drafts update their original memo
When the user opens an edit draft from Draft Box, the app SHALL open the existing memo editor for the bound original memo and restore the saved edit-draft state. Completing the save SHALL update that original memo and remove the edit draft.

#### Scenario: Open edit draft from Draft Box
- **GIVEN** Draft Box contains an edit draft bound to memo A
- **WHEN** the user selects that draft
- **THEN** the app opens the existing memo editor for memo A
- **AND** the editor restores the edit draft state

#### Scenario: Save restored edit draft
- **GIVEN** the user opened an edit draft bound to memo A from Draft Box
- **WHEN** the user saves the editor
- **THEN** the app updates memo A through the normal memo edit save path
- **AND** the app removes the edit draft from Draft Box
- **AND** the app does not create a new memo from the edit draft content

#### Scenario: Bound original memo is unavailable
- **GIVEN** Draft Box contains an edit draft bound to memo A
- **AND** memo A cannot be loaded
- **WHEN** the user selects that draft
- **THEN** the app does not open the create-note compose surface for that draft
- **AND** the edit draft remains available for deletion from Draft Box

### Requirement: Sent memo edit draft ownership preserves architecture boundaries
Sent memo edit draft persistence SHALL be owned by draft repository, mutation, and helper seams. Lower layers MUST NOT import memo feature presentation widgets to restore or route edit drafts.

#### Scenario: Repository owns edit draft writes
- **WHEN** an edit draft is saved, updated, or deleted
- **THEN** the write goes through `ComposeDraftRepository` and its mutation service
- **AND** feature widgets do not call `AppDatabase` draft write methods directly

#### Scenario: Shared edit draft mapping is not hidden in screen widgets
- **WHEN** edit draft snapshot construction or restoration logic is reused by memo editor and Draft Box routing
- **THEN** that mapping lives in a focused helper, repository, provider, or state-layer owner
- **AND** lower layers do not import `features/memos/memo_editor_screen.dart` or other feature presentation widgets
