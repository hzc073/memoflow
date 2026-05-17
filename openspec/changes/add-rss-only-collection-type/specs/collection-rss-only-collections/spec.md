## ADDED Requirements

### Requirement: RSS collections are a dedicated RSS-only collection type
The system SHALL support a dedicated RSS collection type that contains RSS feed sources and RSS articles only.

#### Scenario: RSS collection is created
- **GIVEN** the user chooses to create an RSS collection
- **WHEN** the collection is saved
- **THEN** the collection SHALL be stored with an RSS-specific collection type or equivalent durable type metadata
- **AND** the collection SHALL NOT store smart memo rules as active selection behavior
- **AND** the collection SHALL NOT store manual memo membership as active selection behavior

#### Scenario: RSS collection resolves content
- **GIVEN** an RSS collection has one or more subscribed feeds
- **WHEN** the collection dashboard, detail, or reader resolves content
- **THEN** it SHALL compose RSS article readable items from the collection's RSS sources
- **AND** it SHALL NOT include memo items unless an RSS article was explicitly saved and later appears elsewhere as a normal memo outside the RSS collection

#### Scenario: Manual memo flows list collection targets
- **GIVEN** RSS collections exist
- **WHEN** the user opens an add-to-collection or manual memo membership flow for a memo
- **THEN** RSS collections SHALL NOT be offered as manual memo targets

### Requirement: RSS collection creation supports multiple feeds
The system SHALL let users create an RSS collection by subscribing one or more RSS/Atom feeds during creation.

#### Scenario: User creates RSS collection with one feed
- **GIVEN** the user selected RSS collection creation
- **AND** the user enters a feed or site URL
- **WHEN** feed discovery and preview succeed
- **THEN** the user SHALL be able to create the RSS collection with that feed attached
- **AND** the collection title MAY be prefilled from the feed title when the title field is empty

#### Scenario: User creates RSS collection with multiple feeds
- **GIVEN** the user selected RSS collection creation
- **AND** the user has already previewed and added one feed to the draft RSS collection
- **WHEN** the user previews and adds another valid feed before saving
- **THEN** the saved RSS collection SHALL attach all selected feeds
- **AND** articles from all attached feeds SHALL be eligible for the collection's RSS article list

#### Scenario: User tries to save RSS collection without a feed
- **GIVEN** the user selected RSS collection creation
- **AND** no valid feed has been added
- **WHEN** the user tries to save the collection
- **THEN** the system SHALL prevent saving
- **AND** it SHALL show recoverable guidance to add at least one RSS/Atom feed

### Requirement: RSS collection UI presents RSS behavior distinctly
The system SHALL present RSS collections as RSS collections rather than as manual collections.

#### Scenario: RSS collection appears in collection list
- **GIVEN** an RSS collection exists
- **WHEN** the collection list or shelf is displayed
- **THEN** the collection SHALL use RSS-specific label, icon, or metadata
- **AND** it SHALL NOT be labeled as a manual collection

#### Scenario: User edits RSS collection
- **GIVEN** the user edits an RSS collection
- **WHEN** the edit surface is displayed
- **THEN** smart rule controls SHALL be hidden or disabled
- **AND** manual memo picker controls SHALL be hidden or disabled
- **AND** RSS source management SHALL be available

#### Scenario: RSS collection has no articles yet
- **GIVEN** an RSS collection exists with at least one feed
- **AND** no RSS articles have been fetched or parsed yet
- **WHEN** the detail or reader surface is displayed
- **THEN** the empty state SHALL focus on refreshing or managing RSS sources
- **AND** it SHALL NOT describe the collection as an empty manual memo collection

### Requirement: RSS article save-as-memo is visible and article-scoped
The system SHALL expose a visible save-as-memo shortcut for individual RSS articles while preserving explicit per-article behavior.

#### Scenario: User views an unsaved RSS article in the reader
- **GIVEN** the current reader item is an RSS article
- **AND** the article has no `saved_memo_uid`
- **WHEN** reader controls are visible
- **THEN** the system SHALL show a visible save-as-memo shortcut for the current article
- **AND** activating it SHALL save only the current RSS article as a memo

#### Scenario: User views a saved RSS article
- **GIVEN** the current RSS article has `saved_memo_uid`
- **WHEN** article actions or reader controls are visible
- **THEN** the system SHALL show saved state for that article
- **AND** it SHALL NOT create a duplicate memo when the user activates the saved-state shortcut

#### Scenario: User uses overflow actions
- **GIVEN** the current reader item is an RSS article
- **WHEN** the user opens overflow/current item actions
- **THEN** the existing RSS article save-as-memo action SHALL remain available as a fallback path

### Requirement: RSS-only collections preserve memo boundaries
The system SHALL preserve the RSS article and memo boundary for RSS-only collections.

#### Scenario: RSS article is saved as memo
- **GIVEN** an RSS article belongs to an RSS collection
- **WHEN** the user explicitly saves that article as a memo
- **THEN** the system SHALL create a normal memo through existing memo mutation seams
- **AND** the RSS article SHALL record the created memo uid as `saved_memo_uid`
- **AND** the RSS collection SHALL continue to contain the RSS article, not the created memo

#### Scenario: RSS collection refreshes
- **GIVEN** an RSS collection has one or more feeds
- **WHEN** RSS refresh stores new articles
- **THEN** new articles SHALL remain RSS-owned content
- **AND** no memo SHALL be created unless the user explicitly saves an individual article

### Requirement: RSS-only collection type preserves architecture boundaries
The RSS-only collection type SHALL use existing collection/RSS seams and SHALL NOT hide reusable RSS logic inside widgets.

#### Scenario: RSS collection creation previews feeds
- **WHEN** feed discovery, parsing, or preview is needed during RSS collection creation
- **THEN** reusable logic SHALL live in RSS application/data services
- **AND** collection widgets SHALL call state/repository seams rather than parsing or fetching feeds directly

#### Scenario: RSS collection type logic is added
- **WHEN** RSS collection type handling is implemented
- **THEN** lower layers such as `data`, `application`, `state`, and `core` SHALL NOT import `features/collections` widgets for RSS behavior
- **AND** files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api` SHALL NOT be changed
