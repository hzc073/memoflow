## 1. Search contract foundation

- [x] 1.1 定义 shared plain-text matcher，例如 `MemoSearchMatcher` 或等价 helper，用于 literal substring search。
- [x] 1.2 统一 query normalization：trim surrounding whitespace，并确保 query 被当作 literal text。
- [x] 1.3 梳理必须接入 shared matcher 的 surfaces：main search、local/offline search、shortcut search、quick search、link-memo lookup。

## 2. Local memo search

- [x] 2.1 调整 `AppDatabase.listMemos` 或其调用链，使 cached memo 支持 CJK middle substring matching。
- [x] 2.2 保留 `SQLite FTS` 作为 fast candidate path 或优化路径，但 final visible results MUST 满足 shared matcher。
- [x] 2.3 确保 state、tag、date range、ordering、limit、pinning 行为不因 substring matching 被绕过。

## 3. Remote and provider consistency

- [x] 3.1 调整 remote-search provider，使 server candidates 经过 shared matcher 校验。
- [x] 3.2 在 remote search 场景 merge local cached substring matches，并按 memo UID/name deduplicate。
- [x] 3.3 将 shortcut search、quick search、link-memo lookup 接入同一 matcher semantics。
- [x] 3.4 如果实现需要修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`，先暂停并请求 explicit user approval。

## 4. Verification

- [x] 4.1 添加 CJK regression tests：`在`、`在秩序`、`秩序` MUST 命中 `在秩序中安顿`，不存在的 fragment MUST 不命中。
- [x] 4.2 添加 filters regression tests，确认 state/tag/date/shortcut/quick predicates 仍然作为 additional constraints。
- [x] 4.3 添加 surface consistency coverage，验证同一 memo/query 在 local、remote provider、link-memo lookup 等路径下行为一致。
- [x] 4.4 在 `memos_flutter_app` 中运行 targeted tests；实现完成前再运行 `flutter analyze` 和相关 `flutter test`。
