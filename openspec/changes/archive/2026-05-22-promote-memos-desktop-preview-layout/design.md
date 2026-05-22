## Context

当前问题来自三个分散的 Windows-only 判断：

```text
MemosListAnimatedMemoItem
  └─ Platform.isWindows -> maxWidth: kMemoFlowDesktopMemoCardMaxWidth

shouldUseDesktopPreviewPaneLayout
  └─ defaultTargetPlatform == TargetPlatform.windows

MemosListScreen
  └─ _resolveCurrentWindowsDesktopLayout().supportsSecondaryPane
      gates preview interaction
```

这些判断让 Windows 端拥有更成熟的 desktop memo list 体验，但 macOS 端在同一类大窗口中退化为“拉伸卡片 + 无右侧预览”。

## Decision

将 memo list 的卡片限宽和 preview pane 识别为 desktop 行为，而不是 Windows 行为。

```text
Before
  Windows desktop -> bounded memo cards + preview pane
  macOS desktop   -> stretched memo cards + no preview interaction

After
  desktop target  -> bounded memo cards
  Windows desktop -> existing preview thresholds remain
  macOS desktop   -> desktop preview helper enables right preview at wide width
```

## Layout Model

Memo card width:

```text
desktop memo list column
┌─────────────────────────────── available width ───────────────────────────────┐
│                     ┌──── max 760 memo card ────┐                             │
│                     │ content / media / actions │                             │
│                     └───────────────────────────┘                             │
└───────────────────────────────────────────────────────────────────────────────┘
```

Media grid height limit:

```text
desktop memo card (many images)
┌──── max 760 memo card ────┐
│ ┌───┐ ┌───┐ ┌───┐          │
│ │   │ │   │ │   │          │  tile width shrinks with height limit
│ └───┘ └───┘ └───┘          │  instead of becoming wide, short strips
└───────────────────────────┘
```

Preview pane:

```text
wide desktop home
┌──────── drawer ────────┬──────── bounded list ────────┬──── preview pane ────┐
│ navigation             │ memo cards                    │ selected memo       │
└────────────────────────┴───────────────────────────────┴─────────────────────┘
```

Windows keeps its existing `resolveWindowsDesktopLayout` thresholds. Non-Windows desktop targets use the existing `kMemoFlowDesktopPreviewPaneBreakpoint` helper path.

## Dependency Direction

Touched paths stay within existing ownership:

```text
core/platform_layout.dart
  └─ owns platform-neutral layout helpers

features/memos/*
  └─ consumes layout helpers and owns memo UI composition

state/memos/desktop_home_pane_state.dart
  └─ unchanged preview/editor state owner
```

No new `core -> features`, `state -> features`, or `application -> features` dependency is introduced. The modularity improvement is small but direct: platform-specific feature branching is reduced by replacing `Platform.isWindows` with a desktop-target seam.

## Risks

- [Risk] Linux also receives bounded cards and preview helper support.
  Mitigation: this matches the requested desktop promotion and uses existing desktop target detection.

- [Risk] macOS preview pane may expose layout edge cases previously hidden by Windows-only gating.
  Mitigation: focused tests cover layout state and body composition; manual macOS smoke should verify card click opens preview and pane closes correctly.

- [Risk] Windows behavior changes unintentionally.
  Mitigation: keep Windows `resolveWindowsDesktopLayout` path intact and preserve existing tests.

- [Risk] macOS media previews still appear stretched when there are many attachments and the grid hits its max-height cap.
  Mitigation: promote the existing square-preserving height-limited tile behavior from Windows-only to desktop targets and cover it with a macOS regression test.
