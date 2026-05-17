## Context

当前 `DraftBoxScreen` 已存在，但主要由 compose surfaces 打开：`NoteInputSheet` 和 home inline compose 调用 `DraftBoxScreen.show(...)`，接收返回的 `draftUid`，再在当前编辑器上下文恢复草稿。侧边栏和底部导航目前没有 Draft Box destination；用户必须先进入编辑器才能发现和打开草稿箱。

相关现状：

- `AppDrawerDestination` 和 `AppDrawer` 手动维护侧边栏 destination 列表，同时 desktop rail/sidebar 通过 `AppDrawerModel` 渲染。
- `HomeRootDestination`、`home_navigation_resolver.dart`、`home_root_destination_registry.dart` 维护底部导航可选 destination、fallback、label/icon registry 和页面构建。
- `WorkspacePreferences` 管理 workspace-scoped drawer entry visibility，例如 `showDrawerCollections`、`showDrawerResources`、`showDrawerArchive`。
- `NoteInputSheet` 已有完整 draft restore logic，但目前只从现有 compose-owned picker path 使用。

Architecture phase is `evolve_modularity`. This change touches feature-to-feature navigation and preference persistence surfaces, so the implementation should preserve existing registry/provider seams and avoid adding new reverse dependencies.

## Goals / Non-Goals

**Goals:**

- Add Draft Box as a first-class navigation destination in sidebar and bottom navigation configuration.
- Show the Draft Box sidebar entry by default and allow users to hide it from Laboratory > Customize Sidebar.
- Let navigation-launched Draft Box selections open `NoteInputSheet` and restore the selected draft for editing.
- Preserve existing compose-toolbar Draft Box behavior.
- Keep full draft restoration owned by `NoteInputSheet` and existing draft helpers.
- Add focused tests for drawer visibility, navigation registry/resolver behavior, and selected-draft editor launch.

**Non-Goals:**

- Do not create a separate read-only draft list mode.
- Do not change compose draft storage, sync transfer, WebDAV backup, or migration semantics.
- Do not change memo create API behavior or server compatibility logic.
- Do not add commercial/private hooks.
- Do not redesign Draft Box cards or add draft preview details beyond the existing screen.
- Do not make Draft Box a default bottom navigation slot; it is only an available option.

## Decisions

### Decision: Add Draft Box to existing navigation enums and registries

Add `draftBox` to `AppDrawerDestination` and `HomeRootDestination`, then register it in the existing drawer destination builder and home root destination registry.

```text
AppDrawerDestination.draftBox
        |
        v
DraftBoxScreen

HomeRootDestination.draftBox
        |
        v
homeRootDestinationDefinition(...)
        |
        v
DraftBoxScreen
```

Rationale:

- The app already uses enum-backed destinations for drawer and bottom navigation.
- The home registry is the existing seam for label/icon/screen construction.
- Adding Draft Box here keeps desktop sidebar, desktop rail, overlay panel, and bottom navigation settings aligned with current patterns.

Alternative considered:

- Add Draft Box only as a quick action. Rejected because the user asked for a sidebar entry and a bottom navigation option, and quick actions do not participate in the bottom navigation slot picker.

### Decision: Use a workspace preference for sidebar visibility

Add a workspace-scoped `showDrawerDraftBox` preference defaulting to `true`, following the same shape as `showDrawerCollections`, `showDrawerResources`, and `showDrawerArchive`.

Rationale:

- Drawer customization is already workspace-scoped.
- Default-on matches the requested behavior: 默认允许，可以关闭.
- This preserves existing preference ownership through `WorkspacePreferencesController`.

Implementation notes:

- Update legacy compatibility DTOs only enough to serialize, parse, copy, and bridge the new drawer visibility preference.
- Keep the preference public and non-commercial.
- Include migration-compatible default parsing so older stored preferences show Draft Box by default.

### Decision: Navigation-launched Draft Box consumes `draftUid` by opening note input

Keep `DraftBoxScreen.show(...)` returning `String?` when the user taps a draft. For navigation-launched usage, wrap the screen in a destination route that awaits the returned `draftUid` and opens `NoteInputSheet` with an initial draft identifier.

```text
Sidebar / Bottom nav
    |
    v
DraftBoxScreen.show(...)
    |
    | user taps draft A
    v
selectedDraftId
    |
    v
NoteInputSheet.show(initialDraftUid: selectedDraftId)
    |
    v
NoteInputSheet restores full draft state
```

Rationale:

- The existing Draft Box tap behavior remains useful: selecting a draft produces a `draftUid`.
- Navigation code should not reconstruct draft content, attachments, linked memos, location, or inline image source mappings.
- `NoteInputSheet` is already the correct owner for compose state restoration.

Alternative considered:

- Have `DraftBoxScreen` directly import and open `NoteInputSheet`. Rejected because it couples the list screen to a specific compose presentation and makes the picker use case less clean.

### Decision: Add `initialDraftUid` to `NoteInputSheet`

Extend `NoteInputSheet.show(...)` and the widget constructor with an optional `initialDraftUid`. During initialization, load the draft from `composeDraftRepositoryProvider` and restore it through the existing `_restoreComposeDraft` path.

Rationale:

- Passing only `initialText` would lose non-text draft state.
- Keeping restoration inside `NoteInputSheet` avoids duplicated mapping from `ComposeDraftSnapshot` to composer state.
- Existing compose-owned picker behavior can keep using `_restoreComposeDraft` directly.

Behavior notes:

- If `initialDraftUid` is empty or cannot be found, `NoteInputSheet` should fall back to a normal empty compose surface and avoid crashing.
- If `ignoreDraft` is true, navigation should not pass `initialDraftUid`; this change's navigation path uses normal draft-aware compose.
- The restored draft should keep its active draft id so submitting or saving continues updating/deleting the correct draft record.

### Decision: Keep dependency direction stable

Before:

```text
features/home -> features/memos screens through destination builders
features/memos -> state/memos draft providers
features/settings -> state/settings workspace preferences
state/settings -> data/models workspace preferences
```

After:

```text
features/home -> features/memos DraftBoxScreen / NoteInputSheet through navigation entry points
features/memos -> state/memos draft providers and helper restoration
features/settings -> state/settings workspace preferences
state/settings -> data/models workspace preferences
```

No new `state -> features`, `application -> features`, or `core -> state|application|features` dependency should be introduced. The scoped modularity improvement is to keep the selected-draft restoration seam on `NoteInputSheet` rather than spreading draft snapshot reconstruction into home navigation.

## Risks / Trade-offs

- [Risk] Adding a new enum value can break exhaustive switches. -> Mitigation: update all relevant switches in navigation resolver, registry, bottom navigation settings, and tests.
- [Risk] Navigation-launched Draft Box may pop a route before opening the editor, causing a confusing transition. -> Mitigation: centralize the flow in a destination wrapper/helper that awaits selection, checks `mounted`, then opens `NoteInputSheet`.
- [Risk] `initialDraftUid` restore may race provider initialization. -> Mitigation: load after repositories are available in `NoteInputSheet` init/setup, treat missing drafts as a non-fatal no-op, and preserve current empty compose fallback.
- [Risk] Preference migration may hide the new entry for existing users if parsing defaults incorrectly. -> Mitigation: default absent `showDrawerDraftBox` to `true` in both workspace and legacy compatibility parsing.
- [Risk] Bottom navigation labels may be cramped for localized Draft Box text. -> Mitigation: rely on existing bottom navigation ellipsis and visual tests for compact labels.

## Migration Plan

No data migration is required. Existing stored preferences do not contain `showDrawerDraftBox`; parsing should default it to enabled.

Rollback strategy:

- Remove the Draft Box destination enum values and registry entries.
- Remove `showDrawerDraftBox` from preference models and customization UI.
- Remove `initialDraftUid` from `NoteInputSheet` if no other caller depends on it.

## Open Questions

- None. The desired behavior is that navigation-launched Draft Box lists drafts and tapping a draft opens the editor to edit that draft.
