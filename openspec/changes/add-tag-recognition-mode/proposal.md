## Why

当前 MemoFlow 只从严格标签区识别标签，`文字 #标签` 不会成为标签；这符合现有设计，但与 Memos 用户对 inline hashtag 的直觉不一致，容易被误认为 bug。需要提供一个工作区级偏好，让用户在 Memos 兼容识别和 MemoFlow 严格识别之间明确选择。

## What Changes

- 新增工作区级 `TagRecognitionMode`，支持 `memosCompatible` 与 `memoflowStrict`。
- 新装或新工作区默认 `memosCompatible`；已有工作区缺少该偏好时迁移为 `memoflowStrict`，避免升级后静默改变旧用户标签结果。
- `memosCompatible` 尽量复刻参考 Memos 后端的全文 inline `#tag` 识别行为；`memoflowStrict` 保留首/尾严格标签区模型。
- 严格模式采用本地可见权威：本地标签页、搜索过滤、渲染、重算和 autocomplete 都按严格规则，不因远端返回 inline-derived tags 而显示为本地可见标签。
- 偏好设置页新增“标签识别规则”选择项，并在标题旁提供 tip 图标；点击后居中弹窗说明两种模式差异和示例。
- 切换模式后提示用户可按新规则重建已有 memo 的本地标签索引、搜索索引和统计缓存。
- 继续保持 public repository 免费功能边界；不引入订阅、计费、entitlement、paywall 或私有 overlay 逻辑。

## Capabilities

### New Capabilities

- `tag-recognition-preferences`: 定义用户可见的标签识别模式偏好、默认/升级行为、设置页说明弹窗和切换后重算提示。

### Modified Capabilities

- `memos-tag-compatibility`: 将现有单一严格提取规则扩展为 mode-aware 标签提取、远端 tag 处理和渲染装饰规则。
- `memo-search`: tag filter、searchable metadata 和 fallback extraction MUST 使用当前标签识别模式，避免搜索结果与标签页可见语义不一致。
- `self-repair-tools`: 异常标签修复 MUST 按当前标签识别模式重算本地派生标签，并在模式切换确认后可复用该维护流程。
- `memo-compose-tag-autocomplete`: 标签 autocomplete MUST 与当前标签识别模式一致，避免严格模式下对不会保存的正文 inline hashtag 给出误导性建议。

## Impact

- Affected code: `memos_flutter_app/lib/core/tags.dart`, workspace preferences model/provider, preferences settings UI, memo render preprocessing, memo write/import/sync/search fallback paths, self-repair maintenance flow, focused tests under `memos_flutter_app/test`.
- Affected data behavior: 本地 `memo_tags`、`memos.tags`、search index、tag statistics 会在用户确认重算后按当前模式刷新；普通偏好切换本身不应自动改写已有 memo 内容。
- API impact: 不修改 `memos_flutter_app/lib/data/api` request/response models、route adapters 或版本兼容逻辑。
- Modularity impact: 当前架构阶段为 `evolve_modularity`，本变更触及 checklist `1`、`4`、`7`、`8`、`10`。实现 MUST 通过共享 tag recognition seam 避免在 feature widgets/screens 中复制标签解析逻辑，并补充 guardrail 或 focused tests，确保不会扩大 `state -> features` 等已知反向依赖。
