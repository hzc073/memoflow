## Why

当前 MemoFlow 只从严格标签区识别标签，`文字 #标签` 不会成为标签；这符合现有设计，但与 Memos 用户对 inline hashtag 的直觉不一致，容易被误认为 bug。同时，不同用户对列表项、正文、数字标签、远端返回标签等“识别情况”的期望不同。需要提供一个工作区级标签识别策略，让普通用户可以选择稳定预设，让高级用户可以组合受支持的识别规则，并保持 MemoFlow 默认使用当前严格方案。

## What Changes

- 新增工作区级 `TagRecognitionPolicy`，支持 `memoflowStrict`、`memosCompatible` 与 `custom`。
- MemoFlow 新装、新工作区、旧工作区缺少该偏好时均默认 `memoflowStrict`，避免静默改变标签结果，并保持 MemoFlow 当前严格方案作为默认产品语义。
- 不在首次连接 Memos 或导入 Memos 数据时提示用户切换为 Memos 兼容；导入、同步和写入路径只使用当前工作区已保存的标签识别策略。
- `memosCompatible` 尽量复刻参考 Memos 后端的全文 inline `#tag` 识别行为；`memoflowStrict` 保留首/尾严格标签区模型。
- `custom` 允许用户从受支持的识别维度生成策略，例如严格标签区位置、正文 inline 标签、列表/引用/table 文本中的标签、数字标签、远端 `Memo.tags` 合并策略；不开放自由正则、脚本或不可测试 parser 扩展。
- 自定义策略页顶部提供通用影响与重算说明；每个可组合选项后提供 info 弹窗，解释该选项改变的识别结果、示例和适用习惯。
- 严格预设采用本地可见权威：本地标签页、搜索过滤、渲染、重算和 autocomplete 都按严格规则，不因远端返回 inline-derived tags 而显示为本地可见标签。
- 偏好设置页新增“标签识别规则”选择项，并在标题旁提供 tip 图标；点击后居中弹窗说明预设和自定义方案差异及示例。
- 切换策略后提示用户可按新规则重建已有 memo 的本地标签索引、搜索索引和统计缓存。
- 继续保持 public repository 免费功能边界；不引入订阅、计费、entitlement、paywall 或私有 overlay 逻辑。

## Capabilities

### New Capabilities

- `tag-recognition-preferences`: 定义用户可见的标签识别策略偏好、默认/升级行为、预设/自定义 UI、设置页说明弹窗和切换后重算提示。

### Modified Capabilities

- `memos-tag-compatibility`: 将现有单一严格提取规则扩展为 policy-aware 标签提取、远端 tag 处理和渲染装饰规则。
- `memo-search`: tag filter、searchable metadata 和 fallback extraction MUST 使用当前标签识别策略，避免搜索结果与标签页可见语义不一致。
- `self-repair-tools`: 异常标签修复 MUST 按当前标签识别策略重算本地派生标签，并在策略切换确认后可复用该维护流程。
- `memo-compose-tag-autocomplete`: 标签 autocomplete MUST 与当前标签识别策略一致，避免对不会保存的正文 inline hashtag 给出误导性建议。

## Impact

- Affected code: `memos_flutter_app/lib/core/tags.dart`, workspace preferences model/provider, preferences settings UI, memo render preprocessing, memo write/import/sync/search fallback paths, self-repair maintenance flow, focused tests under `memos_flutter_app/test`.
- Affected data behavior: 本地 `memo_tags`、`memos.tags`、search index、tag statistics 会在用户确认重算后按当前策略刷新；普通偏好切换本身不应自动改写已有 memo 内容。
- API impact: 不修改 `memos_flutter_app/lib/data/api` request/response models、route adapters 或版本兼容逻辑。
- Modularity impact: 当前架构阶段为 `evolve_modularity`，本变更触及 checklist `1`、`4`、`7`、`8`、`10`。实现 MUST 通过共享 tag recognition seam 避免在 feature widgets/screens 中复制标签解析逻辑，并补充 guardrail 或 focused tests，确保不会扩大 `state -> features` 等已知反向依赖。
