# memo-compose-tag-autocomplete Specification

## Purpose
TBD - created by archiving change fix-tag-autocomplete-overlay-picker-lifecycle. Update Purpose after archive.
## Requirements

### Requirement: Tag autocomplete overlay follows editor lifecycle

Memo compose tag autocomplete SHALL remove any root overlay suggestion entry when the owning editor is no longer in an active autocomplete lifecycle.

#### Scenario: Suggestions disappear on focus loss

- **GIVEN** a memo compose editor has focus
- **AND** the collapsed caret is inside an active tag query with at least one suggestion
- **AND** the tag autocomplete suggestion panel is visible
- **WHEN** the owning editor focus is lost
- **THEN** the suggestion panel SHALL be removed from the root overlay
- **AND** no stale tag suggestion panel SHALL remain visible above the app or a platform/plugin surface

#### Scenario: Suggestions disappear when suggestions become empty

- **GIVEN** a memo compose editor has a visible tag autocomplete suggestion panel
- **WHEN** the active tag query no longer exists or produces no suggestions
- **THEN** the suggestion panel SHALL be removed from the root overlay

#### Scenario: Widget disposal removes root overlay entry

- **GIVEN** a tag autocomplete overlay has inserted a root `OverlayEntry`
- **WHEN** the owning compose surface is disposed or no longer builds the overlay widget
- **THEN** the root `OverlayEntry` SHALL be removed.

### Requirement: External picker launch dismisses autocomplete

Memo compose surfaces SHALL leave tag autocomplete inactive before launching external picker flows.

#### Scenario: Memo editor gallery picker hides tag suggestions

- **GIVEN** `MemoEditorScreen` is editing a memo whose current caret position activates tag autocomplete suggestions
- **AND** the tag suggestion panel is visible
- **WHEN** the user taps the gallery/photo picker toolbar action
- **THEN** the editor SHALL dismiss tag autocomplete before or as the picker launch begins
- **AND** the tag suggestion panel SHALL NOT remain visible while the Android photo picker or equivalent platform picker is open
- **AND** returning from the picker SHALL NOT automatically reopen tag suggestions unless the user resumes editing in an active tag query

#### Scenario: Other attachment pickers hide tag suggestions

- **GIVEN** a memo compose surface has visible tag autocomplete suggestions
- **WHEN** the user launches a file picker or camera capture flow from the compose toolbar
- **THEN** the compose surface SHALL dismiss tag autocomplete before or as the external picker/capture flow begins
- **AND** the picker/capture result handling SHALL NOT automatically refocus the editor solely to restore tag suggestions

### Requirement: Tag autocomplete behavior remains unchanged while editing

The autocomplete lifecycle fix SHALL preserve existing tag suggestion behavior during normal text editing.

#### Scenario: Focused editor still shows suggestions

- **GIVEN** a memo compose editor remains focused
- **AND** the collapsed caret is inside an active tag query
- **AND** matching tags exist
- **WHEN** the editor value changes through typing
- **THEN** suggestions SHALL continue to rank and render according to the existing tag autocomplete rules

#### Scenario: Applying a suggestion still inserts the selected tag

- **GIVEN** a visible tag autocomplete suggestion panel
- **WHEN** the user applies a suggestion through keyboard selection or panel selection
- **THEN** the selected tag SHALL replace the active tag query
- **AND** the editor caret SHALL move after the inserted tag text
- **AND** the editor MAY regain focus as part of the existing apply-suggestion behavior

### Requirement: Tag autocomplete lifecycle preserves modularity boundaries

The tag autocomplete lifecycle fix SHALL remain inside existing feature UI and state helper boundaries.

#### Scenario: No upward dependency is introduced

- **WHEN** tag autocomplete lifecycle behavior is implemented
- **THEN** lower layers such as `state`, `application`, and `core` SHALL NOT import `features/memos/tag_autocomplete.dart` or compose screen widgets
- **AND** no architecture allowlist SHALL be expanded for this change

#### Scenario: No API compatibility behavior is changed

- **WHEN** tag autocomplete lifecycle behavior is implemented
- **THEN** API request/response models, route adapters, server-version compatibility logic, and files under `memos_flutter_app/lib/data/api` SHALL remain unchanged
