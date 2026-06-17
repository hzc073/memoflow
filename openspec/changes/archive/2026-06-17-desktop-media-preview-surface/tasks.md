## 1. 范围确认与入口清单

- [x] 1.1 盘点所有媒体预览入口，包括 `ImagePreviewLauncher.open` 调用点、`AttachmentGalleryScreen`、`AttachmentVideoScreen`、inline compose pending attachment、memo editor、memo reader/detail、markdown inline image、share/comment/explore 临时图片预览。
- [x] 1.2 明确第一阶段桌面窗口 platform gate：记录 macOS、Windows、Linux 哪些平台启用独立媒体窗口，哪些平台先走沉浸式 fallback。
- [x] 1.3 明确桌面媒体窗口实例策略：同一主窗口只保留一个 active media window，或允许多个独立 media windows，并把选择写入实现备注或测试命名。
- [x] 1.4 确认本 change 不触碰 `memos_flutter_app/lib/data/api`、`memos_flutter_app/test/data/api`、数据库 schema、sync protocol 或商业/private overlay 代码。

## 2. 媒体请求与结果边界

- [x] 2.1 设计并实现可序列化 `DesktopMediaPreviewRequest` / `DesktopMediaPreviewResult` 或等价 codec，覆盖媒体项、初始 index、source metadata、mime type、尺寸、auth/local file 信息、download/edit/replace capability。
- [x] 2.2 为 codec 增加 focused tests，覆盖本地文件、远程 URL、private attachment、pending attachment、空媒体列表和无 edit/replace capability。
- [x] 2.3 将 edit/replace result handoff 设计为 request-correlated result，由主窗口或原 feature owner 应用 `ImagePreviewEditResult` / 等价结果。
- [x] 2.4 增加 stale-source 校验或复用现有 preview source freshness helper，确保桌面媒体 request 不引用已删除 queued upload source。

## 3. 集中打开入口

- [x] 3.1 新增或扩展 feature-level media preview presenter/launcher，让桌面与移动分流集中在一个入口。
- [x] 3.2 保持移动端调用现有 fullscreen route 行为，不改变 phone/tablet 的返回按钮、手势和安全区行为。
- [x] 3.3 桌面端优先尝试独立 media window；打开失败或 platform gate disabled 时进入无普通 `AppBar` 的沉浸式 fallback。
- [x] 3.4 确保集中入口不新增 `state -> features`、`application -> features` 或 `core -> features` 反向依赖。

## 4. 桌面媒体 surface

- [x] 4.1 实现桌面 media window root 或等价 surface，渲染图片、视频和 mixed attachment preview 的基础内容。
- [x] 4.2 实现系统关闭语义：关闭 media window 只关闭媒体查看器，不关闭主窗口，不 pop 主窗口 route。
- [x] 4.3 实现 `Esc` 关闭 active media surface，并确保不清理无关 memo draft、pending attachment、preview selection 或 editor state。
- [x] 4.4 移除桌面媒体 root 的普通 `AppBar`、App-level Back 和 `Back + Page Title` chrome。
- [x] 4.5 实现媒体查看器控件：页码、上一项/下一项、缩放/重置、下载、编辑/替换、加载和错误状态。
- [x] 4.6 macOS 顶部或左上控件使用 shared `DesktopWindowChromeSafeArea` 或等价 window-root wrapper，避免 traffic lights/titlebar hit area。
- [x] 4.7 实现 main-window immersive fallback 的 viewer-specific close affordance 和 `Esc` 关闭，且不恢复旧左上 AppBar Back。

## 5. 入口迁移

- [x] 5.1 迁移 `memos_flutter_app/lib/features/image_preview/**` 的桌面打开路径到集中 media preview presenter。
- [x] 5.2 迁移 `MemoImageGrid`、memo detail/reader、memo markdown inline image 和 memo card media entry 的桌面图片预览入口。
- [x] 5.3 迁移 `AttachmentGalleryScreen` 纯图片和 mixed image/video 路径，确保桌面端不再直接显示普通 AppBar gallery。
- [x] 5.4 迁移视频预览入口，确保桌面视频查看也走同一 media surface model。
- [x] 5.5 迁移 memo editor 和 inline compose pending attachment 预览，保持 edit/replace result 由原 owner 应用。
- [x] 5.6 审计 share/comment/explore 中的临时图片预览入口；能复用统一 media presenter 的入口完成迁移，暂不能迁移的入口记录原因和后续任务。

## 6. 测试与 guardrails

- [x] 6.1 增加桌面图片预览 widget/presenter tests，断言桌面端不渲染普通 `AppBar` Back，且打开 dedicated media surface 或 fallback viewer。
- [x] 6.2 增加桌面视频和 mixed attachment preview tests，覆盖与图片相同的 media surface 打开模型。
- [x] 6.3 增加 macOS chrome safe-area test，验证媒体 viewer 顶部/左上控件不进入 `kMacosTrafficLightReservedWidth` 区域。
- [x] 6.4 增加 `Esc` 和 native close result tests，覆盖关闭 media surface 后主窗口、draft、pending attachment 和 preview selection 不被误清理。
- [x] 6.5 增加 mobile/tablet regression tests，确认现有 fullscreen route 和平台返回行为保持不变。
- [x] 6.6 增加 architecture guardrail，防止桌面媒体入口重新直接 push `ImagePreviewGalleryScreen`、`AttachmentGalleryScreen` 或桌面视频 route。
- [x] 6.7 增加 commercial/public-shell scan 或复用现有 guardrail，确认本 change 未引入 subscription、billing、entitlement、StoreKit、paywall 或 private overlay 逻辑。

## 7. 验证与收尾

- [x] 7.1 在 `memos_flutter_app` 运行 targeted widget/unit tests，至少覆盖 `test/features/image_preview`、相关 `test/features/memos` 媒体预览测试和新增 architecture guardrail。
- [x] 7.2 在 `memos_flutter_app` 运行 `flutter analyze`。
- [x] 7.3 在 `memos_flutter_app` 运行 `flutter test`，如环境限制导致无法完成，记录失败原因和已完成的 focused tests。
- [ ] 7.4 手动或截图 smoke macOS 桌面：打开单张图片、多图、视频和 pending attachment，确认无左上 App 返回与系统按钮重叠，系统关闭和 `Esc` 均能关闭媒体查看器。
- [x] 7.5 检查 staged/unstaged changes，确认没有 API adapter、付费功能、private overlay 或无关 OpenSpec 归档内容混入本 change。
