## Context

MemoFlow 当前在 `core/tags.dart` 中集中实现 tag grammar、严格标签区提取、normalization，并由 memo 写入、导入、同步、搜索 fallback 和渲染路径复用。参考 Memos 后端 `internal/markdown/parser/tag.go` 则采用 Markdown inline parser，`Text with #tag`、列表项 `#todo`、句末标点前 `#urgent.` 和数字 `#123` 都会成为标签。

本变更跨越 `core`、`data/db`、`state/memos`、`state/settings`、settings UI、memo rendering 与 self-repair。当前架构阶段为 `evolve_modularity`，需要在触碰耦合区域时通过共享 seam 和 guardrail 保持或改善结构。

## Goals / Non-Goals

**Goals:**
- 提供工作区级标签识别模式：`memosCompatible` 与 `memoflowStrict`。
- 新装默认 Memos 兼容；旧工作区缺省保持严格模式，避免升级后静默改变历史标签。
- 让标签页、搜索过滤、渲染、autocomplete、自修复和本地派生写入共享同一 mode-aware 语义。
- 严格模式下本地可见标签以严格规则为权威，即使远端返回 inline-derived tags。
- 在设置页提供清晰说明和示例，并在切换后提示用户主动重建旧索引。

**Non-Goals:**
- 不修改 `memos_flutter_app/lib/data/api` 的 request/response models、route adapters 或 server-version compatibility logic。
- 不改变远端服务器自身存储或返回 `Memo.tags` 的行为。
- 不自动改写 memo 正文，也不在偏好切换时无确认地批量删除或新增本地 tag rows。
- 不引入商业、订阅、billing、entitlement、paywall、StoreKit 或 private overlay 逻辑。

## Decisions

### Decision 1: 通过 lower-layer tag recognition seam 统一模式

在 `core/tags.dart` 增加 `TagRecognitionMode` 与 mode-aware extraction API，例如 `extractTags(content, mode: ...)` 和 `deriveVisibleMemoTags(content: ..., remoteTags: ..., mode: ...)`。现有严格逻辑保留为 `memoflowStrict`；新增 `memosCompatible` 采用全文 Markdown-aware inline tag 扫描。

Rationale: 标签解析是 checklist `4` 高风险共享 domain logic，必须留在 lower layer，不能分散到 screen/widget。`state`、`application`、`features` 只能消费该 seam。

Alternative considered: 在各调用点各自判断模式。拒绝，因为会复制规则、增加搜索/渲染/写入不一致风险，并可能扩大已知耦合热点。

### Decision 2: 工作区级偏好，新装默认兼容，旧工作区迁移严格

`WorkspacePreferences` 新增 `tagRecognitionMode`。`WorkspacePreferences.defaults` 使用 `memosCompatible`；`fromJson` 对缺少字段的旧 JSON 返回 `memoflowStrict`；显式存储值按存储值解析。

Rationale: 标签识别是 memo library 语义，应随账号/本地库而不是设备。旧工作区保持严格可避免升级后标签页突然新增大量正文 hashtag。

Alternative considered: 全部默认 Memos 兼容。拒绝，因为会改变已有用户数据可见结果。

### Decision 3: 严格模式使用本地可见权威

远端 `Memo.tags` 仍可被 API adapter 解析和保留，但进入本地可见标签、tag filter、search fallback、render decoration、autocomplete 和 mode-aware repair 时，`memoflowStrict` MUST 只使用严格规则从正文派生的 tag set。`memosCompatible` MAY 合并远端 tags 与本地兼容提取结果。

Rationale: 用户选择“严格标签区”时，产品承诺应覆盖可见行为；否则连接 Memos 后端时严格模式会失去意义。

Trade-off: 严格模式下本地可见标签可能不同于远端 Memos UI。通过设置说明和 tip 弹窗明确该模式是 MemoFlow 本地可见标签语义。

### Decision 4: 渲染与 autocomplete 跟随模式

`decorateMemoTagsForHtml` 或等价预处理接口需要接收 mode。严格模式只装饰严格标签区；兼容模式装饰普通 Markdown text 中的 inline tags，同时避开 code、link、URL 等保护上下文。`detectActiveTagQuery` 增加 mode-aware 判断：兼容模式保留当前 inline 查询体验；严格模式只在当前文本位置可能成为严格标签区前缀时显示建议。

Rationale: 如果正文 `#tag` 不会保存为标签，却被渲染成 chip 或弹出 autocomplete，会误导用户。

### Decision 5: 切换后复用 self-repair seam 做显式重算

设置页保存新 mode 后弹出确认对话框，说明旧 memo 的本地标签索引可按新规则重建。确认后调用 mode-aware maintenance service：重算 `memo_tags`/`memos.tags`，prune orphan tags，重建搜索索引和统计缓存；取消则仅保存偏好，不修改已有派生数据。

Rationale: 现有 `SelfRepairMutationService` 和 `AppDatabase.rebuildMemoTagsFromContent` 已是本地派生数据维护 owner。复用该 seam 保持 checklist `7`，避免 UI 直接拼装 DB 操作。

### Decision 6: Guardrails and tests protect the touched hotspot

新增或更新 focused tests，确保 tag extraction seam、settings preference model、mode-aware self-repair、search filter fallback、autocomplete 和 render decoration 使用同一 mode。补充 architecture/guardrail 覆盖，禁止 `features` screen/widget 重新拥有 tag parsing 或 lower layers import feature UI。

Dependency direction before: `state/memos`、`state/settings` 已有部分 reverse dependency 热点；tag parsing 主要在 `core`，但部分 call sites 直接裸调 `extractTags(content)`。

Dependency direction after: lower layers仍不依赖 feature UI；mode 通过 provider 在 state/feature 边界读取后传给 core seam；settings UI 只渲染和派发用户 intent；maintenance service 继续通过 DB facade 执行维护。

## Risks / Trade-offs

- [Risk] 兼容模式全文扫描可能把 `Issue #123` 等内容识别为标签。→ Mitigation: 明确按参考 Memos 兼容；在 tip 弹窗和 tests 中固化该行为。
- [Risk] 严格模式忽略远端 inline-derived tags 会让 MemoFlow 与远端 Memos UI 标签计数不同。→ Mitigation: 将其定义为“MemoFlow 本地可见标签语义”，并提供 Memos 兼容模式。
- [Risk] 切换模式后如果不重算，旧 memo 标签页短期不一致。→ Mitigation: 切换后立即提示重算；自修复页也按当前模式提供显式维护入口。
- [Risk] 搜索、AI、导入或同步路径漏改会产生语义不一致。→ Mitigation: 抽出 `deriveVisibleMemoTags` 等统一 seam，并用 focused tests/guardrails 查找裸 `extractTags(content)` 调用。
- [Risk] 兼容模式渲染 inline tags 可能误处理 code/link。→ Mitigation: 重用 Markdown-aware protected-range/fence handling，并用 code、inline code、link、URL fragment tests 覆盖。

## Migration Plan

1. 增加 mode enum、偏好字段和解析逻辑；旧工作区缺字段解析为 `memoflowStrict`，新默认使用 `memosCompatible`。
2. 引入 mode-aware tag extraction/visible tag seam，并逐步替换 create/edit/import/sync/search/render/autocomplete/self-repair call sites。
3. 添加设置页 row、tip 弹窗和切换后重算提示；确认时复用 mode-aware self-repair。
4. 更新 i18n YAML 并生成 `strings.g.dart`。
5. 运行 focused tests、`flutter analyze`、`flutter test`。

Rollback: 若需要回滚，保留未知 `tagRecognitionMode` 字段不会影响旧代码读取；本地派生 tags 可通过自修复在目标规则下重新生成。

## Open Questions

无。默认值、升级行为、严格模式远端策略、兼容边界和切换后重算策略已确认。
