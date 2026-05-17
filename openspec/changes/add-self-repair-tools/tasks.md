## 1. Scope And UX Policy

- [x] 1.1 Confirm first implementation slice: feedback entry plus dedicated self-repair page with tag cleanup, search index rebuild, and stats cache rebuild
- [x] 1.2 Confirm wording policy for strict tag recompute: users are told tags absent from memo body may be removed
- [x] 1.3 Confirm no full database reset, account clearing, attachment deletion, WebDAV mutation, remote sync repair, or API compatibility change is in scope

## 2. Repair Service Seam

- [x] 2.1 Add a focused self-repair mutation/service seam outside feature widgets
- [x] 2.2 Route tag cleanup through `AppDatabase.rebuildMemoTagsFromContent`
- [x] 2.3 Route stats rebuild through `AppDatabase.rebuildStatsCache`
- [x] 2.4 Add an `AppDatabase` facade for local search index rebuild instead of importing search persistence from UI/state code
- [x] 2.5 Ensure repair operations serialize or disable concurrent actions for one page/session

## 3. Self-Repair UI

- [x] 3.1 Add `FeedbackScreen` entry for self repair
- [x] 3.2 Add a dedicated self-repair settings page matching existing settings visual patterns
- [x] 3.3 Add confirmation, busy, success, and failure states for each action
- [x] 3.4 Keep user-visible copy localized for every supported locale
- [x] 3.5 Ensure tag cleanup confirmation explains strict recompute/removal behavior clearly

## 4. Search Index Rebuild

- [x] 4.1 Expose local keyword search index rebuild through `AppDatabase`
- [x] 4.2 Preserve `MemoSearchDbPersistence` as the focused data-layer owner for FTS/index table details
- [x] 4.3 Decide whether rebuild completion drains dirty entries immediately or leaves existing lazy drain behavior documented and tested
- [x] 4.4 Verify rebuilt search preserves literal substring behavior and existing filters

## 5. Data Consistency Tests

- [x] 5.1 Add focused test proving self-repair tag cleanup removes historical code-context false positives and preserves real tags
- [x] 5.2 Add focused test proving tag cleanup updates `memo_tags`, `memos.tags`, search/dirty state, and stats consistently
- [x] 5.3 Add focused test proving search index rebuild restores searchability without changing memo content
- [x] 5.4 Add focused test proving stats cache rebuild restores heatmap/tag summary data

## 6. Modularity Guardrails

- [x] 6.1 Verify feature UI does not import `MemoSearchDbPersistence`, `TagDbPersistence`, or other focused DB persistence helpers directly
- [x] 6.2 Verify the self-repair service does not introduce `state -> features`, `application -> features`, or `core -> higher-layer` dependencies
- [x] 6.3 Add or tighten guardrail coverage if the new repair seam creates a new boundary risk

## 7. Validation

- [x] 7.1 Run focused self-repair/tag/search/stats tests from `memos_flutter_app`
- [x] 7.2 Run architecture guardrail tests relevant to DB persistence and feature/state boundaries
- [x] 7.3 Run `flutter analyze`
- [x] 7.4 Run `flutter test`
