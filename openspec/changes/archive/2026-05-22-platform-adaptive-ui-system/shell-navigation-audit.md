# Shell 与 Navigation 审计

Last updated: 2026-05-20

本审计对应任务 3.1，用于记录桌面、平板和移动 shell 的职责边界。后续 shell/navigation 批次应优先更新这里，再做具体页面迁移。

## Shell Boundary Map

| Shell / Host | File | Current Role | Boundary Notes |
| --- | --- | --- | --- |
| `HomeEntryScreen` | `lib/features/home/home_entry_screen.dart` | 根据 `PlatformTarget` 和 workspace navigation preferences 选择 iPad、desktop、mobile/classic 入口，并包 Apple shell 外壳 | 是 top-level home shell 路由入口；不应承载具体页面布局策略 |
| `DesktopShellHost` | `lib/features/home/desktop/desktop_shell_host.dart` | 作为 desktop feature pages 的组合入口，在 macOS 与 Windows shell strategy 之间路由 | feature pages 应导入它，而不是直接导入具体 macOS / Windows shell |
| `AppleMacosPageShell` | `lib/features/home/desktop/apple_macos_page_shell.dart` | macOS sidebar + toolbar + content + optional secondary pane/modal | 具体 macOS shell strategy，只应由 `DesktopShellHost` 或 shell tests 使用 |
| `WindowsDesktopPageShell` | `lib/features/home/desktop/windows_desktop_page_shell.dart` | Windows command bar/window controls/nav mode 选择，并组合 workspace shell | 具体 Windows page strategy，只应由 `DesktopShellHost` 或 focused Windows shell tests 使用 |
| `WindowsDesktopWorkspaceShell` | `lib/features/home/desktop/windows_desktop_workspace_shell.dart` | Windows workspace layout：pinned/overlay navigation、secondary pane、modal surface、resizer/motion | 低层 Windows shell primitive；feature pages 不应直接依赖 |
| `HomeBottomNavShell` | `lib/features/home/home_bottom_nav_shell.dart` | iPhone / Android bottom navigation shell and mobile swipe behavior | 移动 shell；iPad 窄宽度目前会 fallback 到它 |
| `AppleTabletHomeShell` | `lib/features/home/apple_tablet_home_shell.dart` | iPad sidebar split view，窄宽度 fallback 到 `HomeBottomNavShell` | 已不是简单放大手机页；后续需继续优化 iPad route / popover 行为 |

## Findings

1. 多数高感知 feature page 已经通过 `DesktopShellHost` 组合桌面 shell，例如 settings、memos、collections、resources、review、explore、tags、notifications、about。
2. 目前没有非 `home/desktop` runtime feature 直接导入 `AppleMacosPageShell`、`WindowsDesktopPageShell` 或 `WindowsDesktopWorkspaceShell`。
3. 原先 `DesktopShellHost` 的公共 API 暴露 `WindowsDesktopSecondaryPane*` / `WindowsDesktopModalSurface*` 类型名，导致 macOS 与通用 desktop shell API 继承 Windows 命名。任务 3.2 已开始收敛为 `DesktopShell*` 语义类型，Windows 文件保留兼容 typedef。
4. `AppleMacosPageShell` 目前复用 secondary pane / modal motion 语义，但视觉实现已独立于 Windows command bar/window controls。
5. `AppleTabletHomeShell` 已提供 sidebar split view；窄宽度 fallback 到 `HomeBottomNavShell` 是当前可接受的 responsive fallback，不代表 iPad 最终交互完成。

## Current Risks

- `core/platform_layout.dart` 仍保留 `kWindowsDesktopSecondaryPane*` 命名，后续若进一步泛化 desktop shell token，可迁到平台中立常量。
- `WindowsDesktopPageShell` / `WindowsDesktopWorkspaceShell` 仍导出 Windows 兼容 typedef，主要为了保持现有 focused tests 和内部 API 稳定；后续可以逐步收缩导出。
- feature pages 仍各自决定何时使用 `DesktopShellHost`，缺少更高层 page wrapper；这会在后续 settings/memo/resources 批次继续收敛。

## Guardrail Target

任务 3.5 应保护以下方向：

- feature runtime files 可以导入 `features/home/desktop/desktop_shell_host.dart`。
- feature runtime files 不应直接导入：
  - `features/home/desktop/apple_macos_page_shell.dart`
  - `features/home/desktop/windows_desktop_page_shell.dart`
  - `features/home/desktop/windows_desktop_workspace_shell.dart`
- focused shell tests 可以直接导入具体 shell 文件。
