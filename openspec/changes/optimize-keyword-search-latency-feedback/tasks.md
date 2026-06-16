## 1. 规则收窄

- [x] 1.1 将本 change 收窄为规则更新，不要求应用代码修改。
- [x] 1.2 明确只采纳 Joplin 的两个设计原则：后台/显式索引维护、SQL filter pushdown。
- [x] 1.3 明确不做 Joplin-style FTS 全量替换，不改变 MemoFlow 的 literal substring 和 CJK 短查询语义。

## 2. 后续实现准备

- [x] 2.1 设计 `memo_search_dirty` 后台维护 seam，优先考虑写入后、同步后、idle maintenance 或 self-repair。
  - 实现：`AppDatabase.notifyDataChanged()` 后调度小批量后台维护；`rebuildMemoSearchIndex()` 与新增 `drainMemoSearchDirtyEntries()` 保留显式维护入口。
- [x] 2.2 为 query-time dirty fallback 定义明确预算，避免大 backlog 在搜索路径中无界扫描。
  - 实现：`MemoSearchDbPersistence.listRows()` 不再在查询前 drain dirty backlog，只对排序后的 dirty rows 执行固定预算 fallback，默认 `64`。
- [x] 2.3 定义 dirty memo 可发现性策略，确保维护异步化后不会漏掉刚修改的 memo。
  - 实现：预算内 dirty memo 继续做精确 canonical verification；预算外 memo 通过后台/显式 drain 进入 substring index 后可见。

## 3. SQL 下推准备

- [x] 3.1 梳理 `AdvancedSearchFilters` 中可等价下推的条件。
- [x] 3.2 优先下推 `state`、tag、date range、location presence、attachment presence、relation presence。
  - 实现：`state`、tag、主查询日期范围继续由既有 DB 参数表达；`AdvancedSearchFilters.createdDateRange`、`hasLocation`、`hasAttachments`、`hasRelations` 转成 data-layer `MemoSearchDbFilters`。
- [x] 3.3 对 attachment type、attachment name、shortcut predicate 等暂不能等价表达的条件保留 Dart verification。
  - 实现：`locationContains`、`attachmentNameContains`、`attachmentType`、shortcut/quick-search predicate 仍在 Dart verification 中处理。

## 4. 验证要求

- [x] 4.1 后续实现必须覆盖 CJK 1 字、CJK 2 字、metadata、URL host、literal `%`/`_` 搜索语义。
  - 验证：`flutter test test/data/db/app_database_search_test.dart test/state/memos/memo_search_consistency_test.dart --reporter expanded`；`flutter test test/data/db/app_database_clip_card_test.dart test/state/memos/advanced_search_filters_test.dart test/architecture/modularity_dependency_guardrail_test.dart --reporter expanded`。
- [x] 4.2 后续实现必须覆盖 dirty backlog 规模场景，至少包括 0、64、500、2000。
  - 验证：`listMemos bounds dirty fallback across backlog sizes` 覆盖 `0`、`64`、`500`、`2000` dirty backlog，并验证预算外 query-time fallback 不全量扫描，显式维护后结果可见。
- [x] 4.3 后续实现必须覆盖 SQL 下推路径与 Dart fallback 的可见结果一致性。
  - 验证：新增 `listMemos applies SQLite-owned advanced filter candidates` 覆盖 location/attachment/relation SQL 下推；既有 `AdvancedSearchFilters.matches` 测试保留 Dart verification。
- [x] 4.4 后续实现必须运行相关 DB/provider tests 和 architecture guardrails。
  - 验证：已运行相关 DB/provider tests、`test/architecture/modularity_dependency_guardrail_test.dart`，并运行 `flutter analyze`。
