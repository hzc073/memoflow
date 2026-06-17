## Context

当前图片预览入口大多通过 `ImagePreviewLauncher.open()` push 到主窗口 route，`ImagePreviewGalleryBody` 在普通预览路径里渲染黑色 `Scaffold` 和 `AppBar`。在 macOS 主窗口启用 transparent titlebar / full-size content 后，这个 `AppBar` 的左上返回按钮和页码会进入系统红黄绿窗口按钮附近，形成重叠。

现有桌面架构已经有几个相关边界：

- `desktop-window-chrome-safe-area` 负责窗口控件避让。
- `desktop-share-task-window` 已经定义过“独立任务窗口使用系统关闭语义”的模式。
- `desktop-memo-reader-surface` 把 memo 完整阅读从普通 route 收敛到桌面 reader surface。
- `memo-media-preview-source-freshness` 已约束媒体预览必须使用当前附件来源。

本 change 不把媒体查看器当作普通二级页面继续修补 `AppBar`，而是把桌面媒体预览提升为独立媒体查看 surface。移动端继续保留现有全屏 route 和平台返回行为。

当前处于 `evolve_modularity` 阶段，模块化评分仍为 `4/10`。本 change 会触及 `features/memos`、`features/image_preview` 和桌面窗口打开边界，必须避免新增 `state -> features`、`application -> features` 或 `core -> features` 依赖，并通过集中入口或 guardrail 让被触及区域不再继续分散。

## Goals / Non-Goals

**Goals:**

- 桌面端图片、视频和可预览附件通过独立媒体查看 surface 打开。
- 桌面媒体查看 surface 不显示普通 `AppBar`、App-level Back 或 `Back + Page Title`。
- 桌面媒体查看主要通过系统窗口关闭和 `Esc` 退出；主窗口保持打开。
- 媒体控件只表达查看器能力，例如页码、上一张/下一张、缩放、下载、编辑/替换。
- macOS 上媒体窗口或 fallback 查看器的可见控件不与 traffic lights 或 titlebar hit area 重叠。
- 手机和平板继续使用现有全屏查看页、返回按钮和手势。
- 收敛媒体打开入口，减少各个 widget 自己判断平台并 push route 的分散逻辑。

**Non-Goals:**

- 不改图片压缩、上传、下载、缓存刷新、LocalSync 或 WebDAV 行为。
- 不改 Memos API、数据库 schema、请求/响应模型、route adapters 或版本兼容。
- 不重写图片编辑器、视频播放器或 markdown 渲染器。
- 不把媒体查看做成普通 `AlertDialog` 弹窗作为主方案。
- 不引入商业、订阅、StoreKit、权益、paywall 或 private overlay 逻辑。

## Decisions

### 1. 桌面媒体查看器是独立 surface，不是普通二级页面

桌面端打开图片/视频时进入专用媒体查看 surface。该 surface 可以是独立桌面子窗口；如果平台窗口能力不可用，则使用主窗口内沉浸式 fallback，但仍不渲染普通 `AppBar` 和 App-level Back。

```text
Desktop main window                  Desktop media surface
┌──────────────────────┐             ┌──────────────────────┐
│ memo list / detail   │ --open-->   │ image / video viewer │
│ stays open           │             │ native close + Esc   │
└──────────────────────┘             └──────────────────────┘
```

Alternatives considered:

- 只把现有 `AppBar` 的返回按钮挪开。这个修复小，但仍把媒体预览当普通页面，后续视频/附件预览还会继续继承页面 chrome 问题。
- 做成普通弹窗。弹窗适合轻量查看，但不适合长图缩放、视频控制、左右切换、下载和编辑/替换。

### 2. 用集中 launcher/presenter 统一桌面与移动分流

新增或扩展 feature-level 媒体预览入口，例如 `DesktopMediaPreviewLauncher` / `MediaPreviewPresenter` 等等价 seam。现有 `MemoImageGrid`、`MemoDetailScreen`、`MemoEditorScreen`、inline compose、attachment gallery 和视频预览入口只提交媒体查看请求，不再各自决定桌面窗口、主窗口 route 或 AppBar 行为。

```text
Before
entry widget -> ImagePreviewLauncher -> root Navigator route
entry widget -> AttachmentGalleryScreen / video route

After
entry widget -> media preview presenter
              ├─ desktop supported -> desktop media window
              ├─ desktop unsupported -> immersive fallback viewer
              └─ mobile/tablet -> existing fullscreen route
```

依赖方向要求：

- `features/*` 可以依赖 feature-local presenter 和 lower-layer data models。
- `core` 只保留平台/chrome/window helper，不导入 feature UI。
- `state`、`application`、`core` 不新增对 `features/image_preview` 或 `features/memos` UI 的反向依赖。
- 如果实现必须扩展桌面窗口 manager，应通过已有 desktop window seam 或 serialization boundary 传递请求，不把媒体 UI 直接塞进 lower layer。

### 3. 桌面媒体窗口使用可序列化 request/result

现有 `ImagePreviewOpenRequest` 包含 callback，例如 `onReplace`，不能直接跨独立窗口传递。桌面媒体窗口应使用可序列化的 request/result：

- request 包含媒体项、初始 index、来源 metadata、认证/本地文件信息、是否允许下载/编辑等必要字段。
- 独立媒体窗口编辑或替换后返回 `ImagePreviewEditResult` 或等价 result。
- 主窗口继续拥有实际替换、pending attachment 更新、memo mutation 或 toast 提示。

这样可以保留现有所有权：媒体窗口负责查看和产生结果，主窗口/原 feature owner 负责写入状态。

### 4. 关闭语义优先使用系统窗口关闭和 `Esc`

独立媒体窗口 root 不显示普通返回按钮。用户关闭媒体窗口时：

- macOS red close、Windows/Linux window close、`Cmd+W` / `Alt+F4` 等系统关闭动作关闭媒体窗口。
- `Esc` 关闭当前媒体 surface。
- 关闭媒体窗口不关闭主窗口，不 pop 主窗口 route，不清理无关草稿。

主窗口内沉浸式 fallback 没有独立系统窗口，因此必须提供 `Esc` 和一个安全的查看器关闭 affordance，但它仍不能是普通 `Back + Page Title` AppBar。

### 5. 媒体 chrome 只服务查看，不承担普通页面导航

桌面媒体 surface 可以显示媒体查看器控件，例如：

- `1/5` 页码或文件名的轻量状态。
- 左右切换、缩放重置、下载、编辑/替换。
- 加载、失败、无可用媒体状态。

这些控件应根据平台窗口控件避让规则放置。macOS 上如果控件出现在顶部或左上区域，必须走 shared `DesktopWindowChromeSafeArea` 或等价 shell seam；不得在图片预览文件里硬编码 traffic-light padding。

### 6. 移动端保留现有全屏查看页面

手机和平板不引入桌面子窗口模型。移动端继续使用现有全屏 route、平台返回按钮、系统返回手势和安全区行为。桌面改造不应改变移动端图片/视频预览测试预期。

## Risks / Trade-offs

- [Risk] 独立窗口无法直接携带 Dart callback。 -> Mitigation: 使用 request/result codec，让主窗口保留 mutation owner。
- [Risk] 桌面窗口能力在不同平台不一致。 -> Mitigation: 通过平台 capability gate 启用；失败时进入沉浸式 fallback，而不是恢复普通 AppBar route。
- [Risk] 媒体预览入口分散，容易漏掉某个路径。 -> Mitigation: 先做入口清单，再把图片、视频、纯图片 gallery、混合附件 gallery 和 pending attachment 统一迁移到同一个 presenter。
- [Risk] `features/memos` 已是耦合热点，新增逻辑可能继续膨胀。 -> Mitigation: 把打开策略集中在小型 presenter/launcher，并增加 guardrail 防止入口重新直接 push `ImagePreviewGalleryScreen` 或 `AttachmentGalleryScreen`。
- [Risk] 编辑/替换结果跨窗口后出现 stale source 或错配。 -> Mitigation: request/result 携带 `sourceId`、当前附件 metadata 和 request id，由主窗口校验后再应用结果。
- [Risk] 用户找不到关闭入口。 -> Mitigation: 独立窗口依赖原生窗口关闭和 `Esc`；fallback 提供安全位置的查看器关闭 affordance，并补充键盘测试。

## Migration Plan

1. 盘点所有媒体预览入口：memo 图片网格、memo detail/reader、memo editor、inline compose pending attachment、attachment gallery、video preview、share/comment/explore 中的临时图片预览。
2. 建立媒体预览 request/result codec 和集中 presenter，先让现有移动 route 继续走原行为。
3. 增加桌面媒体窗口 root 和平台 capability gate；实现系统关闭、`Esc`、页码、左右切换和基础图片/视频显示。
4. 迁移桌面图片预览入口到独立媒体 surface；纯图片和混合附件 gallery 都不再直接显示普通 `AppBar`。
5. 接入编辑/替换/下载 result handoff，确保 pending attachment 和已保存 memo 的写入仍由原 owner 处理。
6. 添加 focused widget tests、route/presenter tests 和 architecture guardrails。
7. 如桌面窗口能力出现运行时问题，可临时关闭 capability gate，使桌面端使用沉浸式 fallback；不得回退到带普通左上返回按钮的 `AppBar` 页面。

## Open Questions

- 第一阶段是否同时启用 Windows 和 macOS 独立媒体窗口，还是先启用 macOS，Windows/Linux 走 capability gate 后续打开？
- 独立媒体窗口是每次打开都创建新窗口，还是同一主窗口只保持一个 active media window 并在新请求时替换/聚焦？
- pending attachment 的编辑/替换是否必须在第一阶段跨窗口完整支持，还是允许这类可编辑 pending preview 先走沉浸式 fallback，待 result channel 稳定后再进入独立窗口？
