## 1. 准备与边界确认

- [ ] 1.1 确认 `add-memos-029-api-adapter` 的实现基线已合入或当前分支包含最新 `MemoApiVersion` / `MemoApiFacade` 行为。
- [ ] 1.2 在编辑 `memos_flutter_app/lib/data/api/**` 或 `memos_flutter_app/test/data/api/**` 前取得用户对 API 相关代码变更的显式批准。
- [ ] 1.3 梳理现有 `memoEngagementControllerProvider` 生命周期和主页/详情 engagement 挂载路径，确定活跃 memo uid 的 state-owned 注册或枚举方案。

## 2. SSE API 与事件解析

- [ ] 2.1 新增或扩展 Memos live refresh event model，覆盖 `memo.created`、`memo.updated`、`memo.deleted`、`memo.comment.created`、`reaction.upserted`、`reaction.deleted`、`name` 和可选 `parent`。
- [ ] 2.2 实现 `/api/v1/sse` stream client，请求包含 `Accept: text/event-stream` 与 `Authorization: Bearer <token>`，并将 0.27+ 服务器作为可选 capability gate。
- [ ] 2.3 实现 SSE line/parser 逻辑，忽略 `:` heartbeat/comment，解析 `data:` JSON，安全跳过 malformed payload。
- [ ] 2.4 为 SSE client/parser 添加 focused tests，覆盖 header、heartbeat 忽略、事件解析、malformed JSON、401/404/unsupported 降级行为。

## 3. Engagement Live Refresh State

- [ ] 3.1 新增 live refresh coordinator/provider，使 typed SSE events 不经过 widget 即可映射到 memo engagement refresh。
- [ ] 3.2 为 `reaction.upserted` 和 `reaction.deleted` 触发目标 memo 的 reactions `force` refresh。
- [ ] 3.3 为 `memo.comment.created` 触发目标 memo 的 comments `force` refresh。
- [ ] 3.4 实现短时间同 memo 事件合并或 in-flight 复用，避免多个 card 或连续事件造成重复请求风暴。
- [ ] 3.5 实现 SSE 重连成功后的活跃/可见 engagement 补偿刷新，范围限制在当前活跃 memo uid set。

## 4. Session 与生命周期接入

- [ ] 4.1 在账号登录且版本支持 SSE 时启动 live refresh 连接；账号切换、退出或 token 缺失时停止连接并清理订阅。
- [ ] 4.2 处理 SSE 断线与指数退避重连，确保连接失败不阻断主页 memo 卡片的普通 engagement 加载。
- [ ] 4.3 明确 401 处理策略：复用现有 token refresh seam 或断开等待 session 恢复，并添加对应测试。
- [ ] 4.4 保持 `toggleLike()` 和 `createComment()` 的本地乐观更新体验，收到自己触发的 SSE 后仅作为服务端权威状态校正。

## 5. 模块化与 UI 边界

- [ ] 5.1 确保 `MemoEngagementSurface`、主页 memo card 和 `MemoDetailScreen` 不解析 SSE、不管理长连接、不持有重连策略。
- [ ] 5.2 确保新增 data/state/application seam 不引入新的 `state -> features`、`application -> features` 或 `core -> state|application|features` imports。
- [ ] 5.3 为 live refresh 映射或边界添加 provider-level 测试或 architecture guardrail 覆盖，证明可复用逻辑未隐藏到 widget 文件中。

## 6. 验证

- [ ] 6.1 添加 provider/unit tests：reaction event 会刷新点赞状态，comment event 会刷新评论状态，偏好关闭时不让主页 engagement UI 因事件变为可见。
- [ ] 6.2 添加 widget 或 integration-style test：主页 memo card 在 provider 被 live refresh 更新后显示新的 like count/comment preview。
- [ ] 6.3 从 `memos_flutter_app` 运行相关 focused tests，至少覆盖新增 SSE/API tests 和 engagement provider/widget tests。
- [ ] 6.4 从 `memos_flutter_app` 运行 `flutter analyze`。
- [ ] 6.5 如本变更触及 API route/version 兼容路径，运行 `flutter test test/data/api --reporter expanded`。
- [ ] 6.6 检查变更不包含 private/commercial/paywall/billing/subscription 相关代码或状态。
