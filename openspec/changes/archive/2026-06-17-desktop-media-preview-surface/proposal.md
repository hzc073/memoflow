## Why

macOS 主窗口使用透明标题栏后，单张图片查看仍像普通二级页面一样渲染 `AppBar` 和左上返回按钮，容易与系统红黄绿窗口按钮和标题区域重叠。图片、视频这类多媒体预览更适合作为临时查看器：桌面端用独立媒体查看 surface，移动端继续保留现有全屏页面体验。

## What Changes

- 桌面端图片、视频和可预览媒体打开为独立媒体查看 surface，而不是主窗口里的普通 full-page route。
- 桌面媒体查看 surface 不渲染普通 `AppBar`、App-level Back 或顶部 `Back + Page Title`；关闭主要依赖系统窗口关闭、`Esc` 和明确的媒体查看器关闭行为。
- 媒体查看器保留媒体相关能力：页码、左右切换、缩放、下载、编辑/替换等，并避免这些控件与 macOS traffic lights 或其他平台窗口控件重叠。
- 手机和平板继续使用现有全屏图片/视频查看页面，保留平台习惯的返回按钮或手势。
- 若桌面独立窗口能力不可用或打开失败，fallback 也应使用无普通 `AppBar` 的沉浸式媒体查看器，而不是恢复左上 App 返回按钮。
- 本 change 处于 `evolve_modularity` 阶段；实现应收敛媒体打开入口和窗口打开 seam，避免在多个 widget 中继续分散 push 逻辑，并补充 focused tests/guardrails 防止回退。

## Capabilities

### New Capabilities

- `desktop-media-preview-surface`: 定义桌面端独立媒体查看 surface、关闭语义、fallback、移动端保留行为、媒体控件和架构边界。

### Modified Capabilities

- `secondary-page-navigation`: 明确桌面独立媒体查看 surface 不是普通 full-page secondary page，不要求渲染 `Back + Page Title`。
- `desktop-window-chrome-safe-area`: 增加媒体查看窗口/root surface 的窗口控件避让要求，确保媒体控件不与 macOS traffic lights 或其他平台窗口控件重叠。

## Impact

- 影响 `memos_flutter_app/lib/features/image_preview/**`、`memos_flutter_app/lib/features/memos/attachment_gallery_screen.dart`、memo 图片网格/详情/编辑/内联 compose 的媒体预览入口，以及现有视频/附件预览入口。
- 可能新增或扩展桌面媒体窗口打开 seam、桌面 runtime role、窗口 channel/codec、媒体窗口 app root 和 fallback presenter。
- 不改变 Memos API、数据库 schema、同步协议、请求/响应模型或版本兼容逻辑。
- 不引入订阅、付费、StoreKit、权益、paywall 或 private overlay 逻辑。
- 模块化影响：涉及 `features/memos` 和桌面窗口打开边界；实现不得新增 `state -> features`、`application -> features` 或 `core -> features` 反向依赖，若触及耦合热点需增加集中入口或 guardrail，使被触及区域结构不变差。
