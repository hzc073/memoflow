## Why

当前主页 memo 卡片在开启 engagement 偏好后会加载点赞和评论，但这些数据只在首次进入对应 `MemoEngagementController` 时加载；其他客户端产生点赞或评论后，主页不会自动失效刷新，用户需要退出 APP 再进入才会看到新数据。参考 Memos `0.27.1+` 后端已经提供 `/api/v1/sse` live refresh 事件，本变更需要把这些事件接入 Flutter 客户端，用于 0.27+ 服务器的点赞和评论同步。

项目当前处于 `evolve_modularity` 阶段，本变更会触及 `data/api`、`state/memos` 和主页 memo engagement UI 的交界；实现时必须保持事件解析、连接管理和 provider 失效刷新各自有明确 owner，不引入新的 `state -> features`、`application -> features` 或 `core -> higher-layer` 依赖。

## What Changes

- 为 Memos `0.27.1+` 支持的 `/api/v1/sse` 建立客户端侧 live refresh 设计，消费 `memo.comment.created`、`reaction.upserted`、`reaction.deleted` 等事件。
- 当收到目标 memo 的 comment/reaction 事件时，主页和详情页正在显示的 engagement 状态 SHALL 强制刷新对应 memo 的点赞和评论数据。
- 当 SSE 断线后重连成功时，客户端 SHALL 对当前活跃 memo/engagement 状态执行补偿刷新，避免断线期间丢失事件导致长期陈旧。
- 对不支持 `/api/v1/sse` 的旧服务器或连接失败场景，客户端 SHALL 保持现有手动刷新、进入页面加载、用户本地操作乐观更新行为，不把实时能力作为基础阅读功能的硬依赖。
- 本变更不引入本地 `engagement` 持久化表；离线缓存、冷启动保留点赞/评论预览和批量 engagement 持久同步属于后续可选演进。
- 模块化改进：新增 live refresh 相关逻辑时应使用稳定的 data/state seam，避免把 SSE 解析或重连策略写入 memo widget；如触及 API route/version 代码，应补充对应兼容测试或 provider-level 测试来作为边界 guardrail。

## Capabilities

### New Capabilities

<!-- No new capability. -->

### Modified Capabilities

- `home-memo-engagement`: 增加 0.27+ Memos SSE live refresh 下主页点赞和评论自动同步的 requirement，并明确断线、旧服务器和模块边界行为。

## Impact

- Affected code:
  - `memos_flutter_app/lib/data/api/**`：可能需要新增或扩展 `/api/v1/sse` stream 客户端、事件模型、版本支持或 capability probing。任何编辑前需要用户对 API 相关代码给出显式批准。
  - `memos_flutter_app/lib/state/memos/**`：需要让 live refresh 事件可以触发 `MemoEngagementController` 的 `load(force: true)` 或等价的 provider invalidation。
  - `memos_flutter_app/lib/state/system/**` 或应用 composition seam：需要在账号登录、切换、退出、前后台生命周期中启动/停止 SSE 连接。
  - `memos_flutter_app/lib/features/memos/**`：主页和详情 engagement UI 应继续只消费 state/provider，不直接解析 SSE 或管理长连接。
- Affected tests:
  - provider/unit tests 覆盖 reaction/comment event 到 engagement 刷新的映射。
  - API/data tests 覆盖 `/api/v1/sse` 请求 header、事件解析、心跳注释忽略、断线重连策略的关键路径。
  - widget tests 可覆盖主页 card 在 provider 刷新后显示新的点赞/评论计数。
- API impact:
  - 新增对 Memos `0.27.1+` `/api/v1/sse` 的可选消费；不改变现有 memo CRUD、reaction、comment REST request shape。
- Architecture impact:
  - Active phase remains `evolve_modularity`.
  - 触及 checklist item 1、2、3、4 的风险边界，要求实现不新增反向依赖，并把可复用 live refresh mapping 放在稳定 seam 中，而不是 widget 文件中。
