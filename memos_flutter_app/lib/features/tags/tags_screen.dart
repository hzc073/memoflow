import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform_layout.dart';
import '../../core/drawer_navigation.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/app_drawer_menu_button.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import 'tag_edit_sheet.dart';
import 'tag_sorting.dart';
import 'tag_tree.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedPaths = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _backToAllMemos(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: dest),
    );
  }

  void _openTag(BuildContext context, String tag) {
    closeDrawerThenPushReplacement(
      context,
      MemosListScreen(
        title: '#$tag',
        state: 'NORMAL',
        tag: tag,
        showDrawer: true,
        enableCompose: true,
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  Future<void> _openTagEditor(BuildContext context, TagStat? tag) async {
    await TagEditSheet.showEditorDialog(context, tag: tag);
  }

  void _toggleExpanded(String path) {
    setState(() {
      if (!_expandedPaths.add(path)) {
        _expandedPaths.remove(path);
      }
    });
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    Map<String, TagStat> tagsByPath,
    TagTreeNode node,
    TagTreeMenuAction action,
  ) async {
    final tag = tagsByPath[node.path];
    if (tag == null) return;

    switch (action) {
      case TagTreeMenuAction.edit:
        await _openTagEditor(context, tag);
        break;
      case TagTreeMenuAction.delete:
        await confirmAndDeleteTag(context: context, ref: ref, tag: tag);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagStatsProvider);
    final tagListMode = ref.watch(
      currentWorkspacePreferencesProvider.select((prefs) => prefs.tagListMode),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final enableWindowsDragToMove =
        Theme.of(context).platform == TargetPlatform.windows;
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.tags,
      onSelect: (d) => _navigate(context, d),
      onSelectTag: (t) => _openTag(context, t),
      onOpenNotifications: () => _openNotifications(context),
      embedded: useDesktopSidePane,
    );

    final pageBody = tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sell_outlined,
                    size: 42,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(context.t.strings.legacy.msg_no_tags_yet),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openTagEditor(context, null),
                    icon: const Icon(Icons.add),
                    label: Text(context.t.strings.legacy.msg_create_tag),
                  ),
                ],
              ),
            ),
          );
        }

        final textMain = Theme.of(context).colorScheme.onSurface;
        final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
        final baseTree = buildTagTreeForMode(tags, mode: tagListMode);
        final tagsByPath = {for (final tag in tags) tag.path: tag};
        final query = _searchController.text.trim().toLowerCase();
        final filterResult = query.isEmpty
            ? baseTree
            : filterTagTree(
                baseTree.nodes,
                (node) => node.path.toLowerCase().contains(query),
              );
        final visibleTree = filterResult.nodes;
        final resolvedExpandedPaths = <String>{
          ..._expandedPaths,
          ...filterResult.autoExpandedPaths,
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _TagsSearchBar(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                onClear: _searchController.text.isEmpty
                    ? null
                    : () {
                        setState(() => _searchController.clear());
                      },
              ),
            ),
            Expanded(
              child: visibleTree.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 42,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(context.t.strings.legacy.msg_no_tags),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _searchController.clear());
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(context.t.strings.legacy.msg_clear_2),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        child: TagTreeList(
                          nodes: visibleTree,
                          expandedPaths: resolvedExpandedPaths,
                          onToggleExpanded: _toggleExpanded,
                          onSelect: (tag) => _openTag(context, tag),
                          onMenuAction: (node, action) => _handleMenuAction(
                            context,
                            tagsByPath,
                            node,
                            action,
                          ),
                          showMenu: true,
                          textMain: textMain,
                          textMuted: textMuted,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(context.t.strings.legacy.msg_failed_load_4(e: e))),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        drawer: useDesktopSidePane ? null : drawerPanel,
        appBar: AppBar(
          flexibleSpace: enableWindowsDragToMove
              ? const DragToMoveArea(child: SizedBox.expand())
              : null,
          automaticallyImplyLeading: false,
          leading: useDesktopSidePane
              ? null
              : AppDrawerMenuButton(
                  tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                  iconColor:
                      Theme.of(context).appBarTheme.iconTheme?.color ??
                      IconTheme.of(context).color ??
                      Theme.of(context).colorScheme.onSurface,
                  badgeBorderColor: Theme.of(context).scaffoldBackgroundColor,
                ),
          title: IgnorePointer(
            ignoring: enableWindowsDragToMove,
            child: Text(context.t.strings.legacy.msg_tags),
          ),
          actions: [
            TagListModeMenuButton(
              mode: tagListMode,
              onSelected: (value) {
                if (value == tagListMode) return;
                ref
                    .read(currentWorkspacePreferencesProvider.notifier)
                    .setTagListMode(value);
              },
              iconColor:
                  Theme.of(context).appBarTheme.iconTheme?.color ??
                  IconTheme.of(context).color ??
                  Theme.of(context).colorScheme.onSurface,
            ),
            IconButton(
              tooltip: context.t.strings.legacy.msg_create_tag,
              onPressed: () => _openTagEditor(context, null),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: useDesktopSidePane
            ? Row(
                children: [
                  SizedBox(
                    width: kMemoFlowDesktopDrawerWidth,
                    child: drawerPanel,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(child: pageBody),
                ],
              )
            : pageBody,
      ),
    );
  }
}

class _TagsSearchBar extends StatelessWidget {
  const _TagsSearchBar({
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: context.t.strings.legacy.msg_search,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: context.t.strings.legacy.msg_clear_2,
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
