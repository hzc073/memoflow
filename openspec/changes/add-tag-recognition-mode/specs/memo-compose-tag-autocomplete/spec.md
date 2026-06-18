## ADDED Requirements

### Requirement: Tag autocomplete follows recognition policy
Memo compose tag autocomplete SHALL only suggest tags for text positions that can become app-visible tags under the active `TagRecognitionPolicy`.

#### Scenario: Compatible policy suggests inline body tag
- **WHEN** active policy is `memosCompatible`
- **AND** a memo compose editor has a collapsed caret inside `今天记录 #生`
- **AND** matching tag suggestions exist
- **THEN** tag autocomplete SHALL be eligible to show suggestions for `生`

#### Scenario: Strict policy does not suggest body prose tag
- **WHEN** active policy is `memoflowStrict`
- **AND** a memo compose editor has a collapsed caret inside `今天记录 #生`
- **THEN** tag autocomplete MUST NOT show suggestions for that inline body prose position

#### Scenario: Strict policy suggests tag-zone prefix
- **WHEN** active policy is `memoflowStrict`
- **AND** a memo compose editor has a collapsed caret inside a first or last content line prefix such as `#生`
- **AND** matching tag suggestions exist
- **THEN** tag autocomplete SHALL be eligible to show suggestions

#### Scenario: Custom policy suggestions follow enabled options
- **WHEN** active policy is `custom`
- **AND** the policy disables ordinary inline body tags and enables first-line tag-zone prefixes
- **AND** a memo compose editor has a collapsed caret inside `今天记录 #生`
- **THEN** tag autocomplete MUST NOT show suggestions for that inline body prose position
- **WHEN** the same editor has a collapsed caret inside first-line prefix `#生`
- **THEN** tag autocomplete SHALL be eligible to show suggestions

#### Scenario: Applying suggestion preserves policy semantics
- **WHEN** the user applies a tag autocomplete suggestion
- **THEN** the inserted text SHALL remain in a form that can be recognized under the active policy
- **AND** applying a suggestion SHALL NOT cause a lower layer to import feature UI code
