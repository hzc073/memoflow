## Context

Issue #201 的现象是：用户在偏好设置中开启主页点赞/评论显示后，主页 memo 卡片可以看到 engagement 区域，但其他客户端新增点赞或评论后不会自动同步，必须退出 APP 再进入才刷新。当前 Flutter 侧 engagement 状态由 `memoEngagementControllerProvider(MemoEngagementRequest)` 管理，`MemoEngagementController.load()` 在 `reactionsLoaded` / `commentsLoaded` 后会跳过非 `force` 加载；主页 memo sync 更新 memo 列表本身，但不会让 engagement provider 失效。

参考后端 `F:\Homework\memos\参考项目\memos后端代码\memos-0.29.0\memos-0.29.0`，Memos `0.27.1+` 注册了 `GET /api/v1/sse`。服务端通过 `Authorization: Bearer <token>` 鉴权，响应 `text/event-stream`，发送 `: connected`、`: heartbeat` 注释行以及 `data: {"type":"...","name":"memos/..."}` 事件。事件类型覆盖 memo 创建、更新、删除、评论创建、reaction upsert/delete。官方 Web 客户端 `useLiveMemoRefresh.ts` 的策略是收到事件后 invalidates query caches，而不是直接应用 payload。

本项目处于 `evolve_modularity` 阶段，当前仍存在若干 reverse dependency hotspot。本变更会触及 memo feature、state provider、API/data 连接层和 session/composition seam，设计必须保持依赖方向：

```text
features/memos widgets
        │ consumes
        ▼
state/memos providers  ◀── live refresh coordinator
        │ consumes              │ consumes parsed events
        ▼                       ▼
data/api MemosApi        data/api SSE client/event parser
```

实现后不应出现：

```text
state/memos ──imports──▶ features/memos
core ──imports──▶ state/features
application ──imports──▶ features/memos
```

## Goals / Non-Goals

**Goals:**

- 为 Memos `0.27.1+` 的 `/api/v1/sse` 增加客户端 live refresh 消费能力。
- 将 `reaction.upserted`、`reaction.deleted`、`memo.comment.created` 映射为对应 memo 的 engagement 强制刷新。
- 在 SSE 重连成功后做补偿刷新，避免断线期间丢失事件造成长期陈旧。
- 旧服务器、不支持 SSE、连接失败、后台断线时保持现有页面加载、手动刷新和用户本地乐观更新行为。
- 通过 data/state seam 和 provider-level 测试守住模块边界，避免把连接、解析或映射逻辑放进 widget。

**Non-Goals:**

- 不新增本地 `engagement` SQLite 持久化表。
- 不实现离线下的点赞/评论增量同步。
- 不把服务端 SSE payload 当作完整 reaction/comment 数据直接写入 UI 状态。
- 不改动 memo CRUD、reaction、comment REST request shape。
- 不把实时连接状态作为用户必须理解或操作的新 UI 功能。

## Decisions

### Decision: SSE event 是 invalidation signal，不是数据源

后端事件只包含 `type`、`name` 和可选 `parent`，没有完整 reaction/comment 列表，也没有评论内容、creator display data 或计数快照。因此 Flutter 侧收到事件后应触发对应 provider 的 `load(force: true)` 或等价 invalidation，再复用现有 `listMemoReactions` / `listMemoComments` API 获取权威数据。

备选方案是根据 event 直接修改本地 count，但无法安全处理删除、重复 reaction、其他 reaction type、comment preview 内容、权限过滤和断线漏事件，容易产生与服务端不一致的 UI。

### Decision: 连接与解析归 data/api，刷新编排归 state/application seam

建议新增一个小型 SSE client/event parser owner，负责：

- 构造 `GET /api/v1/sse` 请求。
- 附带 `Accept: text/event-stream` 和 `Authorization: Bearer <token>`。
- 解析 `data:` JSON 行。
- 忽略 `:` 注释心跳。
- 暴露 typed event stream，例如 `MemosLiveRefreshEvent`。

engagement 刷新映射不应放入 widget。可以由 state 层的 coordinator/provider 订阅 typed event stream，并调用已存在或新增的 engagement refresh seam。主页和详情 UI 继续只 watch `memoEngagementControllerProvider`。

依赖方向变化：

- Before: `features/memos` 创建/展示 engagement，`state/memos` 负责一次性加载。
- After: `data/api` 产生 typed live event，`state/memos` 根据事件刷新 engagement，`features/memos` 仍只展示 state。
- Guardrail: 不允许 `data/api`、`state/memos` 或 live coordinator import `features/memos/**`。

### Decision: 对 0.27+ 采用 capability gate，失败时降级

Memos `0.27.1+` 参考后端具备 `/api/v1/sse`。实现应将 SSE 视为可选 capability：

- 当前账号版本为 `0.27.x`、`0.28.x`、`0.29.x` 时可尝试连接。
- 如果连接返回 404/405/501、网络层不支持长连接、代理阻断或认证失败后刷新 token 仍失败，则停止或退避重试，并保留现有行为。
- 对 `0.21` 至 `0.26` 不应强行连接 `/api/v1/sse`。

备选方案是所有版本都试探 `/api/v1/sse`。这会带来旧服务器多余错误日志、登录后无意义网络请求和测试矩阵扩大，不适合当前第一阶段。

### Decision: 重连后刷新活跃 engagement，而不是全量重拉所有 memo

SSE hub 对慢客户端会丢弃事件，移动端后台也可能中断连接。重连成功后需要补偿刷新。范围应控制在当前活跃/已实例化的 engagement provider 或当前主页列表可见 memo，而不是全量账号 memo：

- 如果 provider family 已存在对应 memo 的 controller，可以刷新这些活跃 controllers。
- 如果实现难以枚举活跃 provider，可在 coordinator 中维护最近订阅/显示过的 memo uid set，并限制数量或生命周期。
- 首页列表本身可按既有 memo sync/refresh owner 处理，engagement 只刷新 reaction/comment 状态。

备选方案是重连后触发完整 sync。它更简单但代价高、影响排序和 outbox 相关路径，也会把一个 engagement 实时问题扩大成全局同步行为。

### Decision: 自己发出的本地操作继续 optimistic update，SSE 作为最终校正

当前 `toggleLike()` 和 `createComment()` 已经对本地状态做乐观更新或立即插入新评论。实现不应移除该体验。由于后端也会广播当前用户自己的事件，收到 SSE 后可再 force refresh，作为服务端权威状态校正。需要避免刷新过程覆盖正在提交中的可见 loading 状态或造成重复请求风暴。

## Risks / Trade-offs

- [Risk] 长连接在移动网络、代理、后台生命周期中容易断开 → 使用指数退避重连；断开不阻断基础功能；重连成功后补偿刷新活跃 engagement。
- [Risk] SSE event 到达频繁导致列表中多个 card 同时 force refresh → 合并同 memo 的短时间事件，避免已有 in-flight 请求重复；必要时对活跃 memo set 做上限。
- [Risk] 0.27+ 版本判断与当前 `add-memos-029-api-adapter` 改动重叠 → 实现前确认该 change 已应用或基于最新 API version model；任何 `memos_flutter_app/lib/data/api` 编辑需要用户显式批准。
- [Risk] token 过期导致 SSE 401 循环 → 复用现有 session/token 读取与刷新 seam；刷新失败时断开并等待 session 状态变化。
- [Risk] 把 live refresh 逻辑塞进 `MemoEngagementSurface` 会加重 feature widget 复杂度 → 通过 state/data owner 和 provider tests 约束，widget 不直接管理 SSE。
- [Risk] 本阶段不做本地 engagement 表，冷启动仍需重新加载 engagement → 这是有意取舍；本 issue 的目标是前台实时同步，持久缓存可另起 change。

## Migration Plan

1. 在实现前确认 `add-memos-029-api-adapter` 的基线状态，并取得用户对 API 相关文件编辑的显式批准。
2. 增加 SSE event model/parser/client，并用 fake stream 或 parser unit tests 固化 `data:`、心跳、 malformed JSON、401/404 行为。
3. 增加 live refresh coordinator/provider，把 typed events 映射到 engagement force refresh，不改 widget ownership。
4. 将 coordinator 接入账号 session/composition 生命周期：登录后启动，账号切换/退出时停止，重连时补偿刷新。
5. 补齐 provider/widget/API focused tests，最后运行 `flutter analyze` 和相关 `flutter test`。

Rollback 策略：如果 SSE 连接导致异常，可通过禁用 coordinator 启动或 capability gate 回退到现有 engagement 加载行为；现有 REST reaction/comment 和本地操作路径不应依赖 SSE。

## Open Questions

- 当前账号 token 是否已有统一 refresh seam 可供长连接 401 后复用，还是第一版只断开并等待 session 恢复？
- 活跃 engagement memo set 应由 provider lifecycle 自动维护，还是由主页/详情显示层通过一个轻量注册 provider 暴露？两者都可行，但需要避免 feature widget 管理连接。
- 是否需要在设置或 debug 页面显示 SSE 连接状态？本 change 不需要，但未来排障可能有价值。
