## Why

主页搜索当前在新 query 的搜索结果返回前可能继续展示上一批全量笔记，用户会误以为旧列表就是搜索结果。远端搜索还可能把探索页或其他用户的 memo 混入主页结果，随后进入普通编辑链路并在同步时暴露权限错误。

这个变更把主页搜索的产品语义收紧为“只搜索我的笔记库”，并规定搜索中的内容区为空白等待态，避免显示旧结果或探索内容。

## What Changes

- 主页非空关键词搜索 MUST 只展示当前用户自己的 memo；探索页/public/protected 的其他用户 memo MUST NOT 出现在主页搜索结果中。
- 主页搜索 query 改变并进入首次加载时，内容区 MUST 清空为等待态，不展示上一 query 或全量列表的旧 memo。
- 搜索完成后按结果状态展示：有结果显示结果列表，无结果显示空结果态，错误显示错误态。
- 探索页浏览/搜索不受此变更影响，仍由探索页自己的远端 `Memo` 流程处理。
- 针对远端返回结果增加客户端最终过滤规则与测试，防止服务端版本差异或 fallback 路径把非当前用户 memo 暴露到主页。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `memo-search`: 收紧主页搜索的可见结果作用域，并新增主页搜索加载等待态行为。

## Impact

- 影响 `memos_flutter_app/lib/features/memos` 下主页 memo 列表搜索 UI 状态与可见结果切换。
- 影响 `memos_flutter_app/lib/state/memos` 下远端搜索合并/过滤逻辑；若实现需要调整 `memos_flutter_app/lib/data/api` 或 API 兼容适配，必须先取得用户对 API 相关编辑的明确批准。
- 需要补充 provider/协调器测试，覆盖“远端返回其他用户 memo 时主页搜索不展示”。
- 需要补充 UI 或 view-state 测试，覆盖“搜索加载中不保留旧列表”。
- 当前架构阶段为 `evolve_modularity`。本变更触及 `state/memos` 与 `features/memos` 的搜索边界，必须至少新增或收紧 guardrail/测试来防止搜索作用域和 UI 状态回退，不引入新的 `state -> features` 依赖。
