## 1. 已有媒体缓存维护基础

- [x] 1.1 设计并实现 `application/maintenance` 媒体缓存维护 seam，提供媒体缓存分类、总量统计、批量清理结果和错误信息模型。
- [x] 1.2 为 `DefaultCacheManager` 图片网络缓存封装 adapter，删除使用 public `emptyCache()` API，大小统计通过隔离的 best-effort 路径实现。
- [x] 1.3 为 Flutter image memory cache 封装清理动作，避免设置 UI 直接引用 `PaintingBinding`。
- [x] 1.4 为 `VideoThumbnailCache` 增加维护 API，用于统计和清理 `video_thumbnails` 派生缓存，并清理内部 memory/file maps。
- [x] 1.5 为图片压缩临时缓存提供 allowlisted 统计/清理入口，确保不递归清理 broad support/temp/documents 目录。
- [x] 1.6 添加 media cache maintenance service、`VideoThumbnailCache` 维护 API、compression cache store 相关 focused tests。

## 2. 信息架构与入口迁移

- [x] 2.1 将设置首页用户可见入口从 `反馈` 调整为 `帮助与诊断`，保留现有 route/target 兼容性。
- [x] 2.2 将 `FeedbackScreen` 的页面标题和语义调整为 `帮助与诊断`，保留导出日志、自助修复、如何反馈路径。
- [x] 2.3 在 `帮助与诊断` 页面新增 `存储空间` navigation entry，点击后进入独立 `StorageSpaceScreen`。
- [x] 2.4 从 `SelfRepairScreen` 移除媒体缓存清理按钮、媒体缓存总量行和媒体缓存分类行。
- [x] 2.5 更新 `SelfRepairScreen` 自助修复副标题和说明，使其只描述标签、搜索、统计等本地修复动作。

## 3. 存储空间 summary seam

- [x] 3.1 新增或扩展 `application/maintenance` 下的 storage-space summary models，表达 MemoFlow 已知占用总量、分类大小、设备容量可用性和错误状态。
- [x] 3.2 新增 read-only memo/attachment storage summary seam，用于统计 memo content bytes 和 attachment metadata 分类大小；不得在 settings widget 中解析 memo rows 或 attachment JSON。
- [x] 3.3 定义附件分类规则：image、video、audio、file，并覆盖 missing size、unknown mime/extension、duplicate attachment identity 的确定性处理。
- [x] 3.4 新增可选 `DeviceStorageCapacityAdapter` seam，支持平台容量不可用时返回 unavailable；首版不得依赖其它 App 占用统计。
- [x] 3.5 新增或迁移 `state/maintenance` controller/provider，负责加载 storage summary、运行缓存清理、刷新 summary、处理 busy/partial-failure/success 状态。

## 4. 存储空间 UI

- [x] 4.1 新增 `StorageSpaceScreen`，页面标题为 `存储空间` / `Storage Space`，使用现有 settings page/seam 样式。
- [x] 4.2 页面展示 MemoFlow 已知占用总量；设备容量可用时显示 MemoFlow 占设备容量百分比，容量不可用时优雅降级。
- [x] 4.3 页面展示分类行：缓存、笔记内容、笔记图片、笔记视频、笔记音频、笔记文件。
- [x] 4.4 仅 `缓存` 行展示清理按钮；笔记内容和附件分类不得展示主动清理按钮。
- [x] 4.5 缓存清理确认弹窗明确不会删除笔记、账号、附件源文件、偏好设置、WebDAV 备份、待同步队列或远端服务器数据。
- [x] 4.6 复用或迁移现有清理 busy 和 snackbar/result 模式，覆盖成功、失败、部分失败和取消路径。
- [x] 4.7 页面不得展示其它 App 已用空间、缓存图库、逐图选择、URL 选择、按图删除或 per-attachment cleanup controls。

## 5. 本地化与文案

- [x] 5.1 为 `帮助与诊断`、`存储空间`、MemoFlow 已知占用、设备容量不可用、缓存/笔记分类、只展示说明和清理结果补充 `strings*.i18n.yaml` 文案。
- [x] 5.2 更新 `msg_self_repair_subtitle` 或相关说明，移除媒体缓存语义。
- [x] 5.3 重新生成 `strings.g.dart`，并检查中文写入路径使用 UTF-8 安全编辑方式。

## 6. 测试与 Guardrail

- [x] 6.1 添加 storage-space summary service 单元测试，覆盖 MemoFlow 已知占用总量、分类汇总、missing size、duplicate identity、device capacity unavailable。
- [x] 6.2 添加 storage-space controller/provider 测试，覆盖加载、清理、刷新、部分失败和错误状态。
- [x] 6.3 更新 `SelfRepairScreen` widget tests，验证自助修复页不再展示媒体缓存清理按钮或媒体缓存分类行。
- [x] 6.4 添加 `Help & Diagnostics` widget tests，验证设置首页入口名称、`存储空间` 入口和导航路径。
- [x] 6.5 添加 `StorageSpaceScreen` widget tests，验证 MemoFlow 已知占用、分类行、容量不可用降级、确认后调用 cache provider、取消不调用 provider。
- [x] 6.6 添加或扩展 architecture guardrail，禁止 `self_repair_screen.dart` / `storage_space_screen.dart` 直接拥有 cache manager、filesystem traversal、`path_provider`、DB persistence helper、platform capacity internals 或 media cache helper internals。
- [x] 6.7 验证不会新增 `state -> features`、`application -> features`、`core -> state|application|features` 反向依赖。

## 7. 验证

- [x] 7.1 运行 focused maintenance tests：media cache、storage-space summary、storage-space controller。
- [x] 7.2 运行 focused widget tests：help diagnostics、self repair、storage space。
- [x] 7.3 运行架构测试：`flutter test test/architecture --reporter expanded`。
- [ ] 7.4 运行完整本地检查：在 `memos_flutter_app` 执行 `flutter analyze` 和 `flutter test`。
