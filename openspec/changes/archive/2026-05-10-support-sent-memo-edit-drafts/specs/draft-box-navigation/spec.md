## MODIFIED Requirements

### Requirement: Navigation-launched Draft Box opens selected drafts for editing
When Draft Box is opened from app navigation, selecting a draft SHALL open the appropriate editor for that draft type. Create drafts SHALL open the note input editor with that create draft restored. Sent memo edit drafts SHALL open the existing memo editor for the bound original memo with the edit draft restored.

#### Scenario: Sidebar Draft Box selection opens create draft editor
- **GIVEN** the user opens Draft Box from the sidebar
- **AND** draft A is a create draft
- **WHEN** the user taps draft A
- **THEN** the app opens the note input editor
- **AND** the editor restores draft A for editing

#### Scenario: Sidebar Draft Box selection opens sent memo edit draft editor
- **GIVEN** the user opens Draft Box from the sidebar
- **AND** draft A is an edit draft bound to an existing sent memo
- **WHEN** the user taps draft A
- **THEN** the app opens the existing memo editor for the bound memo
- **AND** the editor restores draft A for editing

#### Scenario: Bottom navigation Draft Box selection opens create draft editor
- **GIVEN** the user opens Draft Box from a bottom navigation destination
- **AND** draft A is a create draft
- **WHEN** the user taps draft A
- **THEN** the app opens the note input editor
- **AND** the editor restores draft A for editing

#### Scenario: Bottom navigation Draft Box selection opens sent memo edit draft editor
- **GIVEN** the user opens Draft Box from a bottom navigation destination
- **AND** draft A is an edit draft bound to an existing sent memo
- **WHEN** the user taps draft A
- **THEN** the app opens the existing memo editor for the bound memo
- **AND** the editor restores draft A for editing

#### Scenario: Navigation Draft Box refreshes after create draft editor close
- **GIVEN** the user opens Draft Box from app navigation
- **AND** the user taps create draft A and edits its content
- **WHEN** the user exits the note input editor without submitting
- **THEN** Draft Box displays draft A with the latest saved draft content
- **AND** the user does not need to leave and re-enter Draft Box to see the update

#### Scenario: Navigation Draft Box refreshes after edit draft editor close
- **GIVEN** the user opens Draft Box from app navigation
- **AND** the user taps edit draft A and edits its content
- **WHEN** the user exits the existing memo editor by adding the edit to Draft Box again
- **THEN** Draft Box displays draft A with the latest saved edit draft content
- **AND** Draft Box does not create a duplicate edit draft for the same original memo

#### Scenario: Empty Draft Box remains viewable from navigation
- **GIVEN** the user opens Draft Box from app navigation
- **WHEN** there are no saved drafts
- **THEN** the app displays the existing empty Draft Box state
- **AND** no note input editor or memo editor is opened automatically

### Requirement: Draft Box navigation preserves architecture boundaries
Draft Box navigation SHALL use existing navigation registry, preference provider, typed draft selection, and editor restoration seams. It MUST NOT introduce new reverse dependencies from `state` to `features`, from `application` to `features`, or from `core` to higher layers.

#### Scenario: Navigation uses destination registry seams
- **WHEN** Draft Box is added to sidebar and bottom navigation
- **THEN** the implementation routes through the existing drawer and home root destination seams
- **AND** destination metadata remains centralized with the other home root destinations

#### Scenario: Create draft restoration remains owned by note input
- **WHEN** a navigation-launched Draft Box returns a selected create draft
- **THEN** navigation code delegates create draft restoration to the note input entry point
- **AND** navigation code does not duplicate `ComposeDraftSnapshot` restoration logic for create drafts

#### Scenario: Edit draft restoration remains owned by memo editor draft seams
- **WHEN** a navigation-launched Draft Box returns a selected sent memo edit draft
- **THEN** navigation code delegates edit draft restoration to the existing memo editor entry point and edit draft helper seams
- **AND** lower layers do not import Draft Box or memo editor presentation widgets to perform routing
