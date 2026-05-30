# Secondary Page Inventory

## 扫描范围

本清单用于任务 1.3 / 1.4。扫描范围覆盖 `memos_flutter_app/lib` 下与二级页面和桌面 chrome 相关的入口：

- 路由入口：`Navigator.push`、`Navigator.pushAndRemoveUntil`、`buildPlatformPageRoute`、`MaterialPageRoute`、`fullscreenDialog`
- 页面容器：`Scaffold + AppBar`、`PlatformPage`、`desktopWindowChromeSafeArea`
- 临时表面：`showDialog`、`showGeneralDialog`、`showPlatformDialog`、`showPlatformAlertDialog`、`showModalBottomSheet`、`showWindowsAdaptiveSurface`
- 桌面 chrome：`resolveDesktopRouteAutomaticallyImplyLeading`、`resolveDesktopRouteDismissalLeading`、`DragToMoveArea`、`window_chrome_safe_area`

分类规则：

- `needs-migration`: 桌面端任务型二级流程，适合迁移到共享桌面任务表面，或已确认会触发当前窗口控制遮挡问题。
- `keep-full-page`: 阅读、详情、预览、长内容、沉浸式或导航型页面，应保持完整页面；若有 chrome 风险，后续用安全 page chrome seam 修。
- `needs-review`: 历史页面或混合型流程，可能适合桌面任务表面，但本 change 不应直接大范围迁移。
- `out-of-scope`: 已是 dialog/sheet/popover、顶层 destination、专用子窗口、启动/锁屏/登录等不属于本次二级任务页面迁移的入口。

## needs-migration

这些是本 change 首批或明确后续需要修改的页面。

| 页面/入口 | 当前呈现方式 | 未保存保护 | 桌面窗口控制风险 | 判断 |
| --- | --- | --- | --- | --- |
| `memos_flutter_app/lib/features/collections/collection_editor_screen.dart` `CollectionEditorScreen` | `PopScope` + `Scaffold` + `AppBar` + `bottomNavigationBar`，由 `collections_screen.dart` 和 reader more actions push | 有，`_hasUnsavedChanges` + `_requestClose` | 高。macOS 主窗口二级 route 上 AppBar 左侧返回键可能进入 traffic lights 区域 | 创建/编辑合集是短任务，应迁移到共享桌面任务表面 |
| `memos_flutter_app/lib/features/collections/add_to_collection_sheet.dart` 创建手动合集分支 | Windows 先打开 `showWindowsAdaptiveSurface`，再 `MaterialPageRoute` push `CollectionEditorScreen` | 依赖 `CollectionEditorScreen` | 高。桌面弹窗内继续 push 完整页面会回到同一遮挡问题 | 应改为复用共享桌面任务表面打开手动合集创建 |
| `memos_flutter_app/lib/features/collections/collection_reader_screen.dart` 空手动合集的“编辑合集”按钮 | `PlatformPage` 内 push `CollectionEditorScreen` | 依赖 `CollectionEditorScreen` | 高。入口本身安全，但目标页面有风险 | 应改为桌面任务表面入口 |
| `memos_flutter_app/lib/features/collections/collection_reader_shell.dart` `editCollection` / `manageCollectionItems` | reader more menu 里 push `CollectionEditorScreen` 或 `ManualCollectionManageScreen` | `CollectionEditorScreen` 有；`ManualCollectionManageScreen` 无显式未保存确认 | 高。编辑合集目标页面有风险；管理条目是任务型页面 | 编辑合集应迁移；管理条目是否同批见 `needs-review` |
| `memos_flutter_app/lib/features/collections/collections_screen.dart` `_openEditor` | top-level collections destination push `CollectionEditorScreen` | 依赖 `CollectionEditorScreen` | 高。当前用户反馈入口 | 首批必须迁移 |
| `memos_flutter_app/lib/features/collections/collection_article_flow_screen.dart` 空文章流的“编辑合集”按钮 | `MaterialPageRoute` push `CollectionEditorScreen` | 依赖 `CollectionEditorScreen` | 高。入口位于阅读型 full-page 内，但目标是任务型编辑页 | 入口应改为共享桌面任务表面；文章流本身继续保持 full-page |
| `memos_flutter_app/lib/features/collections/manual_collection_manage_screen.dart` `ManualCollectionManageScreen` | `Scaffold + AppBar`，reader more menu push | 无显式未保存确认；操作即时写入 repository | 中到高。任务型管理页面，AppBar 可能进入 traffic lights 区域 | 任务 1.5 确认纳入首批，同步迁移到共享桌面任务表面 |

明确“需要修改”的首批页面：

- `memos_flutter_app/lib/features/collections/collection_editor_screen.dart`
- `memos_flutter_app/lib/features/collections/collections_screen.dart`
- `memos_flutter_app/lib/features/collections/add_to_collection_sheet.dart`
- `memos_flutter_app/lib/features/collections/collection_reader_screen.dart`
- `memos_flutter_app/lib/features/collections/collection_reader_shell.dart`
- `memos_flutter_app/lib/features/collections/collection_article_flow_screen.dart`
- `memos_flutter_app/lib/features/collections/manual_collection_manage_screen.dart`

## needs-review

这些页面或入口符合“任务型”特征或存在 page-local AppBar，但迁移范围和交互需要后续确认；本 change 只在 1.5 后决定是否纳入同批。

| 页面/入口 | 当前呈现方式 | 未保存保护 | 桌面窗口控制风险 | 判断 |
| --- | --- | --- | --- | --- |
| `memos_flutter_app/lib/features/collections/collection_editor_screen.dart` `_ManualMemoPickerScreen` | 内部 `MaterialPageRoute(fullscreenDialog: true)` + `Scaffold + AppBar` | 选择结果提交，未提交可取消 | 中。是创建合集里的子任务；迁移外层后仍可能在桌面任务里再 push 页面 | 建议在迁移 `CollectionEditorScreen` 时改为任务表面内嵌 picker、nested task surface 或桌面 dialog |
| `memos_flutter_app/lib/features/settings/shortcut_editor_screen.dart` | `Scaffold + AppBar`，leading 是 `Cancel` 文本，actions 是保存 | 有任务型编辑语义；未见复杂未保存保护 | 中。典型短任务，但属于 settings 历史范围 | 适合后续迁移，不纳入 collections 首批 |
| `memos_flutter_app/lib/features/settings/ai_service_wizard_screen.dart` | `Scaffold + AppBar`，从 AI settings push | 需要进一步确认 | 中。创建服务向导是任务型 | 后续迁移候选 |
| `memos_flutter_app/lib/features/settings/ai_service_detail_screen.dart` | `Scaffold + AppBar`，服务详情/配置 | 需要进一步确认 | 中。配置型但可能长内容 | 后续评估是 task surface 还是 full-page settings |
| `memos_flutter_app/lib/features/settings/api_plugins_screen.dart` token 创建相关弹出层 | 页面本身 `Scaffold + AppBar`，局部使用 `showWindowsAdaptiveSurface` / bottom sheet | token 创建是任务型 | 低到中。局部表面已有 Windows 适配，但非统一桌面 | 后续可统一到 shared task surface |
| `memos_flutter_app/lib/features/settings/export_memos_screen.dart` | `Scaffold + AppBar`，从 import/export push | 导出配置/执行任务 | 中。任务型但可能包含长进度 | 后续评估 |
| `memos_flutter_app/lib/features/settings/import_export_screen.dart` 下游 import/export/migration routes | `PlatformPage` push import/export 子流程 | 视子流程而定 | 低到中。`PlatformPage` 已较安全，但任务型入口多 | 后续按 settings/import 批次统一 |
| `memos_flutter_app/lib/features/reminders/memo_reminder_editor_screen.dart` | `PlatformPage` + save action | 提醒编辑任务 | 低。`PlatformPage` 已有安全 seam | 若要统一任务型桌面 UX，可后续迁移；不是遮挡首要问题 |
| `memos_flutter_app/lib/features/location_picker/show_location_picker.dart` | Windows `showWindowsAdaptiveSurface`，其他平台 bottom sheet；设置入口 push `LocationSettingsScreen` | 临时选择任务 | 低。已有自适应表面但 Windows-only | 可作为共享 task surface 泛化参考，不是首批 |
| `memos_flutter_app/lib/features/memos/memo_editor_screen.dart` | full editor surface，内部有未保存确认 dialog | 有 | 中。编辑 memo 是重任务，可能不适合居中弹窗 | 后续单独设计，不纳入本 change |
| `memos_flutter_app/lib/features/memos/windows_camera_capture_screen.dart` | `MaterialPageRoute(fullscreenDialog: true)` + AppBar | 临时捕获任务 | 中。Windows 专用 | 后续平台任务表面或专用窗口评估 |

## keep-full-page

这些页面是阅读、详情、预览、长内容或顶层导航体验，不应因为本 change 被统一改成居中任务弹窗。

| 页面/入口 | 当前呈现方式 | 未保存保护 | 桌面窗口控制风险 | 判断 |
| --- | --- | --- | --- | --- |
| `memos_flutter_app/lib/features/collections/collection_detail_screen.dart` | collection detail 分派到 reader/article flow；错误态 `Scaffold + AppBar` | 不涉及编辑 | 错误态有 AppBar 风险，但主内容是详情/阅读 | 保持 full-page；错误态后续可迁移到安全 page chrome seam |
| `memos_flutter_app/lib/features/collections/collection_reader_screen.dart` `CollectionReaderScreen` | `PlatformPage` | 阅读器状态 | 低 | 阅读型页面，保持 full-page |
| `memos_flutter_app/lib/features/collections/collection_article_flow_screen.dart` | article flow `Scaffold + AppBar`，detail view body | 阅读/文章流 | 中。AppBar 可能仍需安全 page chrome | 保持 full-page；不改成任务弹窗 |
| `memos_flutter_app/lib/features/memos/memo_detail_screen.dart` | memo detail push route | 不涉及短任务 | 视入口而定 | 详情页，保持 full-page |
| `memos_flutter_app/lib/features/memos/memo_versions_screen.dart` / `memo_version_preview_screen.dart` | history / preview full-page | restore 确认 | 中 | 历史和预览为详情型，保持 full-page |
| `memos_flutter_app/lib/features/memos/draft_box_screen.dart` | draft box selection route / top-level-like page | 选择状态 | 低到中 | 列表/导航型，保持 full-page |
| `memos_flutter_app/lib/features/memos/recycle_bin_screen.dart` / `recycle_bin_preview_screen.dart` | recycle bin and preview pages | 删除/恢复确认 | 中 | 列表/预览型，保持 full-page |
| `memos_flutter_app/lib/features/image_preview/widgets/image_preview_gallery_body.dart` | gallery preview/edit full-page | edit action dialog | 中 | 媒体预览型，保持 full-page |
| `memos_flutter_app/lib/features/resources/resources_screen.dart` `_ImageViewerScreen` | `PlatformPage` preview | 不涉及编辑 | 低 | 预览型，保持 full-page |
| `memos_flutter_app/lib/features/review/ai_summary_screen.dart` evidence memo / settings routes | memo detail、AI settings、history 等 full-page | 视目标页 | 中 | 分析/详情流，保持 full-page 或由各目标页后续处理 |
| `memos_flutter_app/lib/features/review/ai_insight_history_screen.dart` | `PlatformPage` | 不涉及短任务 | 低 | 历史列表，保持 full-page |
| `memos_flutter_app/lib/features/import/import_flow_screens.dart` | `PlatformPage` 多步导入流程 | 导入状态 | 低到中 | 长流程，保持 full-page；后续单独评估 task window |
| `memos_flutter_app/lib/features/notifications/notifications_screen.dart` | `PlatformPage(desktopWindowChromeSafeArea: true)` | 不涉及编辑 | 低 | 已使用安全 seam，保持 full-page |
| `memos_flutter_app/lib/features/stats/stats_screen.dart` | `PlatformPage(desktopWindowChromeSafeArea: true)` | 不涉及编辑 | 低 | 已使用安全 seam，保持 full-page |

## out-of-scope

这些入口不属于本 change 的二级任务页面迁移对象。

| 页面/入口 | 当前呈现方式 | 原因 |
| --- | --- | --- |
| `memos_flutter_app/lib/features/settings/settings_screen.dart` | top-level settings destination / desktop settings root uses `PlatformPage` and optional drag area | 顶层 destination，不是二级任务表面 |
| `memos_flutter_app/lib/features/home/desktop/*` | `DesktopShellHost` / Windows/macOS shell | 桌面 shell 基础设施，不是 feature 二级页面 |
| `memos_flutter_app/lib/features/share/desktop_share_task_window_app.dart` / `share_clip_screen.dart` | dedicated share task window / `PlatformPage(desktopWindowChromeSafeArea: true)` | 专用任务窗口已有 chrome safe-area 规则 |
| `memos_flutter_app/lib/features/desktop/quick_input/desktop_quick_input_window.dart` | 专用 quick input subwindow | 独立子窗口，不是主窗口二级页面 |
| `memos_flutter_app/lib/features/auth/login_screen.dart` / onboarding / legal / lock gate | 启动、登录、锁屏、合规流程 | 特殊 root/gate 流程 |
| `memos_flutter_app/lib/features/settings/donation_dialog.dart` 和 updates notice dialogs | `showGeneralDialog` / dialog presenter | 已是临时 dialog，不是 page migration |
| `memos_flutter_app/lib/features/memos/advanced_search_sheet.dart`、`memo_time_adjustment_sheet.dart`、`widgets/memo_engagement_surface.dart` | Windows adaptive surface 或 bottom sheet | 已是临时 surface；后续可复用共享 seam，但不是本次页面迁移 |
| `memos_flutter_app/lib/features/tags/tag_edit_sheet.dart` | dialog | 已是临时编辑 dialog |
| `memos_flutter_app/lib/platform/widgets/platform_dialog.dart`、`platform_popover_or_sheet.dart`、`core/windows_adaptive_surface.dart` | shared/adaptive surface helpers | 基础设施，后续可能被泛化，不作为页面候选 |
| `memos_flutter_app/lib/main_animated_list_demo.dart` | demo page | 非主应用运行路径 |

## 首批结论

本 change 的首批实现应围绕 collections task-like flows：

1. 必须迁移 `CollectionEditorScreen` 及其入口，解决“合集 -> 创建合集”桌面遮挡问题。
2. 必须更新 `add_to_collection_sheet.dart`，避免桌面弹窗中再 push 风险完整页面。
3. 应更新 `collections_screen.dart`、`collection_reader_screen.dart`、`collection_reader_shell.dart` 中打开 `CollectionEditorScreen` 的入口。
4. 任务 1.5 确认 `ManualCollectionManageScreen` 同批迁移；从本清单看，它属于任务型管理页面，优先级仅次于 `CollectionEditorScreen`。
5. `_ManualMemoPickerScreen` 是 `CollectionEditorScreen` 内部子任务，迁移外层时需要避免继续用桌面 full-page `fullscreenDialog` 造成同类问题。

## 任务 1.1 / 1.2 / 1.5 确认记录

- 架构阶段：`openspec/config.yaml` 当前仍声明 `Architecture phase: evolve_modularity`。
- 模块化影响：本 change 触及模块化清单第 6 项（feature 间协作通过入口 helper 和 platform seam）、第 8 项（新增/更新 guardrail）、第 10 项（collections 触及区域用共享 seam 代替页面内平台修补）。
- API 范围：首批实现不需要修改 `memos_flutter_app/lib/data/api` 或 `memos_flutter_app/test/data/api`。
- 首批迁移范围：`CollectionEditorScreen`、`_ManualMemoPickerScreen`、`ManualCollectionManageScreen` 以及 collections 中所有打开这些任务页的入口同批迁移。
