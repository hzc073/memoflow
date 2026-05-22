## 1. 总纲与 Inventory

- [x] 1.1 创建平台 UI migration inventory，覆盖 shell/navigation、onboarding/login、settings、memo 主流程、collections/resources/review/AI/stats、dialogs/pickers/sheets/popovers、primary actions、list/form controls、route transitions、keyboard/right-click、安全区/window chrome、dark mode、accessibility、smoke checks
- [x] 1.2 给 inventory 中每个区域标记当前状态：mobile-expanded、partial desktop shell、adaptive seam ready、migrated、blocked、accepted as-is
- [x] 1.3 定义平台目标矩阵：iPhone、iPadOS、macOS、Windows、Android/Linux/web 的 shell、navigation、action、transient UI、list/form、keyboard/right-click 目标行为
- [x] 1.4 明确本 change 后续工作方式：每次 implementation 只选择一个 migration batch，并在完成后更新 inventory / tasks 状态

## 2. Adaptive UI 基建

- [x] 2.1 梳理现有 `platform/` adapters、`PlatformPage`、`PlatformListTile`、`PlatformGroupedList`、`PlatformActionSheet`、`PlatformControls` 与 desktop shell host 的覆盖缺口
- [x] 2.2 设计并实现 bounded desktop primary action seam，避免桌面端按钮默认全宽拉伸，同时保留移动端 full-width 行为
- [x] 2.3 设计并实现 adaptive dialog / picker / popover-or-sheet seam，统一桌面 dialog/popover 与移动 bottom sheet/action sheet 的语义入口
- [x] 2.4 设计并实现 adaptive list/form section seam，支持 Apple grouped lists、desktop dense rows、mobile touch rows 与现有 Material fallback
- [x] 2.5 设计并实现 desktop bounded content / master-detail helper，用于单列页面最大宽度、预览 pane、inspector 或 table-like layout 的选择
- [x] 2.6 为 adaptive seam 增加 architecture guardrail，防止 `platform/` 或 shared adaptive UI 反向依赖 `features/*`、`state/*`、`application/*`、`data/*`

## 3. Shell 与 Navigation 批次

- [x] 3.1 审计 `DesktopShellHost`、`AppleMacosPageShell`、`WindowsDesktopPageShell`、`home_bottom_nav_shell`、`apple_tablet_home_shell` 的职责边界
- [x] 3.2 收敛桌面 shell 组合入口，确保 feature pages 不直接导入具体平台 shell 实现
- [x] 3.3 校准 macOS sidebar/toolbar/window chrome 与 Windows sidebar/rail/command bar 的差异，不互相套用最终 UI
- [x] 3.4 校准 iPad shell 与 iPhone shell 的分歧，避免 iPad 继续像放大手机页
- [x] 3.5 增加 focused tests 或 guardrails，覆盖 shell host 平台路由和 feature-to-shell 依赖方向

## 4. Onboarding / Login / Workspace 批次

- [x] 4.1 迁移首次设置页到 adaptive layout：移动端保持原流程，桌面端限制内容宽度与按钮宽度，不使用手机全宽控件拉伸
- [x] 4.2 迁移登录页和服务器/本地工作区选择相关流程，桌面端使用 bounded form、dialog/picker 和合适的 primary action placement
- [x] 4.3 校准 macOS / Windows 初始窗口尺寸、最小尺寸与内容可见性，避免用页面畸形排版补偿窗口尺寸问题
- [x] 4.4 增加 focused widget tests，覆盖桌面宽窗口按钮不拉伸、移动端布局不回退、窄窗口仍可滚动访问主操作

## 5. Settings 批次

- [x] 5.1 以 `SettingsScreen` 和 `PreferencesSettingsScreen` 作为样板迁移 settings grouped list、value row、toggle、picker、dialog 和 route behavior
- [x] 5.2 将桌面设置页的全宽 card/list 流调整为 bounded content、split view 或独立 settings window 适配布局
- [x] 5.3 将 enum/date/font/theme 等选择器迁移到 adaptive picker seam，避免桌面继续使用手机 bottom sheet
- [x] 5.4 审计设置页入口和子窗口行为，确保 macOS / Windows / mobile 各自 shell 体验一致且不引入商业逻辑
- [x] 5.5 增加 settings focused tests，覆盖 Apple grouped list、desktop bounded actions、mobile fallback 和 public shell guardrails

## 6. Memo 主流程批次

- [x] 6.1 审计 `memos_list_screen.dart` 中 desktop preview/editor/shortcut 状态，识别可抽到 desktop-common 或 feature-owned seam 的平台行为
- [x] 6.2 迁移 memo list 在桌面端的密度、右键菜单、hover/selection、preview pane、keyboard navigation 和 primary compose action
- [x] 6.3 迁移 memo detail 在桌面端的阅读宽度、action placement、context menu、image/video preview 和 navigation behavior
- [x] 6.4 迁移 memo editor / compose 在桌面端的 modal/fullscreen、toolbar、attachments、save/cancel actions 和 keyboard shortcuts
- [x] 6.5 保持移动端 note input / editor 交互不回退，并为桌面与移动关键路径分别增加 focused tests

## 7. Collections / Resources / Review / AI / Stats 批次

- [x] 7.1 审计 collections 与 reader shell，识别桌面端需要 master-detail、toolbar、reader width、popover 的区域
- [x] 7.2 审计 resources 页面，迁移 desktop list/table、filter/search、context actions 和 preview behavior
- [x] 7.3 审计 review / AI summary / explore 页面，迁移桌面端 command placement、side panel、bounded reading width 和 transient UI（本批完成 AI 检索预览 bounded reading width；Explore / Daily Review transient UI 继续作为后续 pending）
- [x] 7.4 审计 stats 页面，迁移宽屏 dashboard layout、图表尺寸和 action placement
- [x] 7.5 为每个批次记录 accepted as-is / migrated / pending 状态，并补 focused tests 或 smoke checklist

## 8. Verification 与长期维护

- [x] 8.1 每个 migration batch 运行 `flutter analyze`
- [x] 8.2 每个 migration batch 运行相关 focused widget tests 和 architecture guardrails
- [x] 8.3 涉及 macOS / Windows shell 的批次必须记录手动 smoke checklist：窗口控制、菜单、快捷键、右键、拖拽、resize、dark mode
- [x] 8.4 涉及移动端 fallback 的批次必须验证 iPhone / Android 关键布局不回退
- [x] 8.5 完成高感知区域后更新 `platform-adaptive-ui-system` inventory，总结剩余 pending 和 accepted as-is 项
