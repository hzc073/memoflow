## ADDED Requirements

### Requirement: Abnormal tag cleanup follows active recognition mode
The abnormal tag cleanup operation SHALL recompute local derived memo tags using the active workspace `TagRecognitionMode`.

#### Scenario: Strict cleanup removes inline-only derived tags
- **WHEN** active mode is `memoflowStrict`
- **AND** an existing memo has a persisted local tag that appears only as ordinary body prose such as `今天记录 #生活`
- **AND** the user confirms abnormal tag cleanup or mode-switch recompute
- **THEN** the local `生活` tag relationship MUST be removed from that memo
- **AND** redundant `memos.tags`, search data, and tag statistics MUST no longer expose `生活` for that memo after repair-dependent refresh completes

#### Scenario: Compatible cleanup keeps inline tags
- **WHEN** active mode is `memosCompatible`
- **AND** an existing memo contains ordinary body prose such as `今天记录 #生活`
- **AND** the user confirms abnormal tag cleanup or mode-switch recompute
- **THEN** the local `生活` tag relationship SHALL be present for that memo
- **AND** redundant `memos.tags`, search data, and tag statistics SHALL reflect that tag after repair-dependent refresh completes

#### Scenario: Cleanup explains active mode
- **WHEN** the abnormal tag cleanup or mode-switch recompute confirmation is shown
- **THEN** the confirmation SHALL explain that tags will be rebuilt using the current tag recognition rule
- **AND** it SHALL warn that stored tags not visible under that rule may be removed from local derived data

### Requirement: Mode-switch recompute reuses safe self-repair maintenance
The mode-switch recompute action SHALL use the same safe local maintenance ownership as self-repair instead of embedding database mutation logic in settings UI.

#### Scenario: Settings UI starts recompute through maintenance seam
- **WHEN** the user confirms recompute after changing tag recognition mode
- **THEN** settings UI SHALL call a state/application maintenance seam
- **AND** it MUST NOT directly call focused DB persistence helpers or manually duplicate tag, search, stats, and orphan pruning sequences

#### Scenario: Mode-switch recompute preserves user content
- **WHEN** mode-switch recompute runs
- **THEN** memo content, attachments, accounts, preferences, local library source files, WebDAV backups, pending sync queues, and remote server data SHALL NOT be deleted or edited by that action
