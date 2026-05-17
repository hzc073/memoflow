## ADDED Requirements

### Requirement: Collection detail supports selectable reading experiences
The system SHALL support collection-scoped reading experiences so a collection can open either an article-flow reader or the existing continuous reader.

#### Scenario: RSS collection opens article flow by default
- **GIVEN** an RSS collection has no saved reading experience override
- **WHEN** the user opens that collection detail
- **THEN** the system SHALL open the article-flow reader by default

#### Scenario: Smart or manual collection opens continuous reader by default
- **GIVEN** a smart or manual collection has no saved reading experience override
- **WHEN** the user opens that collection detail
- **THEN** the system SHALL open the existing continuous reader by default

#### Scenario: User switches reading experience
- **GIVEN** a collection supports more than one reading experience
- **WHEN** the user switches between article flow and continuous reader
- **THEN** the system SHALL persist the selected reading experience for that collection
- **AND** subsequent opens of that collection SHALL use the saved reading experience

#### Scenario: RSS collection uses continuous reader by choice
- **GIVEN** an RSS collection has been switched to continuous reader
- **WHEN** the collection is opened
- **THEN** the system SHALL render RSS articles in the existing continuous reader
- **AND** RSS articles SHALL remain RSS-owned content unless explicitly saved as memos

### Requirement: RSS article flow presents filterable article lists
The article-flow reader SHALL present collection items as a filterable article list, with RSS-specific metadata for RSS articles.

#### Scenario: RSS article row is displayed
- **GIVEN** an RSS article belongs to the opened collection
- **WHEN** the article appears in article flow
- **THEN** the row SHALL show available feed icon, feed name, article title, excerpt, display time, thumbnail, unread state, and saved state according to display settings

#### Scenario: User filters RSS articles by status
- **GIVEN** an RSS collection has read, unread, and saved articles
- **WHEN** the user selects all, unread, read, or saved filter
- **THEN** the article list SHALL show only items matching the selected filter

#### Scenario: User filters RSS articles by feed
- **GIVEN** an RSS collection has articles from multiple feeds
- **WHEN** the user selects a specific feed filter
- **THEN** the article list SHALL show only articles from that feed

#### Scenario: User filters or groups RSS articles by date
- **GIVEN** an RSS collection has articles across multiple dates
- **WHEN** date grouping or date filtering is enabled
- **THEN** the article list SHALL organize or filter articles by their effective display time

#### Scenario: Memo collection uses article-flow mode
- **GIVEN** a smart or manual memo collection is switched to article-flow mode
- **WHEN** the article-flow list is displayed
- **THEN** memo items MAY be shown in a list/detail article-flow layout
- **AND** RSS-only actions such as full-content fetch or save-as-memo SHALL NOT be shown for memo items

### Requirement: Article flow supports first-pass list actions
The article-flow reader SHALL provide efficient built-in actions for RSS article triage while keeping custom swipe mapping out of the first implementation.

#### Scenario: User swipes an RSS article row
- **GIVEN** an RSS article row is visible
- **WHEN** the user performs a supported swipe action
- **THEN** the system SHALL perform a built-in action such as toggling read/unread or saving the article as a memo
- **AND** the action SHALL apply only to that article

#### Scenario: User marks articles above as read
- **GIVEN** an RSS article row is selected from a filtered list
- **WHEN** the user chooses mark-above-as-read
- **THEN** the system SHALL mark only eligible RSS articles above that row in the current list as read

#### Scenario: User marks articles below as read
- **GIVEN** an RSS article row is selected from a filtered list
- **WHEN** the user chooses mark-below-as-read
- **THEN** the system SHALL mark only eligible RSS articles below that row in the current list as read

### Requirement: Single RSS article reading supports RSS-specific actions
The article-flow reader SHALL provide a single-article reading surface for RSS articles with top and bottom controls aligned to RSS reading behavior.

#### Scenario: User opens an RSS article
- **GIVEN** an RSS article is unread
- **WHEN** the user opens the article from article flow
- **THEN** the system SHALL mark that article read immediately
- **AND** the article body SHALL display the best available readable content

#### Scenario: User uses top article actions
- **GIVEN** an RSS article detail is open
- **WHEN** the top controls are visible
- **THEN** the system SHALL provide back or close navigation
- **AND** it SHALL provide share and open-original actions when source data is available
- **AND** it SHALL NOT provide a style-editing entry in this change

#### Scenario: User uses bottom article actions
- **GIVEN** an RSS article detail is open
- **WHEN** the bottom controls are visible
- **THEN** the system SHALL provide read/unread toggle, save-as-memo, next article, and full-content fetch or retry actions as applicable
- **AND** it SHALL NOT provide text-to-speech in this change

#### Scenario: User moves to next article
- **GIVEN** an RSS article detail is open from a filtered article list
- **WHEN** the user activates next article
- **THEN** the system SHALL open the next article in the current filtered list
- **AND** it SHALL NOT skip ahead to unread-only items unless the current filter already restricts the list to unread items

#### Scenario: Full-content fetch fails or is skipped
- **GIVEN** an RSS article has feed-provided fallback content
- **WHEN** full-content fetch fails or is skipped
- **THEN** the detail reader SHALL continue showing fallback content
- **AND** it SHALL expose recoverable status with retry when eligible
- **AND** it SHALL allow opening the original link when available

### Requirement: Article-flow layout adapts to device width
The article-flow reader SHALL adapt between mobile single-pane navigation and wider list-detail reading.

#### Scenario: User opens article flow on mobile
- **GIVEN** the viewport is single-pane
- **WHEN** the user taps an article row
- **THEN** the system SHALL navigate to a single-article detail surface

#### Scenario: User opens article flow on tablet or desktop
- **GIVEN** the viewport supports a two-pane layout
- **WHEN** article flow is displayed
- **THEN** the system SHALL show article list and selected article detail side by side
- **AND** selecting a different row SHALL update the detail pane

### Requirement: Article-flow display and progress are collection-scoped
The system SHALL store article-flow display settings and progress separately from continuous reader progress.

#### Scenario: User changes article-flow display settings
- **GIVEN** article flow is open for a collection
- **WHEN** the user changes excerpt, thumbnail, feed icon, density, or auto-hide toolbar settings
- **THEN** the system SHALL persist those settings for that collection

#### Scenario: Article toolbar auto-hides
- **GIVEN** auto-hide toolbar is enabled for article detail
- **WHEN** the user scrolls down while reading
- **THEN** article controls MAY hide to prioritize content
- **AND** controls SHALL become reachable again through normal scroll or interaction behavior

#### Scenario: User switches between reading experiences
- **GIVEN** a collection has article-flow progress and continuous-reader progress
- **WHEN** the user switches reading experiences
- **THEN** article-flow filter, selected item, and list scroll progress SHALL NOT overwrite continuous-reader page or scroll progress
- **AND** continuous-reader progress SHALL NOT overwrite article-flow progress

### Requirement: Article-flow reader preserves RSS and memo boundaries
The article-flow reader SHALL preserve existing RSS-owned article state and explicit memo creation boundaries.

#### Scenario: RSS article is saved from article detail
- **GIVEN** an RSS article detail is open
- **WHEN** the user explicitly saves the article as a memo
- **THEN** the system SHALL create a normal memo through approved memo mutation seams
- **AND** it SHALL record the saved memo uid on the RSS article
- **AND** it SHALL NOT save any other article in the collection

#### Scenario: RSS article is opened but not saved
- **GIVEN** an RSS article detail is opened
- **WHEN** the system marks the article read
- **THEN** it SHALL NOT create a memo
- **AND** it SHALL NOT sync the RSS article to the Memos server as a memo

#### Scenario: Saved RSS article is saved again
- **GIVEN** an RSS article already has `saved_memo_uid`
- **WHEN** the user activates the saved/save-as-memo control again
- **THEN** the system SHALL NOT create a duplicate memo

### Requirement: Article-flow implementation preserves architecture boundaries
The article-flow change SHALL keep reusable RSS and reading-experience logic outside lower-layer/UI dependency violations.

#### Scenario: Article-flow state and actions are implemented
- **WHEN** article-flow state, filtering, action availability, or reading-experience routing is implemented
- **THEN** lower layers such as `data`, `application`, `state`, and `core` SHALL NOT import article-flow widgets or collection screen implementations
- **AND** reusable logic SHALL be placed in model, state, repository, service, or feature-local pure helpers according to dependency needs

#### Scenario: RSS fetch and parser logic is reused
- **WHEN** RSS article flow needs feed/article/full-content state
- **THEN** it SHALL use existing RSS repository/application seams
- **AND** RSS parser, fetcher, extraction, or sanitization logic SHALL NOT be implemented inside article-flow widgets

#### Scenario: Public RSS flow is implemented
- **WHEN** article-flow code is added to the public app shell
- **THEN** it SHALL NOT introduce subscription, billing, entitlement, receipt, paywall, StoreKit, or other commercial/private-extension logic
- **AND** it SHALL NOT add commercial state to shared public models

#### Scenario: API compatibility area remains untouched
- **WHEN** this change is implemented
- **THEN** files under `memos_flutter_app/lib/data/api` and `memos_flutter_app/test/data/api` SHALL NOT be changed unless the user gives separate explicit approval
