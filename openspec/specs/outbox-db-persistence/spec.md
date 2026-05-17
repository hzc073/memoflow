# outbox-db-persistence Specification

## Purpose

Define the local SQLite outbox persistence contract so sync queue schema, migration, read, write, retry, quarantine, desktop write-proxy, and modular boundary behavior remains stable while table-specific persistence details live outside the monolithic `AppDatabase` implementation.

## Requirements

### Requirement: Outbox persistence preserves schema compatibility
The local outbox persistence layer SHALL preserve the existing `outbox` table contract, additive migration behavior, state codes, and payload storage semantics while moving table-specific SQLite details out of the monolithic `AppDatabase` implementation.

#### Scenario: New database creates compatible outbox table
- **WHEN** a new local database is created
- **THEN** the `outbox` table SHALL contain the existing columns for id, type, payload, state, attempts, last error, failure code, failure kind, retry time, quarantine time, and created time
- **AND** newly enqueued outbox rows SHALL use the existing pending state and payload JSON shape

#### Scenario: Legacy retry column migration remains compatible
- **WHEN** a database older than the retry-state migration is upgraded
- **THEN** legacy outbox state values SHALL be mapped to the current pending, retry, error, and done state contract exactly as before this extraction

#### Scenario: Legacy error-chain migration remains compatible
- **WHEN** a database containing legacy failed root outbox tasks is upgraded through the quarantine metadata migration
- **THEN** root failed tasks SHALL be migrated to the quarantined state with existing failure metadata semantics
- **AND** dependent active tasks for the same memo SHALL be quarantined as blocked by the root task

### Requirement: Outbox read behavior remains unchanged
The system SHALL preserve existing outbox read behavior while delegating outbox-specific queries and payload helpers to a focused data-layer persistence owner.

#### Scenario: Pending outbox listing preserves ordering and states
- **WHEN** callers list pending outbox rows
- **THEN** rows in pending, running, or retry state SHALL be returned in ascending id order
- **AND** the result row maps SHALL preserve the same columns and values as before the extraction

#### Scenario: Attention listing preserves derived fields
- **WHEN** callers list outbox attention rows
- **THEN** rows in quarantined or error state SHALL be returned in existing attention ordering
- **AND** each row SHALL keep the existing derived `memo_uid` and `occurred_at` fields when payload data supports them

#### Scenario: Memo-scoped lookup preserves payload matching
- **WHEN** callers list or detect outbox rows for a memo uid
- **THEN** the system SHALL inspect existing outbox payload shapes for create, update, delete, upload attachment, and delete attachment tasks
- **AND** it SHALL preserve existing type and state filters when matching rows

#### Scenario: Counts preserve active and attention semantics
- **WHEN** callers count pending, retryable, failed, quarantined, or attention outbox rows
- **THEN** each count SHALL use the same state set as before the persistence extraction

### Requirement: Outbox write state transitions remain unchanged
The system SHALL preserve existing outbox enqueue, claim, completion, retry, quarantine, deletion, and payload rewrite behavior while moving SQL primitives behind `AppDatabaseWriteDao`.

#### Scenario: Enqueue preserves payload and created order
- **WHEN** a single outbox item or batch of outbox items is enqueued
- **THEN** the inserted rows SHALL preserve the existing type, JSON payload, pending state, attempts, error metadata defaults, and created time behavior
- **AND** batch insertion SHALL preserve local insertion order

#### Scenario: Claim preserves runnable predicates
- **WHEN** a sync worker claims an outbox task by id or claims the next runnable task
- **THEN** only pending tasks or due retry tasks SHALL transition to running
- **AND** non-due retry, error, quarantined, done, or missing tasks SHALL NOT be claimed

#### Scenario: Completion preserves deletion behavior
- **WHEN** an outbox task is completed through the existing completion path
- **THEN** the task SHALL be marked done and removed according to the current behavior
- **AND** data-change notifications SHALL still fire from the write owner

#### Scenario: Retry and quarantine metadata remains stable
- **WHEN** a task is marked error, scheduled for retry, retried, or quarantined
- **THEN** state, attempts, retry time, last error, failure code, failure kind, and quarantine time SHALL be updated with the same semantics as before this extraction

#### Scenario: Memo uid rewrites preserve outbox payload semantics
- **WHEN** a local memo uid is renamed or remote sync rewrites queued payloads from an old uid to a new uid
- **THEN** supported outbox payloads SHALL be rewritten in place without changing unrelated payload fields
- **AND** the changed row count SHALL preserve the existing meaning

#### Scenario: Memo-scoped delete preserves active states
- **WHEN** callers delete outbox rows for a memo uid
- **THEN** only rows matching the existing active/attention state set and supported memo uid payload shapes SHALL be removed

### Requirement: AppDatabase facade and desktop write proxy remain stable
The extraction SHALL keep `AppDatabase` as the public facade and desktop write-proxy dispatcher for outbox operations.

#### Scenario: Public AppDatabase outbox methods remain available
- **WHEN** existing callers use `AppDatabase` outbox methods for enqueue, list, count, claim, mark, retry, delete, clear, rewrite, or pending memo uid lookup
- **THEN** those methods SHALL remain available with compatible signatures and return values

#### Scenario: Desktop write operations preserve operation names
- **WHEN** outbox writes run through the desktop write-proxy configuration
- **THEN** existing write command operation names and payload keys SHALL remain unchanged
- **AND** local envelope execution SHALL continue to route to the same public facade methods

#### Scenario: Write notifications remain owned by write owners
- **WHEN** outbox write operations mutate local state
- **THEN** data-change notifications SHALL continue to be emitted by `AppDatabase` or `AppDatabaseWriteDao` owner paths as before
- **AND** the extracted persistence helper SHALL NOT own UI or provider notification policy

### Requirement: Outbox persistence preserves modular boundaries
Outbox persistence extraction SHALL improve data-layer ownership without introducing new reverse dependencies or broadening transaction ownership.

#### Scenario: Persistence seam has no upward imports
- **WHEN** architecture guardrail tests inspect outbox DB persistence files under `lib/data/db`
- **THEN** those files SHALL NOT import `features/`, `state/`, or `application/`

#### Scenario: Transaction ownership does not expand
- **WHEN** architecture guardrail tests inspect direct `.transaction(` usage
- **THEN** this change SHALL NOT require adding the outbox persistence file to the direct transaction allowlist
- **AND** transaction boundaries SHALL remain in existing write-owner paths

#### Scenario: AppDatabase does not re-own outbox SQLite details
- **WHEN** architecture guardrail tests inspect `AppDatabase`
- **THEN** `AppDatabase` SHALL NOT directly contain outbox table creation SQL, outbox payload decode helpers, or outbox state transition SQL after extraction
- **AND** it MAY continue to expose public outbox facade methods, desktop write-proxy dispatch, and public outbox state constants

#### Scenario: No new reverse dependencies are introduced
- **WHEN** outbox persistence extraction is implemented during `evolve_modularity`
- **THEN** it MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` imports
