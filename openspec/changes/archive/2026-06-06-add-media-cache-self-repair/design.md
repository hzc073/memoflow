## Context

GitHub issue `hzc073/memoflow#207` 指向的是媒体缓存长期增长后的空间释放问题。当前实现已经建立了媒体缓存维护 seam：

```text
state/maintenance/self_repair_media_cache_controller.dart
        │
        ▼
application/maintenance/media_cache_maintenance_service.dart
        ├─ DefaultCacheManager network image cache
        ├─ Flutter image memory cache
        ├─ VideoThumbnailCache
        └─ CompressionCacheStore temporary cache
```

这些 seam 可以继续复用，但产品入口需要从 `Self Repair` 调整为更直观的存储诊断路径：

```text
设置
  └─ 帮助与诊断
       ├─ 存储空间
       ├─ 导出日志
       ├─ 自助修复
       └─ 如何反馈
```

新 `Storage Space` 页面只统计 MemoFlow 已知占用，不统计其它 App 已用空间，也不试图复刻系统存储设置页。MemoFlow 占设备容量百分比依赖平台容量 adapter；若平台能力不可用，页面应降级为只展示 MemoFlow 已知占用和分类。

架构阶段为 `evolve_modularity`。该改动触碰设置 UI、state maintenance seam、application/core cache helpers、SQLite 统计读取和可选平台容量读取，必须避免新增 `state -> features`、`application -> features`、`core -> state|application|features` 依赖，并避免把缓存目录扫描、DB 汇总或平台能力读取放进 settings widget。

## Goals / Non-Goals

**Goals:**

- 将设置首页入口展示名从 `反馈` 调整为 `帮助与诊断`。
- 在 `帮助与诊断` 页面新增 `存储空间` 入口。
- 将所有缓存清理按钮移入独立 `Storage Space` 页面；`Self Repair` 页面不再直接展示媒体缓存清理按钮或媒体缓存分类大小。
- 在 `Storage Space` 页面展示 MemoFlow 已知占用总量和分类大小。
- 分类至少包括：

```text
MemoFlow known usage
  ├─ Cache
  ├─ Note content
  ├─ Note images
  ├─ Note videos
  ├─ Note audio
  └─ Note files
```

- 仅 `Cache` 分类提供主动清理按钮；笔记正文和附件分类只展示占用。
- 支持 Windows 和 macOS 当前平台；设计上保留 Android 和 iOS 的平台容量 adapter 扩展点。
- 清理安全的媒体派生缓存，包括网络图片缓存、Flutter image memory cache、视频缩略图缓存、图片压缩临时缓存。
- 通过 reusable seam 承载统计与清理逻辑，设置 UI 只负责文案、布局、确认、busy state 和结果反馈。

**Non-Goals:**

- 不统计或展示其它 App 已用空间。
- 不提供系统存储管理能力，也不跳转系统 App storage 页面。
- 不提供缓存图片浏览、缓存图库、逐张选择、按 URL 删除、按来源 memo 删除。
- 不在 `Storage Space` 页面主动删除笔记正文、附件源文件、LocalLibrary 源文件、WebDAV 备份、待同步队列或远端服务器数据。
- 不改变图片加载和预览的 cache policy，不调小 `DefaultCacheManager` 默认容量；这些属于后续增长控制阶段。
- 不触碰 Memos API route/version compatibility，不引入商业/private hook 行为。

## Decisions

### 1. `反馈` 展示名调整为 `帮助与诊断`

现有 `FeedbackScreen` 实际包含日志导出、自助修复、问题反馈等诊断能力，不只是反馈。将设置首页入口和页面标题展示为 `帮助与诊断` 更符合新增 `存储空间` 的语义。

实现上可以保留内部文件名、route target 或 enum 名称（例如 `FeedbackScreen`、`DesktopSettingsWindowTarget.feedback`）以减少迁移风险，但用户可见文案必须使用 `帮助与诊断`。旧的 desktop/macOS target 继续打开同一页面，不需要因为命名调整破坏兼容。

### 2. `Storage Space` 是 `帮助与诊断` 下的独立页面

媒体缓存清理不是异常修复本身，而是空间诊断/释放动作。新页面承载总览、分类和清理按钮：

```text
Help & Diagnostics
  ├─ Storage Space  ─────▶  Storage Space
  ├─ Export Logs
  ├─ Self Repair
  └─ How to report?
```

`SelfRepairScreen` 只保留：

```text
Self Repair
  ├─ Repair abnormal tags
  ├─ Rebuild search index
  └─ Rebuild stats cache
```

### 3. MemoFlow 已知占用由 app 数据 seam 计算

`Storage Space` 页面展示的 MemoFlow 已知占用不依赖其它 App 统计。建议引入上层 summary seam：

```text
features/settings/storage_space_screen.dart
        │ rendering / user intent only
        ▼
state/maintenance/storage_space_controller.dart
        │ Riverpod state, loading, clearing, refresh
        ▼
application/maintenance/storage_space_summary_service.dart
        │ known usage aggregation
        ├─ MediaCacheMaintenanceService
        ├─ AppDatabase / DB facade read-only summary
        └─ DeviceStorageCapacityAdapter optional platform capacity
```

`storage_space_summary_service` 负责组合：

- `cacheBytes`: 现有媒体缓存 summary 的总量。
- `noteContentBytes`: 本地 memo 正文的 UTF-8 byte 估算。
- `noteImageBytes`: attachment metadata 中图片类附件 size 汇总。
- `noteVideoBytes`: attachment metadata 中视频类附件 size 汇总。
- `noteAudioBytes`: attachment metadata 中音频类附件 size 汇总。
- `noteFileBytes`: 其它文件/文档类附件 size 汇总。

`knownTotalBytes` 为上述分类总和。该值代表 MemoFlow 可解释的已知占用，而不是系统层 app sandbox 总占用。

### 4. 设备容量只作为可选分母

为了支持 Windows、macOS、未来 Android 和 iOS，设备容量通过 adapter 隔离：

```text
DeviceStorageCapacityAdapter
  ├─ Windows adapter
  ├─ macOS adapter
  ├─ Android adapter
  └─ iOS adapter
```

adapter 输出建议只包含当前 app data 所在 volume 的 `totalBytes` 和可选 `availableBytes`。页面只需要用 `knownTotalBytes / totalBytes` 计算 MemoFlow 占比。若 adapter 未实现、平台不支持或读取失败：

- 页面继续展示 MemoFlow 已知占用。
- 页面不展示其它 App 分段。
- 占比文案降级为“设备容量不可用”或不显示百分比。
- 分类列表和缓存清理仍可用。

该设计避免在首版引入跨平台系统存储扫描，同时为 Android/iOS 留出平台适配点。

### 5. 附件分类采用 metadata，不扫描源文件

笔记图片/视频/音频/文件大小使用本地 memo/attachment metadata 中的 `size` 字段汇总，分类依据现有 `Attachment` 类型判断能力或等价的 application/data 层 helper。不要在设置 widget 中解析 attachment JSON。

大小口径是估算：

- 如果 attachment size 为 `0` 或缺失，则该附件对已知占用贡献 `0`。
- 远端附件、LocalLibrary 文件、待同步附件可能与系统实际占用不同，页面文案应使用“MemoFlow 已知占用”。
- 同一附件如果在 memo JSON 和 attachment 表之间重复出现，必须由 summary service 选择一个稳定数据源或按 attachment identity 去重，避免明显重复统计。

### 6. 清理按钮只属于 `Cache`

截图里的 `笔记图片`、`笔记视频`、`笔记音频`、`笔记文件` 表示用户内容或附件源文件，不应提供“清理”按钮。它们可以说明：

```text
不可主动清理，删除关联笔记后会随记录删除或同步删除
```

`Cache` 行可以提供 `清理` 按钮，触发现有 `MediaCacheMaintenanceService.clearAll()`。清理前确认文案必须明确不会删除笔记、账号、附件源文件、偏好设置、WebDAV 备份、待同步队列或远端服务器数据。

### 7. `Self Repair` 与存储空间共享 seam，但不共享 UI 责任

当前 `SelfRepairMediaCacheController` 的职责需要迁移或泛化。可选路径：

- 重命名/迁移为 `StorageSpaceController`，由 `StorageSpaceScreen` 使用。
- 保留 provider 内部名称但只由 `StorageSpaceScreen` 使用，后续再清理命名。

无论选择哪条路径，`SelfRepairScreen` 不再渲染媒体缓存大小、不再触发媒体缓存清理。

## UI Sketch

```text
┌──────────────────────────────┐
│ <        存储空间             │
├──────────────────────────────┤
│ MemoFlow 已知占用             │
│ 4.44 MB                      │
│ MemoFlow 占用设备容量不足 1%  │
│                              │
│ ┌──────────────────────────┐ │
│ │ 缓存              清理    │ │
│ │ 21.26 KB                 │ │
│ │ 临时数据，清理不影响使用  │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ 笔记内容                 │ │
│ │ 1.09 MB                  │ │
│ │ 笔记文字等内容大小       │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ 笔记图片                 │ │
│ │ 3.33 MB                  │ │
│ │ 不可主动清理             │ │
│ └──────────────────────────┘ │
│ ...                          │
└──────────────────────────────┘
```

顶部条形图只表达 MemoFlow 已知占用，不展示其它 App 已用分段。若设备容量不可用，则显示分类占比或简化为 MemoFlow 已知占用卡片。

## Risks / Trade-offs

- [Risk] `knownTotalBytes` 与系统设置里的 app storage 不一致。  
  [Mitigation] 文案使用“MemoFlow 已知占用”，不声称等于系统 app storage。

- [Risk] 平台容量 adapter 在 Windows/macOS/Android/iOS 实现差异大。  
  [Mitigation] 容量分母可选；读取失败不影响分类和清理。

- [Risk] 附件 metadata 可能缺 size 或存在重复来源。  
  [Mitigation] summary service 统一选择数据源/去重规则，并通过单元测试覆盖缺失、重复、分类边界。

- [Risk] 清理正在被 image widget 使用的缓存文件可能导致当前图片短暂重载或显示占位。  
  [Mitigation] 清理前确认，清理后同时清内存 image cache；用户重新进入页面时图片可重新下载/生成。

- [Risk] 在 `evolve_modularity` 下，快速实现容易把 DB 汇总或平台容量读取塞进 UI。  
  [Mitigation] 增加架构 guardrail，禁止 `storage_space_screen.dart` 和 `self_repair_screen.dart` 直接导入 cache manager、path provider、`dart:io` 目录扫描、DB persistence helper 或平台容量 internals。

## Migration Plan

1. 更新帮助诊断/自助修复/存储空间的 OpenSpec 规则和测试预期。
2. 引入或调整 `storage_space_summary_service` 和 controller，复用现有 media cache maintenance seam。
3. 扩展 read-only DB summary 能力，统计 memo content 与 attachment metadata 分类大小。
4. 新增 `StorageSpaceScreen`，将缓存清理确认、busy state、结果反馈迁移到该页面。
5. 更新 `FeedbackScreen` 的展示名和入口列表，新增 `Storage Space` 导航，移除 `SelfRepairScreen` 中媒体缓存清理 UI。
6. 更新本地化文案、widget tests、service tests 和 architecture guardrail。
7. 跑 focused tests、`flutter analyze` 和 `flutter test`。

该 change 不需要数据迁移。回滚策略是移除 `Storage Space` 入口并恢复 `SelfRepairScreen` 媒体缓存清理入口；已有缓存文件仍可由系统或 cache manager 后续自然清理。
