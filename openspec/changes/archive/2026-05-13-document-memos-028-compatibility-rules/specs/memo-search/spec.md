## ADDED Requirements

### Requirement: Remote search ordering honors active server capabilities
The system SHALL choose remote `ListMemos.order_by` fields according to the active Memos server version capabilities while preserving app-visible memo search semantics.

#### Scenario: Memos 0.28 search fallback uses supported ordering
- **WHEN** remote-backed memo search falls back to `ListMemos` against a Memos `0.28.x` server
- **THEN** the request SHALL use an order field supported by Memos `0.28.x`
- **AND** the request SHALL NOT use `display_time desc`

#### Scenario: Older server search behavior is preserved
- **WHEN** remote-backed memo search runs against a Memos `0.21` through `0.27` server
- **THEN** the request ordering SHALL preserve the existing behavior for that version unless another compatibility rule explicitly changes it

#### Scenario: Visible search filtering remains local-normalized
- **WHEN** remote search returns candidates using a version-compatible order field
- **THEN** the system MUST still apply the existing local verification, state, tag, date-range, advanced-filter, and result-limit constraints before showing results

#### Scenario: Ordering compatibility is covered by tests
- **WHEN** memo search compatibility tests cover Memos `0.28.x`
- **THEN** they MUST fail if remote search fallback sends `display_time desc`
