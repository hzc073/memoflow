## Why

GitHub issue `hzc073/memoflow#207` 反馈图片浏览缓存会长期占用本地空间。已有实现已经完成媒体派生缓存统计与清理的基础能力，但入口放在 `Settings -> Feedback -> Self Repair -> Clear media cache` 下，路径偏深且语义更像故障修复。

新的产品方向是把空间释放能力调整为独立的存储诊断页面：入口路径为 `设置 -> 帮助与诊断 -> 存储空间`。该页面聚焦 MemoFlow 自身已知占用及其分类，不统计或展示其它 App 占用。

## What Changes

- 将设置首页原 `反馈` 入口的展示名称调整为 `帮助与诊断`，保留日志导出、自助修复和反馈路径。
- 在 `帮助与诊断` 页面新增 `存储空间` 入口，点击后进入单独的 `Storage Space` 页面。
- 将媒体缓存清理按钮从 `Self Repair` 页面移入 `Storage Space` 页面；`Self Repair` 只保留标签、搜索、统计等本地派生数据修复动作。
- `Storage Space` 页面展示 MemoFlow 已知占用总量、MemoFlow 占设备容量百分比（平台能力可用时）、缓存大小、笔记正文大小、笔记图片/视频/音频/文件大小。
- `Storage Space` 不统计其它 App 已用空间，也不展示“其它 App 已用”分段；设备容量不可用时，页面仍展示 MemoFlow 已知占用和分类。
- 仅 `缓存` 分类提供主动清理按钮；笔记正文和附件分类只展示占用，不提供主动删除按钮。
- 继续复用现有媒体缓存维护 seam 清理安全的派生缓存，不删除笔记、账号、附件源文件、偏好设置、WebDAV 备份、待同步队列或远端服务器数据。
- 本 change 不调整 Memos API，不改变附件上传、同步、账号离线数据、WebDAV 备份或商业/private hook 行为。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `self-repair-tools`: 自助诊断入口调整为 `帮助与诊断`，新增独立 `存储空间` 页面，媒体缓存清理动作从 `Self Repair` 页面迁移到该页面。

## Impact

- 影响 Flutter 设置/帮助诊断 UI：`memos_flutter_app/lib/features/settings/feedback_screen.dart` 的展示语义改为 `帮助与诊断`，并新增 `Storage Space` 页面入口。
- 影响自助修复 UI：`memos_flutter_app/lib/features/settings/self_repair_screen.dart` 移除媒体缓存清理动作与媒体缓存大小行，仅保留修复动作。
- 影响状态/应用层维护 seam：预计新增或扩展 `state/maintenance` 与 `application/maintenance` 下的存储空间 summary service/controller，组合媒体缓存、SQLite memo content、attachment metadata 和可选平台设备容量 adapter。
- 影响媒体缓存相关代码：继续复用现有 `MediaCacheMaintenanceService` / target allowlist 清理图片网络缓存、Flutter image memory cache、视频缩略图缓存和图片压缩临时缓存。
- 影响本地化文案和测试：新增 `帮助与诊断`、`存储空间`、MemoFlow 已知占用、缓存/笔记分类、设备容量不可用、清理结果等文案；更新 widget tests 和架构 guardrail。
- 当前架构阶段为 `evolve_modularity`。本 change 触及 checklist `1`/`2`/`3` 的依赖方向风险和 `4` 的共享逻辑归属风险，必须通过 reusable seam 和 guardrail 保证不新增 `state -> features`、`application -> features`、`core -> state|application|features` 依赖，也不能把缓存扫描、SQLite 汇总或平台容量读取逻辑藏在 screen/widget 文件中。
