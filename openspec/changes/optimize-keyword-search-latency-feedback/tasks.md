## 1. 规则收窄

- [x] 1.1 将本 change 收窄为规则更新，不要求应用代码修改。
- [x] 1.2 明确只采纳 Joplin 的两个设计原则：后台/显式索引维护、SQL filter pushdown。
- [x] 1.3 明确不做 Joplin-style FTS 全量替换，不改变 MemoFlow 的 literal substring 和 CJK 短查询语义。

## 2. 后续实现准备

- [ ] 2.1 设计 `memo_search_dirty` 后台维护 seam，优先考虑写入后、同步后、idle maintenance 或 self-repair。
- [ ] 2.2 为 query-time dirty fallback 定义明确预算，避免大 backlog 在搜索路径中无界扫描。
- [ ] 2.3 定义 dirty memo 可发现性策略，确保维护异步化后不会漏掉刚修改的 memo。

## 3. SQL 下推准备

- [ ] 3.1 梳理 `AdvancedSearchFilters` 中可等价下推的条件。
- [ ] 3.2 优先下推 `state`、tag、date range、location presence、attachment presence、relation presence。
- [ ] 3.3 对 attachment type、attachment name、shortcut predicate 等暂不能等价表达的条件保留 Dart verification。

## 4. 验证要求

- [ ] 4.1 后续实现必须覆盖 CJK 1 字、CJK 2 字、metadata、URL host、literal `%`/`_` 搜索语义。
- [ ] 4.2 后续实现必须覆盖 dirty backlog 规模场景，至少包括 0、64、500、2000。
- [ ] 4.3 后续实现必须覆盖 SQL 下推路径与 Dart fallback 的可见结果一致性。
- [ ] 4.4 后续实现必须运行相关 DB/provider tests 和 architecture guardrails。
