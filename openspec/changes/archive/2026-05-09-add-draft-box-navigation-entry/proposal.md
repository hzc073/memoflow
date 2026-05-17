## Why

草稿箱现在主要作为 compose 工具栏内的恢复入口存在，用户无法从主要导航直接进入草稿列表。新增导航入口可以让未完成草稿成为可发现的一级工作流，并让用户从侧边栏或底部导航进入后继续编辑选中的草稿。

## What Changes

- Add a Draft Box destination to the app navigation model.
- Show the Draft Box entry in the sidebar by default.
- Add a Draft Box visibility toggle to Laboratory > Customize Sidebar, defaulting to enabled.
- Add Draft Box as a selectable destination for configurable bottom navigation slots.
- When Draft Box is opened from navigation and the user taps a draft, open the compose editor and restore that draft for editing.
- Preserve the existing compose-toolbar Draft Box picker behavior.
- No API, sync protocol, billing/private hook, or server route behavior changes.

## Capabilities

### New Capabilities
- `draft-box-navigation`: Covers the Draft Box sidebar entry, sidebar customization toggle, bottom navigation destination option, and navigation-launched draft selection behavior.

### Modified Capabilities
- `note-input-sheet`: Adds the ability to launch note input from a selected compose draft so navigation-launched Draft Box selections restore full draft state in the editor.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/home/app_drawer.dart`
  - `memos_flutter_app/lib/features/home/app_drawer_destination_builder.dart`
  - `memos_flutter_app/lib/features/home/home_navigation_resolver.dart`
  - `memos_flutter_app/lib/features/home/home_root_destination_registry.dart`
  - `memos_flutter_app/lib/features/home/home_bottom_nav_shell.dart`
  - `memos_flutter_app/lib/features/memos/draft_box_screen.dart`
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/features/settings/customize_drawer_screen.dart`
  - `memos_flutter_app/lib/data/models/workspace_preferences.dart`
  - legacy preference compatibility surfaces that mirror workspace drawer preferences.
- Affected tests:
  - Drawer visibility/customization widget tests.
  - Bottom navigation destination resolver/registry/settings tests.
  - Draft Box selection and note input draft-restore tests.
- Architecture phase: `evolve_modularity`.
- Modularity checklist touched: item 6 (feature-to-feature collaboration through registry/seams), item 7 (write paths keep clear owners), item 8 (guardrail/regression tests).
- Scoped modularity improvement: route Draft Box through existing home destination registry/navigation seams and keep draft restoration owned by `NoteInputSheet`/draft helpers rather than duplicating draft state reconstruction in navigation widgets.
