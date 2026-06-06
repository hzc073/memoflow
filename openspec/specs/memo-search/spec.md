## Purpose

Define app-visible memo search semantics so local, cached, and remote-backed search surfaces apply consistent literal substring behavior while preserving existing non-text filters.
## Requirements
### Requirement: Plain search matches memo content substrings
The system SHALL treat a non-empty plain memo search query as a literal continuous substring query against memo content after trimming surrounding whitespace.

#### Scenario: CJK middle substring matches
- **GIVEN** a memo content is `在秩序中安顿`
- **WHEN** the user searches for `秩序`
- **THEN** the memo appears in the search results.

#### Scenario: CJK prefix still matches
- **GIVEN** a memo content is `在秩序中安顿`
- **WHEN** the user searches for `在` or `在秩序`
- **THEN** the memo appears in the search results.

#### Scenario: Non-matching fragment is excluded
- **GIVEN** a memo content is `在秩序中安顿`
- **WHEN** the user searches for a fragment that does not occur in the memo content
- **THEN** the memo does not appear in the search results.

#### Scenario: Query text is literal
- **GIVEN** a memo content contains characters that could have special meaning in `SQL`, `SQLite FTS`, or server filter syntax
- **WHEN** the user searches for those characters as plain text
- **THEN** the system matches them as literal query text and MUST NOT execute them as operators or wildcards.

### Requirement: Search behavior is consistent across memo search surfaces
The system SHALL apply the same plain-text memo content matching semantics to main memo search, local/offline search, shortcut search, quick search, and link-memo lookup.

#### Scenario: Same query across surfaces
- **GIVEN** a memo content matches a plain search query by substring
- **WHEN** the same query is used in main search, local/offline search, shortcut search, quick search, and link-memo lookup
- **THEN** each surface includes the memo when all non-text filters for that surface also match.

#### Scenario: Shortcut and quick filters remain additional constraints
- **GIVEN** a memo content matches the plain search query
- **WHEN** a shortcut filter or quick-search predicate is also active
- **THEN** the memo appears only if it satisfies both the plain substring query and the active shortcut or quick-search predicate.

### Requirement: Search preserves existing non-text filters
The system SHALL preserve state, tag, creator, date range, advanced filter, pinning, ordering, and result-limit behavior when adding substring matching.

#### Scenario: State filter remains enforced
- **GIVEN** a memo content matches the plain search query
- **WHEN** the memo state does not match the active state filter
- **THEN** the memo does not appear in the search results.

#### Scenario: Tag filter remains enforced
- **GIVEN** a memo content matches the plain search query
- **WHEN** the memo tags do not match the active tag filter
- **THEN** the memo does not appear in the search results.

#### Scenario: Date range filter remains enforced
- **GIVEN** a memo content matches the plain search query
- **WHEN** the memo display/create time falls outside the active date range
- **THEN** the memo does not appear in the search results.

### Requirement: Remote search differences are normalized for visible results
The system SHALL NOT rely on server token-prefix behavior as the sole source of truth for app-visible plain search results when local cached memo content is available.

#### Scenario: Server misses a cached substring match
- **GIVEN** a cached memo content contains the plain search substring
- **WHEN** the server search path does not return that memo because of token-prefix or version-specific search semantics
- **THEN** the app includes the cached memo in visible results if all other active filters match.

#### Scenario: Server returns a non-matching candidate
- **GIVEN** the server search path returns a memo candidate
- **WHEN** the memo content does not contain the plain search substring
- **THEN** the app excludes that memo from visible results unless another supported searchable field is explicitly part of the search contract.

#### Scenario: Unsynchronized remote-only memo is best effort
- **GIVEN** a memo exists only on the remote server and is not present in local cache
- **WHEN** the server APIs do not return that memo for the plain search query
- **THEN** the app is not required to display that memo.

### Requirement: SearchCoordinator unifies non-empty memo search execution
The system MUST route every non-empty memo search request through a shared `SearchCoordinator` that applies the same query normalization, local candidate lookup, remote merge policy, and final local verification for main memo search, local/offline search, shortcut search, quick search, and link-memo lookup.

#### Scenario: Same query uses the same matching contract across surfaces
- **WHEN** the same non-empty query and equivalent filters are executed against the same local memo corpus from two supported memo-search surfaces
- **THEN** both searches MUST use the same literal substring matching contract and MUST NOT diverge solely because they come from different provider or controller paths

### Requirement: Memo search matches literal substrings in the canonical search document
The system MUST match a memo when the normalized query appears as a continuous literal substring in that memo's canonical search document. The canonical search document MUST include memo content and the searchable metadata already exposed to local memo search, including supported tags and clip-card search fields. The system MUST NOT require token-prefix, word-boundary, or tokenizer-dependent alignment for a match.

#### Scenario: CJK middle substring matches
- **WHEN** a memo canonical search document contains the text `鍦ㄧЗ搴忎腑瀹夐】` and the query is `绉╁簭`
- **THEN** the memo MUST be returned as a search result

#### Scenario: Searchable metadata remains discoverable
- **WHEN** a memo's canonical search document includes searchable clip-card metadata or tags containing the normalized query as a continuous substring
- **THEN** the memo MUST be eligible to appear in results even if the memo body itself does not contain that substring

### Requirement: Indexed memo search preserves existing filter semantics
The system MUST apply the same state, tag, creator-scope, date-range, advanced-filter, and shortcut-predicate constraints to indexed, fallback, and remote-normalized candidates before they become visible results.

#### Scenario: Substring hit still respects tag and date filters
- **WHEN** a memo contains the query as a continuous substring but does not satisfy the active tag or date-range constraints
- **THEN** the memo MUST be excluded from visible search results

#### Scenario: Advanced filters apply after candidate lookup
- **WHEN** the substring index returns a candidate memo that fails the active advanced filters
- **THEN** the system MUST discard that memo before returning visible results

### Requirement: Search index invalidation is memo-scoped and incremental
The system MUST invalidate and rebuild search index state only for memos whose canonical search document changed or whose searchable rows were removed. The system MUST NOT require a global full-index rebuild to surface a single memo edit, clip-card update, tag change, or deletion.

#### Scenario: Edited memo becomes searchable without full rebuild
- **WHEN** a memo is updated so that its canonical search document now contains a new literal substring query
- **THEN** the system MUST rebuild search index state for that memo and MUST be able to return it for the new query without requiring a full-corpus backfill

#### Scenario: Deleted memo stops contributing old postings
- **WHEN** a memo is deleted or no longer eligible for search results after invalidation processing
- **THEN** its prior index entries MUST stop contributing matches to future searches

### Requirement: Visible results stay correct during partial reindex and remote normalization
The system MUST continue returning correct app-visible results while dirty index entries remain pending, and it MUST locally normalize remote candidates before showing them to the user.

#### Scenario: Dirty memo is still discoverable before rebuild completes
- **WHEN** a memo has been marked dirty after a local searchable-text change and its fresh substring postings have not yet been fully rebuilt
- **THEN** a matching query MUST still be able to return that memo through coordinator-managed fallback or exact verification

#### Scenario: Remote false positives are filtered out locally
- **WHEN** remote search returns a memo whose canonical search document does not contain the normalized literal query and the memo is not already confirmed as a local match
- **THEN** the system MUST exclude that memo from visible results

#### Scenario: Local indexed matches supplement remote misses
- **WHEN** remote search misses a memo that exists in the local cache and that memo satisfies the same filters plus the literal substring contract
- **THEN** the system MUST still include the local memo in visible results

### Requirement: AI-assisted memo search is explicit and user-triggered
The system SHALL keep literal keyword search as the default behavior for non-empty memo search queries and SHALL start AI-assisted semantic search only after an explicit user action for the current query.

#### Scenario: Keyword search remains default
- **WHEN** the user enters a non-empty memo search query
- **THEN** the system SHALL first execute the existing literal keyword search path and SHALL NOT automatically execute AI-assisted semantic search.

#### Scenario: Empty keyword results offer AI search
- **WHEN** keyword search for a non-empty query returns no visible memo results
- **THEN** the system SHALL present a user-triggered AI-assisted search action for that same query.

#### Scenario: Non-empty keyword results can still offer AI search
- **WHEN** keyword search for a non-empty query returns visible memo results
- **THEN** the system SHALL provide at least one user-triggered affordance that lets the user run AI-assisted search for the same query without replacing the default keyword behavior.

### Requirement: AI-assisted memo search retrieves semantic local matches
The system SHALL use configured embedding capability to retrieve local memos whose content is semantically related to the user query, even when the memo does not contain the query as a literal substring.

#### Scenario: Semantic food query finds related memo
- **GIVEN** a locally cached eligible memo discusses `澶х洏楦
- **WHEN** the user searches for `鍚冧粈涔坄 and explicitly runs AI-assisted search
- **THEN** the memo SHALL be eligible to appear in AI-assisted results even if its canonical search document does not contain `鍚冧粈涔坄 as a literal substring.

#### Scenario: AI search uses local corpus semantics
- **WHEN** AI-assisted search runs for a non-empty query
- **THEN** the system SHALL rank results by semantic relevance to eligible locally available memo content rather than by server keyword search behavior.

#### Scenario: AI search labels semantic results
- **WHEN** AI-assisted search results are displayed
- **THEN** the system SHALL indicate that the visible results come from AI-assisted semantic search rather than literal keyword matching.

### Requirement: AI-assisted memo search preserves filters and eligibility
The system SHALL preserve active memo search constraints and AI eligibility rules before showing AI-assisted results.

#### Scenario: State and date filters remain enforced
- **WHEN** AI-assisted search finds a semantically related memo outside the active state or date-range constraints
- **THEN** the system SHALL exclude that memo from visible AI-assisted results.

#### Scenario: Tag and advanced filters remain enforced
- **WHEN** AI-assisted search finds a semantically related memo that does not satisfy the active tag or advanced filters
- **THEN** the system SHALL exclude that memo from visible AI-assisted results.

#### Scenario: AI policy is respected
- **WHEN** a semantically related memo is marked as not allowed for AI processing
- **THEN** the system SHALL exclude that memo from AI-assisted indexing and visible AI-assisted results.

#### Scenario: Result limits remain bounded
- **WHEN** AI-assisted search produces more candidate memos than the active result limit
- **THEN** the system SHALL return no more visible AI-assisted results than the active limit allows.

### Requirement: AI-assisted memo search handles configuration and failure states
The system SHALL expose recoverable user-visible states when AI-assisted search cannot run or returns no semantic matches.

#### Scenario: Missing embedding configuration
- **WHEN** the user triggers AI-assisted search without a configured embedding route
- **THEN** the system SHALL show a configuration-required state and SHALL NOT silently fall back to unrelated keyword behavior.

#### Scenario: AI search is loading
- **WHEN** AI-assisted search is indexing, embedding, or ranking results for the current query
- **THEN** the system SHALL show a loading state associated with AI-assisted search.

#### Scenario: AI search fails
- **WHEN** AI-assisted search fails because the configured provider or local indexing operation returns an error
- **THEN** the system SHALL show an error state that keeps keyword search available.

#### Scenario: AI search has no matches
- **WHEN** AI-assisted search completes successfully but finds no eligible semantic matches
- **THEN** the system SHALL show an AI-specific empty state distinct from the default keyword no-results state.

### Requirement: AI-assisted memo search preserves modular boundaries
The system MUST implement AI-assisted search through reusable service, repository, and provider seams without placing semantic retrieval or ranking logic in memo list screens or widgets.

#### Scenario: UI renders AI search state only
- **WHEN** memo list UI code is updated for AI-assisted search
- **THEN** it MUST only render actions, labels, loading/error states, and result lists and MUST NOT own embedding, chunking, ranking, or AI policy logic.

#### Scenario: State providers do not depend on feature widgets
- **WHEN** state providers are added or changed for AI-assisted search
- **THEN** they MUST NOT introduce new `state -> features` imports.

#### Scenario: Shared AI retrieval logic is reusable
- **WHEN** AI-assisted search needs chunking, indexing, embedding, scoring, or memo eligibility checks
- **THEN** that logic MUST live in a reusable `data/ai` seam or lower-level repository/service owner instead of being duplicated inside `features/memos` or `state/memos`.

#### Scenario: Guardrails cover the new seam
- **WHEN** AI-assisted search is implemented during `evolve_modularity`
- **THEN** automated architecture guardrails MUST verify that the new search path does not worsen known reverse-dependency or shared-logic hotspots.

### Requirement: AI-assisted memo search UI is localized
The system SHALL render all user-visible AI-assisted memo search copy through the existing localization system for every supported app locale.

#### Scenario: AI search entry points use localized copy
- **WHEN** keyword search results are empty or the user is viewing keyword results for a non-empty query
- **THEN** the AI-assisted search affordance SHALL render localized action text instead of hard-coded English copy.

#### Scenario: AI search result labels use localized copy
- **WHEN** AI-assisted semantic results are displayed
- **THEN** AI result labels, keyword recovery actions, and search source labels SHALL render localized copy for the active locale.

#### Scenario: AI search failure states use localized copy
- **WHEN** AI-assisted search cannot run because embedding configuration is missing or the provider returns an error
- **THEN** the configuration-required title, configuration guidance, error title, and recovery action SHALL render localized copy for the active locale.

#### Scenario: AI search empty states use localized copy
- **WHEN** AI-assisted search completes successfully without eligible semantic matches
- **THEN** the AI-specific empty-state title and guidance SHALL render localized copy distinct from the default keyword no-results state.

#### Scenario: Hard-coded AI search UI copy is guarded
- **WHEN** memo list widget code is changed
- **THEN** automated tests or guardrails SHALL fail if known AI-assisted search user-visible English phrases are reintroduced directly in memo list widgets.

### Requirement: AI-assisted memo search confirms token-consuming index builds
The system SHALL run a read-only preflight before starting user-triggered AI-assisted memo search and SHALL ask for user confirmation when the current search scope requires new or refreshed embedding index work.

#### Scenario: AI search starts directly when no index work is needed
- **WHEN** the user triggers AI-assisted memo search for a non-empty query and the current search scope already has fresh embeddings for the active embedding model
- **THEN** the system SHALL start AI-assisted memo search without showing an index token confirmation dialog.

#### Scenario: AI search asks before building embeddings
- **WHEN** the user triggers AI-assisted memo search for a non-empty query and the current search scope requires new or refreshed embeddings for eligible memo chunks
- **THEN** the system SHALL show a confirmation prompt before starting indexing or embedding requests.

#### Scenario: Confirmation shows estimated indexing tokens
- **WHEN** the confirmation prompt is shown
- **THEN** the prompt SHALL include an estimated token count for the required indexing work.

#### Scenario: Cancel keeps keyword search active
- **WHEN** the confirmation prompt is shown and the user cancels
- **THEN** the system SHALL leave the current keyword search state active and SHALL NOT enqueue index jobs, rebuild chunks, or call the embedding provider for indexing.

#### Scenario: Continue starts AI-assisted search
- **WHEN** the confirmation prompt is shown and the user confirms
- **THEN** the system SHALL start AI-assisted memo search and MAY build or refresh the required semantic index according to existing AI search indexing rules.

#### Scenario: Missing embedding configuration keeps existing recovery behavior
- **WHEN** the user triggers AI-assisted memo search without a configured embedding route
- **THEN** the system SHALL NOT show an index token confirmation prompt and SHALL preserve the existing configuration-required recovery state.

### Requirement: AI search index confirmation is localized and informative
The system SHALL render all user-visible AI search index confirmation copy through the existing localization system for every supported app locale.

#### Scenario: Confirmation copy uses active locale
- **WHEN** the AI search index confirmation prompt is shown
- **THEN** the title, explanation, token estimate label, cancel action, and continue action SHALL render localized copy for the active locale.

#### Scenario: Remote embedding warning is explicit
- **WHEN** the active embedding profile uses a remote API backend and the confirmation prompt is shown
- **THEN** the prompt SHALL explain that eligible memo chunks may be sent to the configured embedding model and may consume provider quota or cost.

#### Scenario: Local embedding warning avoids billing claims
- **WHEN** the active embedding profile uses a local API backend and the confirmation prompt is shown
- **THEN** the prompt SHALL explain that the estimated tokens represent local embedding/indexing work without claiming remote provider billing.

#### Scenario: Hard-coded confirmation copy is guarded
- **WHEN** memo list widget or screen code is changed
- **THEN** automated tests or guardrails SHALL fail if known AI search index confirmation English phrases are reintroduced directly in memo list UI code.

### Requirement: AI search index preflight preserves modular boundaries
The system MUST implement AI search index token estimation through reusable service, repository, and provider seams without placing indexing, freshness, chunking, or token-estimation logic in memo list screens or widgets.

#### Scenario: Preflight is read-only
- **WHEN** the system estimates required AI search index work before user confirmation
- **THEN** the preflight MUST NOT enqueue index jobs, invalidate chunks, insert chunks, insert embeddings, or call the embedding provider.

#### Scenario: UI renders and routes user intent only
- **WHEN** memo list UI code is updated for AI search index confirmation
- **THEN** it MUST only request preflight facts through a provider seam, render localized confirmation UI, and route cancel or continue actions.

#### Scenario: State providers do not depend on feature widgets
- **WHEN** state providers are added or changed for AI search index preflight
- **THEN** they MUST NOT introduce new `state -> features` imports.

#### Scenario: Estimation logic reuses AI indexing rules
- **WHEN** AI search index preflight calculates required work
- **THEN** it MUST reuse the same memo eligibility, content hash, chunking, and embedding freshness semantics used by AI-assisted memo search indexing.

### Requirement: Memo search persistence extraction preserves visible search semantics
The system MUST preserve existing memo search result behavior while moving canonical search-document construction and SQLite search-index persistence out of the monolithic `AppDatabase` implementation.

#### Scenario: Literal substring behavior remains unchanged
- **WHEN** a non-empty memo search query is executed after the persistence extraction
- **THEN** the system MUST continue to match canonical search-document literal substrings, including CJK middle substrings and literal characters that have special meaning in `SQL`, `LIKE`, or `SQLite FTS`.

#### Scenario: Searchable metadata remains part of the canonical document
- **WHEN** memo body text does not contain the query but supported tags or clip-card metadata do contain the query
- **THEN** the memo MUST remain eligible to appear in search results according to the existing canonical search-document contract.

#### Scenario: Existing filters and ordering remain constraints
- **WHEN** indexed, dirty, fallback, or remote-normalized search candidates are merged
- **THEN** the system MUST continue to enforce active state, tag, date-range, advanced-filter, ordering, pinning, and result-limit behavior before returning visible results.

### Requirement: Memo search index persistence is owned by a data-layer seam
The system MUST own memo search SQLite table creation, index maintenance, dirty-entry draining, and legacy `memos_fts` recovery through focused data-layer persistence code rather than embedding those responsibilities directly in `AppDatabase`.

#### Scenario: AppDatabase remains a facade and lifecycle owner
- **WHEN** local search tables, `memos_fts`, `memo_search_documents`, `memo_search_substrings`, or `memo_search_dirty` are created, rebuilt, drained, or queried
- **THEN** `AppDatabase` MUST delegate the search-specific SQLite work to a focused data-layer owner while retaining database open, migration ordering, public facade, and notification responsibilities.

#### Scenario: Search index invalidation remains memo-scoped
- **WHEN** a memo, tag mapping, clip-card row, or searchable row is updated or deleted
- **THEN** the extracted persistence path MUST preserve memo-scoped dirty marking, index replacement, or index deletion without requiring a full search-index rebuild for every change.

#### Scenario: Partial reindex remains correct
- **WHEN** dirty search-index entries remain pending after a local searchable-text change
- **THEN** search results MUST continue to include matching dirty memos through the existing fallback or exact-verification behavior.

### Requirement: Memo search document rules are reusable without AppDatabase
The system MUST expose canonical memo search-document construction through a reusable lower-level seam that does not require importing or instantiating `AppDatabase`.

#### Scenario: State search code uses the pure search-document seam
- **WHEN** state-layer search coordination normalizes remote candidates or performs in-memory exact verification
- **THEN** it MUST use the reusable search-document helper rather than calling `AppDatabase` static helpers for pure text construction.

#### Scenario: Database search and state search share one canonical rule
- **WHEN** the database search path builds indexed documents and state search code verifies remote candidates
- **THEN** both paths MUST use the same canonical search-document construction semantics.

### Requirement: Memo search persistence preserves modular boundaries
The system MUST keep extracted memo search persistence code independent of higher app layers and MUST guard against reintroducing search persistence ownership into feature, state, or application code.

#### Scenario: Persistence seam has no upward imports
- **WHEN** memo search DB persistence files are added or changed
- **THEN** automated architecture checks MUST fail if those files import `features/`, `state/`, or `application/`.

#### Scenario: Guardrails cover AppDatabase search utility leakage
- **WHEN** state-layer search code is added or changed
- **THEN** automated architecture checks MUST fail if pure canonical search-document construction is accessed through `AppDatabase` instead of the reusable search-document seam.

#### Scenario: No new reverse dependencies are introduced
- **WHEN** memo search persistence extraction is implemented during `evolve_modularity`
- **THEN** it MUST NOT add new `state -> features`, `application -> features`, or `core -> state|application|features` imports.

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

### Requirement: Home keyword search is scoped to the current user's memo library
主页非空关键词搜索 SHALL 只展示当前用户自己的 memo。远端搜索返回的探索页 memo、其他用户 memo、或无法证明属于当前用户的 remote-only memo MUST NOT 成为主页搜索可见结果，即使它们满足关键词、tag、state、date range 或 advanced filters。

#### Scenario: Remote search returns another user's memo
- **GIVEN** 当前账号为 `users/1`
- **AND** 主页搜索 query 非空
- **WHEN** 远端搜索返回 `creator` 为 `users/2` 的 memo
- **THEN** 该 memo MUST NOT 出现在主页搜索结果中

#### Scenario: Remote-only candidate has missing or untrusted creator
- **GIVEN** 当前账号为 `users/1`
- **AND** 远端候选 memo 不存在于当前工作区本地 DB
- **WHEN** 该远端候选缺少可验证的 `creator` 或其 `creator` 无法与当前账号匹配
- **THEN** 该 memo MUST NOT 出现在主页搜索结果中

#### Scenario: Current user's memo remains searchable
- **GIVEN** 当前账号为 `users/1`
- **AND** 主页搜索 query 非空
- **WHEN** 远端搜索返回 `creator` 为 `users/1` 且满足当前关键词和筛选条件的 memo
- **THEN** 该 memo SHALL 出现在主页搜索结果中

#### Scenario: Local memo library matches still supplement remote misses
- **GIVEN** 当前工作区本地 DB 中存在满足当前关键词和筛选条件的 memo
- **WHEN** 远端搜索没有返回该 memo
- **THEN** 主页搜索 SHALL 继续展示该本地 memo

#### Scenario: Explore search remains separate
- **WHEN** 用户在探索页浏览或搜索公开 memo
- **THEN** 探索页 SHALL 继续使用探索页自己的结果流
- **AND** 主页搜索的当前用户作用域规则 MUST NOT 移除探索页中的公开结果

### Requirement: Home keyword search uses a blank waiting state for first results
主页非空关键词搜索 SHALL 在新 query 的首次结果返回前显示空白等待态。等待期间内容区 MUST NOT 展示上一 query 的 memo、默认全量 memo、skeleton cards、无结果提示或错误提示；搜索框、筛选入口和搜索 chrome MAY 保持可见。

#### Scenario: New query starts loading after full list is visible
- **GIVEN** 主页正在展示默认全量 memo 列表
- **WHEN** 用户输入非空搜索 query 且该 query 的首次结果仍在加载
- **THEN** 主页内容区 MUST 进入空白等待态
- **AND** 默认全量 memo 列表 MUST NOT 继续显示为搜索结果

#### Scenario: Query changes while previous search results are visible
- **GIVEN** 主页正在展示 query `alpha` 的搜索结果
- **WHEN** 用户将搜索 query 改为 `beta` 且 `beta` 的首次结果仍在加载
- **THEN** 主页内容区 MUST 进入空白等待态
- **AND** query `alpha` 的结果 MUST NOT 继续显示

#### Scenario: Search completes with results
- **GIVEN** 主页内容区处于非空 query 的空白等待态
- **WHEN** 当前 query 搜索完成并返回至少一个可见 memo
- **THEN** 主页内容区 SHALL 显示当前 query 的结果列表

#### Scenario: Search completes with no results
- **GIVEN** 主页内容区处于非空 query 的空白等待态
- **WHEN** 当前 query 搜索完成且没有可见 memo
- **THEN** 主页内容区 SHALL 显示搜索无结果状态
- **AND** 无结果状态 MUST NOT 在首次加载完成前出现

#### Scenario: Same-query refresh can preserve visible results
- **GIVEN** 主页已经展示当前 query 的搜索结果
- **WHEN** 同一 query 触发刷新或分页加载
- **THEN** 主页 MAY 保留当前 query 的已有结果
- **AND** 任何加载反馈 MUST NOT 混入其他 query 或默认全量 memo
