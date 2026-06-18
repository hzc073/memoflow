## Context

MemoFlow 当前在 `core/tags.dart` 中集中实现 tag grammar、严格标签区提取、normalization，并由 memo 写入、导入、同步、搜索 fallback 和渲染路径复用。参考 Memos 后端 `internal/markdown/parser/tag.go` 则采用 Markdown inline parser，`Text with #tag`、列表项 `#todo`、句末标点前 `#urgent.` 和数字 `#123` 都会成为标签。

现有实现已经隐含两层语义：`findInlineTagMatches` 负责判断 `#...` token 是否像标签，`findStrictTagZoneLineIndexes` 和 `findStrictTagZonePrefixMatches` 决定这些 token 在哪些位置能成为 app-visible tags。本变更将这两层抽象为工作区级 `TagRecognitionPolicy`，用预设覆盖常见语义，用受控选项支持高级自定义。

本变更跨越 `core`、`data/db`、`state/memos`、`state/settings`、settings UI、memo rendering 与 self-repair。当前架构阶段为 `evolve_modularity`，需要在触碰耦合区域时通过共享 seam 和 guardrail 保持或改善结构。

## Goals / Non-Goals

**Goals:**
- 提供工作区级标签识别策略：`memoflowStrict`、`memosCompatible` 与 `custom`。
- MemoFlow 新装、新工作区和旧工作区缺省均使用 `memoflowStrict`，保持当前严格方案作为默认产品语义。
- 让标签页、搜索过滤、渲染、autocomplete、自修复和本地派生写入共享同一 policy-aware 语义。
- 严格预设下本地可见标签以严格规则为权威，即使远端返回 inline-derived tags。
- 允许高级用户通过受控选项生成自定义策略，但不允许自由正则、脚本或不可测试 parser 扩展。
- 在设置页提供清晰说明、示例、预设选择、自定义入口；自定义页每个选项都提供 tip 说明，并在策略切换后提示用户主动重建旧索引。

**Non-Goals:**
- 不在首次连接 Memos 或导入 Memos 数据时提示用户切换为 Memos 兼容；导入、同步和写入只尊重当前工作区已保存策略。
- 不修改 `memos_flutter_app/lib/data/api` 的 request/response models、route adapters 或 server-version compatibility logic。
- 不改变远端服务器自身存储或返回 `Memo.tags` 的行为。
- 不自动改写 memo 正文，也不在偏好切换时无确认地批量删除或新增本地 tag rows。
- 不引入商业、订阅、billing、entitlement、paywall、StoreKit 或 private overlay 逻辑。

## Decisions

### Decision 1: 通过 lower-layer tag recognition policy seam 统一语义

在 `core/tags.dart` 增加 `TagRecognitionPolicy` 与 policy-aware extraction API，例如 `extractTags(content, policy: ...)` 和 `deriveVisibleMemoTags(content: ..., remoteTags: ..., policy: ...)`。`memoflowStrict` 与 `memosCompatible` 是冻结预设；`custom` 是由受支持选项解析出的冻结 policy。调用点只能消费 resolved policy，不直接读取 UI 选项并自行拼装解析逻辑。

Rationale: 标签解析是 checklist `4` 高风险共享 domain logic，必须留在 lower layer，不能分散到 screen/widget。`state`、`application`、`features` 只能消费该 seam。

Alternative considered: 在各调用点各自判断策略或自定义选项。拒绝，因为会复制规则、增加搜索/渲染/写入不一致风险，并可能扩大已知耦合热点。

### Decision 2: MemoFlow 默认严格，不做连接/导入切换提示

`WorkspacePreferences` 新增 `tagRecognitionPolicy`。`WorkspacePreferences.defaults` 使用 `memoflowStrict`；`fromJson` 对缺少字段的旧 JSON 返回 `memoflowStrict`；显式存储值按存储值解析。首次连接 Memos、首次同步、导入 Memos 数据或导入 Markdown/第三方数据时，不弹出“是否切换到 Memos 兼容”的提示，也不静默切换策略。

Rationale: 标签识别是 memo library 的核心语义。MemoFlow 默认严格可以避免新旧用户都被正文 hashtag 改变标签结果，也让 Memos 兼容成为明确的用户选择，而不是数据来源驱动的隐式迁移。

Trade-off: Memos 用户第一次使用 MemoFlow 时可能仍会期待 inline hashtag。通过设置入口、tip 示例和文案说明降低误解，而不在连接/导入路径增加打断。

### Decision 3: 自定义策略只开放受控识别维度

`custom` policy SHOULD 从受支持选项生成，初始维度限定为：
- strict tag zones: 首个内容行 prefix、最后内容行 prefix、可选任意内容行 prefix。
- inline Markdown text: 是否识别普通正文、列表项、引用或 table cell 中的 inline `#tag`。
- token classes: 是否允许数字-only tag、层级 tag、emoji/symbol tag；Unicode 文字标签保持支持。
- remote tag handling: 本地正文解析为权威，或合并远端 `Memo.tags`。
- protected contexts: code block、inline code、link destination、image URL、URL fragment 和内部 marker 保护 MUST 始终启用，不作为可关闭选项。

Rationale: 用户要的是“识别情况”的组合，而不是任意 parser。受控维度可以用示例、测试和 guardrail 固化，避免每个用户生成不可维护语义。

Alternative considered: 提供高级正则输入。拒绝，因为会破坏搜索、渲染、autocomplete 和 self-repair 的可验证一致性，也容易引入性能和安全风险。

### Decision 4: 自定义选项逐项提供信息弹窗

自定义策略 UI 中，每个可组合选项后都需要提供 info icon，点击后打开居中说明弹窗。弹窗内容 MUST 覆盖：
- 该选项会让哪些文本位置或 token 类型成为 app-visible tags。
- 一个最小正例和一个容易误解的反例或注意点。
- 适合哪类用户或使用习惯，避免暴露过多 parser 术语。

自定义设置顶部的公共说明承担通用影响说明：渲染、autocomplete、搜索过滤和 self-repair 会跟随最终规则；如果用户希望旧 memo 立刻反映新规则，需要运行本地派生数据重算。

Rationale: 自定义规则的复杂度主要来自“开关之间的组合效果”。逐项信息弹窗比单行 tooltip 更适合展示多段示例，顶部公共说明则避免每个弹窗重复同一段影响和重算提示。

### Decision 5: 严格预设使用本地可见权威，兼容预设可合并远端 tags

远端 `Memo.tags` 仍可被 API adapter 解析和保留，但进入本地可见标签、tag filter、search fallback、render decoration、autocomplete 和 policy-aware repair 时，`memoflowStrict` MUST 只使用严格规则从正文派生的 tag set。`memosCompatible` MAY 合并远端 tags 与本地兼容提取结果。`custom` 按其 remote tag handling 选项执行；若未显式选择，默认使用本地正文解析为权威。

Rationale: 用户选择严格或自定义本地权威时，产品承诺应覆盖可见行为；否则连接 Memos 后端时本地策略会失去意义。

### Decision 6: 渲染与 autocomplete 跟随 resolved policy

`decorateMemoTagsForHtml` 或等价预处理接口需要接收 policy。严格预设只装饰严格标签区；兼容预设装饰普通 Markdown text 中的 inline tags，同时避开 code、link、URL 等保护上下文；自定义策略只装饰其会保存为 app-visible tags 的位置。`detectActiveTagQuery` 增加 policy-aware 判断：只有当前位置可能成为当前策略下的 app-visible tag 时才显示建议。

Rationale: 如果正文 `#tag` 不会保存为标签，却被渲染成 chip 或弹出 autocomplete，会误导用户。

### Decision 7: 切换后复用 self-repair seam 做显式重算

设置页保存新 policy 后弹出确认对话框，说明旧 memo 的本地标签索引可按新规则重建。确认后调用 policy-aware maintenance service：重算 `memo_tags`/`memos.tags`，prune orphan tags，重建搜索索引和统计缓存；取消则仅保存偏好，不修改已有派生数据。

Rationale: 现有 `SelfRepairMutationService` 和 `AppDatabase.rebuildMemoTagsFromContent` 已是本地派生数据维护 owner。复用该 seam 保持 checklist `7`，避免 UI 直接拼装 DB 操作。

### Decision 8: Guardrails and tests protect the touched hotspot

新增或更新 focused tests，确保 tag extraction seam、settings preference model、policy-aware self-repair、search filter fallback、autocomplete 和 render decoration 使用同一 resolved policy。补充 architecture/guardrail 覆盖，禁止 `features` screen/widget 重新拥有 tag parsing 或 lower layers import feature UI。

Dependency direction before: `state/memos`、`state/settings` 已有部分 reverse dependency 热点；tag parsing 主要在 `core`，但部分 call sites 直接裸调 `extractTags(content)`。

Dependency direction after: lower layers 仍不依赖 feature UI；policy 通过 provider 在 state/feature 边界读取后传给 core seam；settings UI 只渲染和派发用户 intent；maintenance service 继续通过 DB facade 执行维护。

## Risks / Trade-offs

- [Risk] 自定义策略过多导致用户不理解结果。→ Mitigation: 默认只显示两个预设和一个高级入口；每个自定义选项提供 tip 说明，并在自定义页使用 live examples 展示当前规则会识别哪些标签。
- [Risk] 兼容预设或 custom inline 选项可能把 `Issue #123` 等内容识别为标签。→ Mitigation: 用数字标签开关、tip 弹窗和 tests 固化行为。
- [Risk] 严格预设忽略远端 inline-derived tags 会让 MemoFlow 与远端 Memos UI 标签计数不同。→ Mitigation: 将其定义为“MemoFlow 本地可见标签语义”，并提供 Memos 兼容预设。
- [Risk] 切换策略后如果不重算，旧 memo 标签页短期不一致。→ Mitigation: 切换后立即提示重算；自修复页也按当前策略提供显式维护入口。
- [Risk] 搜索、AI、导入或同步路径漏改会产生语义不一致。→ Mitigation: 抽出 `deriveVisibleMemoTags` 等统一 seam，并用 focused tests/guardrails 查找裸 `extractTags(content)` 调用。
- [Risk] inline tag 渲染可能误处理 code/link。→ Mitigation: 重用 Markdown-aware protected-range/fence handling，并用 code、inline code、link、URL fragment tests 覆盖。

## Migration Plan

1. 增加 policy 类型、预设解析、custom options、偏好字段和解析逻辑；缺字段统一解析为 `memoflowStrict`。
2. 引入 policy-aware tag extraction/visible tag seam，并逐步替换 create/edit/import/sync/search/render/autocomplete/self-repair call sites。
3. 添加设置页 row、tip 弹窗、预设选择、自定义入口、自定义选项逐项 tip 和切换后重算提示；确认时复用 policy-aware self-repair。
4. 更新 i18n YAML 与 generated strings。
5. 运行 focused tests、`flutter analyze`、`flutter test`。

Rollback: 若需要回滚，保留未知 `tagRecognitionPolicy` 字段不会影响旧代码读取；本地派生 tags 可通过自修复在目标规则下重新生成。

## Open Questions

- 自定义 UI 初版是否开放全部初始维度，还是先开放“正文 inline / 任意行 prefix / 数字标签 / 远端合并”四个高影响选项，其余留在预设内部？
