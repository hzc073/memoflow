## ADDED Requirements

### Requirement: Tag autocomplete follows recognition mode
Memo compose tag autocomplete SHALL only suggest tags for text positions that can become app-visible tags under the active `TagRecognitionMode`.

#### Scenario: Compatible mode suggests inline body tag
- **WHEN** active mode is `memosCompatible`
- **AND** a memo compose editor has a collapsed caret inside `今天记录 #生`
- **AND** matching tag suggestions exist
- **THEN** tag autocomplete SHALL be eligible to show suggestions for `生`

#### Scenario: Strict mode does not suggest body prose tag
- **WHEN** active mode is `memoflowStrict`
- **AND** a memo compose editor has a collapsed caret inside `今天记录 #生`
- **THEN** tag autocomplete MUST NOT show suggestions for that inline body prose position

#### Scenario: Strict mode suggests tag-zone prefix
- **WHEN** active mode is `memoflowStrict`
- **AND** a memo compose editor has a collapsed caret inside a first or last content line prefix such as `#生`
- **AND** matching tag suggestions exist
- **THEN** tag autocomplete SHALL be eligible to show suggestions

#### Scenario: Applying suggestion preserves mode semantics
- **WHEN** the user applies a tag autocomplete suggestion
- **THEN** the inserted text SHALL remain in a form that can be recognized under the active mode
- **AND** applying a suggestion SHALL NOT cause a lower layer to import feature UI code
