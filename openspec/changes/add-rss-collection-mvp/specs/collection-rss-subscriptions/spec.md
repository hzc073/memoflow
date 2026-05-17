## ADDED Requirements

### Requirement: Collections support RSS feed sources
The system SHALL allow a collection to include RSS feed sources while preserving existing smart and manual memo collection behavior.

#### Scenario: RSS feed is attached to a collection
- **GIVEN** a collection exists
- **AND** a valid RSS or Atom feed has been discovered or parsed
- **WHEN** the user subscribes the collection to that feed
- **THEN** the feed SHALL be stored as an RSS source for that collection
- **AND** existing smart or manual memo rules SHALL remain unchanged
- **AND** RSS articles from that feed SHALL NOT be inserted into `memos` automatically

#### Scenario: Existing memo-only collection is loaded
- **GIVEN** a collection has no RSS sources
- **WHEN** the collection dashboard, detail, or reader is loaded
- **THEN** it SHALL continue resolving its memo items according to its existing smart or manual configuration

### Requirement: RSS subscription discovery is explicit and previewed
The system SHALL let the user enter a feed or site URL, discover or parse the feed, and review feed metadata before attaching it to a collection.

#### Scenario: User enters direct feed URL
- **GIVEN** the user enters a direct RSS or Atom feed URL
- **WHEN** the system fetches and parses the URL successfully
- **THEN** the system SHALL show the feed title, source URL, site URL when available, icon when available, and a small article preview
- **AND** the user SHALL be able to confirm the subscription for the selected collection

#### Scenario: User enters site URL with alternate feed link
- **GIVEN** the user enters an HTML site URL
- **AND** the page advertises an alternate RSS or Atom feed link
- **WHEN** discovery succeeds
- **THEN** the system SHALL use the discovered feed URL for subscription preview

#### Scenario: Feed discovery fails
- **GIVEN** the user enters a URL that cannot be parsed as a feed and does not advertise a supported feed
- **WHEN** discovery finishes
- **THEN** the system SHALL show a recoverable error
- **AND** no subscription SHALL be created

### Requirement: RSS feeds refresh manually in the MVP
The MVP SHALL support user-initiated RSS feed refresh and SHALL NOT require background scheduling.

#### Scenario: User refreshes a subscribed feed
- **GIVEN** a collection has a subscribed RSS feed
- **WHEN** the user triggers refresh for the feed or collection
- **THEN** the system SHALL fetch the feed
- **AND** new feed entries SHALL be stored as RSS articles
- **AND** existing RSS articles SHALL be deduplicated by stable feed article identity such as `guid` or `link`
- **AND** local article state such as read/unread and `saved_memo_uid` SHALL be preserved

#### Scenario: Manual refresh fails
- **GIVEN** a subscribed feed cannot be fetched or parsed
- **WHEN** the user triggers refresh
- **THEN** the feed SHALL record failure metadata
- **AND** existing articles SHALL remain available
- **AND** the collection SHALL show recoverable refresh feedback

### Requirement: RSS articles are independent collection reading items
The system SHALL render RSS articles in collection reading surfaces without converting them to `LocalMemo`.

#### Scenario: Collection contains memo and RSS content
- **GIVEN** a collection resolves both memo items and RSS articles
- **WHEN** the collection detail or reader is rendered
- **THEN** the system SHALL display both item kinds through a collection readable-item seam
- **AND** memo-only actions such as edit memo, pin memo, or memo sync retry SHALL NOT be offered for RSS article items
- **AND** RSS article actions such as mark read/unread, open original, and save as memo MAY be offered for RSS article items

#### Scenario: RSS article is read
- **GIVEN** an RSS article is unread
- **WHEN** the user opens or marks the article as read
- **THEN** the article read state SHALL be updated in RSS-owned storage
- **AND** no memo state SHALL be changed

### Requirement: RSS article saving creates memos only on explicit action
The system SHALL create a memo from an RSS article only when the user explicitly chooses to save the article as a memo.

#### Scenario: User saves RSS article as memo
- **GIVEN** an RSS article exists in a collection
- **WHEN** the user activates save-as-memo for that article
- **THEN** the system SHALL create a normal memo through existing memo creation or mutation seams
- **AND** the memo SHALL include source attribution and original article link
- **AND** the RSS article SHALL store the created memo uid as `saved_memo_uid`

#### Scenario: User reads RSS article without saving
- **GIVEN** an RSS article exists in a collection
- **WHEN** the user reads, marks read, or opens the original article
- **THEN** no memo SHALL be created

### Requirement: RSS MVP preserves architecture boundaries
The RSS collection MVP SHALL use owned data/application/state seams and SHALL NOT hide reusable RSS domain logic inside screen or widget files.

#### Scenario: RSS persistence is added
- **WHEN** RSS tables, schema helpers, or SQLite primitives are introduced
- **THEN** they SHALL live in focused data-layer persistence/repository owners
- **AND** `AppDatabase` SHALL NOT re-own RSS schema SQL beyond invoking focused persistence setup

#### Scenario: RSS parsing or fetching is added
- **WHEN** RSS discovery, parsing, or fetching behavior is implemented
- **THEN** reusable parsing/fetching logic SHALL live outside collection screen widgets
- **AND** lower layers such as `data`, `application`, `state`, and `core` SHALL NOT import `features/collections` or `features/share` UI modules for RSS behavior

#### Scenario: API compatibility is preserved
- **WHEN** the RSS collection MVP is implemented
- **THEN** request/response models, route adapters, version compatibility logic, and files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api` SHALL NOT be changed
