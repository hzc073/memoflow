import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/attachment_url.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../data/models/account.dart';
import '../../data/models/attachment.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/memo_collection.dart';
import '../../data/repositories/collections_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collection_resolver.dart';
import '../../state/collections/collections_provider.dart';
import '../../state/system/session_provider.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/app_drawer_menu_button.dart';
import '../home/home_navigation_host.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import 'collection_diagnostics.dart';
import 'collection_detail_screen.dart';
import 'collection_editor_screen.dart';
import 'collection_reader_tokens.dart';
import 'collection_ui.dart';

enum _CollectionsFilter { all, smart, manual, archived }

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, this.embeddedNavigationHost});

  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'collectionsKeyboard',
  );
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'collectionsSearch');
  _CollectionsFilter _filter = _CollectionsFilter.all;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocusNode.hasFocus) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, AppDrawerDestination destination) {
    final host = widget.embeddedNavigationHost;
    if (host != null) {
      host.handleDrawerDestination(context, destination);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: destination),
    );
  }

  void _openTag(BuildContext context, String tag) {
    final host = widget.embeddedNavigationHost;
    if (host != null) {
      host.handleDrawerTag(context, tag);
      return;
    }
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
    final host = widget.embeddedNavigationHost;
    if (host != null) {
      host.handleOpenNotifications(context);
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  Future<void> _openEditor(BuildContext context, {MemoCollection? initial}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionEditorScreen(initialCollection: initial),
      ),
    );
  }

  void _expandSearch() {
    if (!_searchExpanded) {
      setState(() => _searchExpanded = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _collapseSearch() {
    _searchFocusNode.unfocus();
    setState(() {
      _searchExpanded = false;
      _searchController.clear();
    });
    if (!_keyboardFocusNode.hasFocus) {
      _keyboardFocusNode.requestFocus();
    }
  }

  Future<void> _openReorderSheet(
    BuildContext context,
    List<MemoCollectionDashboardItem> items,
  ) {
    if (items.length < 2) {
      return Future<void>.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CollectionsReorderSheet(
        items: items,
        onReorder: (orderedIds) =>
            ref.read(collectionsRepositoryProvider).reorder(orderedIds),
      ),
    );
  }

  Future<void> _togglePinned(MemoCollection collection) async {
    await ref
        .read(collectionsRepositoryProvider)
        .pin(collection.id, !collection.pinned);
  }

  Future<void> _toggleArchived(MemoCollection collection) async {
    await ref
        .read(collectionsRepositoryProvider)
        .archive(collection.id, !collection.archived);
  }

  Future<void> _duplicate(MemoCollection collection) async {
    await ref.read(collectionsRepositoryProvider).duplicate(collection);
  }

  Future<void> _copyDiagnostics(
    BuildContext context,
    MemoCollectionDashboardItem item,
  ) async {
    try {
      final text = buildCollectionDiagnosticsReport(
        collection: item.collection,
        preview: item.preview,
        items: item.items,
      );
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_diagnostics_copied),
        ),
      );
      LogManager.instance.info(
        'Collection diagnostics copied',
        context: <String, Object?>{
          'collectionId': item.collection.id,
          'collectionType': item.collection.type.name,
        },
      );
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Collection diagnostics copy failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'collectionId': item.collection.id,
          'collectionType': item.collection.type.name,
        },
      );
    }
  }

  Future<void> _deleteCollection(
    BuildContext context,
    MemoCollection collection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.strings.collections.deleteTitle),
        content: Text(
          context.t.strings.collections.deleteMessage(title: collection.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.strings.legacy.msg_cancel_2),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t.strings.legacy.msg_delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(collectionsRepositoryProvider).delete(collection.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(collectionsDashboardProvider);
    final reorderItems = _reorderableItems(
      dashboardAsync.valueOrNull ?? const <MemoCollectionDashboardItem>[],
    );
    final currentAccount = ref.watch(
      appSessionProvider.select((state) => state.valueOrNull?.currentAccount),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.collections,
      onSelect: (destination) => _navigate(context, destination),
      onSelectTag: (tag) => _openTag(context, tag),
      onOpenNotifications: () => _openNotifications(context),
      embedded: useDesktopSidePane,
    );
    final body = dashboardAsync.when(
      data: (items) {
        final visibleItems = _filterItems(items);

        Widget buildStatus({
          required IconData icon,
          required String title,
          required String description,
          required Widget action,
        }) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: CollectionReaderTokens.shelfListPadding,
              child: CollectionStatusView(
                icon: icon,
                title: title,
                description: description,
                action: action,
                centered: false,
              ),
            ),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (items.isEmpty)
              buildStatus(
                icon: Icons.auto_stories_rounded,
                title: context.t.strings.collections.noCollectionsTitle,
                description:
                    context.t.strings.collections.noCollectionsDescription,
                action: FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: Text(context.t.strings.collections.createCollection),
                ),
              )
            else if (visibleItems.isEmpty)
              buildStatus(
                icon: Icons.search_off_rounded,
                title: context.t.strings.collections.noMatchingTitle,
                description:
                    context.t.strings.collections.noMatchingDescription,
                action: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _filter = _CollectionsFilter.all;
                      _searchExpanded = false;
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.t.strings.collections.resetFilters),
                ),
              )
            else
              SliverPadding(
                padding: CollectionReaderTokens.shelfListPadding,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = visibleItems[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == visibleItems.length - 1 ? 0 : 6,
                      ),
                      child: _CollectionCard(
                        item: item,
                        account: currentAccount,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CollectionDetailScreen(
                                collectionId: item.collection.id,
                              ),
                            ),
                          );
                        },
                        onEdit: () =>
                            _openEditor(context, initial: item.collection),
                        onCopy: () => _duplicate(item.collection),
                        onCopyDiagnostics: () =>
                            _copyDiagnostics(context, item),
                        onTogglePinned: () => _togglePinned(item.collection),
                        onToggleArchived: () =>
                            _toggleArchived(item.collection),
                        onDelete: () =>
                            _deleteCollection(context, item.collection),
                      ),
                    );
                  }, childCount: visibleItems.length),
                ),
              ),
          ],
        );
      },
      loading: () => CollectionLoadingView(
        label: context.t.strings.collections.loadingCollections,
      ),
      error: (error, stackTrace) => CollectionErrorView(
        title: context.t.strings.collections.unableToLoadCollections,
        message: '$error',
      ),
    );

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;

    return Focus(
      focusNode: _keyboardFocusNode,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _expandSearch,
          SingleActivator(LogicalKeyboardKey.keyK, meta: true): _expandSearch,
          SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
              _openEditor(context),
          SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
              _openEditor(context),
          if (reorderItems.length >= 2)
            SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
                _openReorderSheet(context, reorderItems),
          if (reorderItems.length >= 2)
            SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
                _openReorderSheet(context, reorderItems),
        },
        child: Scaffold(
          backgroundColor: bg,
          drawer: useDesktopSidePane ? null : drawerPanel,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: useDesktopSidePane
                ? null
                : AppDrawerMenuButton(
                    tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                    iconColor:
                        Theme.of(context).appBarTheme.iconTheme?.color ??
                        IconTheme.of(context).color ??
                        Theme.of(context).colorScheme.onSurface,
                    badgeBorderColor: bg,
                  ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchExpanded
                  ? Container(
                      key: const ValueKey<String>('search-field'),
                      height: 40,
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (_) => setState(() {}),
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText:
                              context.t.strings.collections.searchCollections,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    )
                  : Text(context.t.strings.collections.title),
            ),
            actions: _searchExpanded
                ? [
                    IconButton(
                      tooltip: _searchController.text.trim().isEmpty
                          ? context.t.strings.legacy.msg_close_search
                          : context.t.strings.legacy.msg_clear_2,
                      onPressed: _collapseSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]
                : [
                    IconButton(
                      key: const ValueKey<String>('search-button'),
                      tooltip: context.t.strings.collections.searchCollections,
                      onPressed: _expandSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                    PopupMenuButton<_CollectionsFilter>(
                      tooltip: _filterTooltip(context),
                      icon: Icon(
                        _filter == _CollectionsFilter.all
                            ? Icons.filter_list_rounded
                            : Icons.filter_alt_rounded,
                      ),
                      initialValue: _filter,
                      onSelected: (value) {
                        setState(() => _filter = value);
                      },
                      itemBuilder: (context) => [
                        for (final filter in _CollectionsFilter.values)
                          PopupMenuItem<_CollectionsFilter>(
                            value: filter,
                            child: Row(
                              children: [
                                if (filter == _filter)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(Icons.check_rounded, size: 18),
                                  )
                                else
                                  const SizedBox(width: 26),
                                Text(_filterLabel(context, filter)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      tooltip: context.t.strings.collections.reorderShelf,
                      onPressed: reorderItems.length < 2
                          ? null
                          : () => _openReorderSheet(context, reorderItems),
                      icon: const Icon(Icons.reorder_rounded),
                    ),
                    IconButton(
                      tooltip: context.t.strings.collections.createCollection,
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add_rounded),
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
                      color: dividerColor,
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
      ),
    );
  }

  List<MemoCollectionDashboardItem> _filterItems(
    List<MemoCollectionDashboardItem> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return items
        .where((item) {
          final collection = item.collection;
          final includeByFilter = switch (_filter) {
            _CollectionsFilter.all => !collection.archived,
            _CollectionsFilter.smart =>
              !collection.archived &&
                  collection.type == MemoCollectionType.smart,
            _CollectionsFilter.manual =>
              !collection.archived &&
                  collection.type == MemoCollectionType.manual,
            _CollectionsFilter.archived => collection.archived,
          };
          if (!includeByFilter) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final title = collection.title.toLowerCase();
          final description = collection.description.toLowerCase();
          return title.contains(query) || description.contains(query);
        })
        .toList(growable: false);
  }

  List<MemoCollectionDashboardItem> _reorderableItems(
    List<MemoCollectionDashboardItem> items,
  ) {
    return items
        .where((item) {
          final collection = item.collection;
          return !collection.archived;
        })
        .toList(growable: false);
  }

  String _filterLabel(BuildContext context, _CollectionsFilter filter) {
    return switch (filter) {
      _CollectionsFilter.all => context.t.strings.legacy.msg_all_2,
      _CollectionsFilter.smart => context.t.strings.collections.smart,
      _CollectionsFilter.manual => context.t.strings.collections.manual,
      _CollectionsFilter.archived => context.t.strings.collections.archived,
    };
  }

  String _filterTooltip(BuildContext context) {
    final base = context.t.strings.legacy.msg_filter;
    final current = _filterLabel(context, _filter);
    return '$base: $current';
  }
}

class _CollectionsReorderSheet extends StatefulWidget {
  const _CollectionsReorderSheet({
    required this.items,
    required this.onReorder,
  });

  final List<MemoCollectionDashboardItem> items;
  final Future<void> Function(List<String> orderedIds) onReorder;

  @override
  State<_CollectionsReorderSheet> createState() =>
      _CollectionsReorderSheetState();
}

class _CollectionsReorderSheetState extends State<_CollectionsReorderSheet> {
  late final List<MemoCollectionDashboardItem> _items = widget.items.toList(
    growable: true,
  );
  bool _isSaving = false;

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (_isSaving) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _isSaving = true;
    });

    try {
      await widget.onReorder(
        _items.map((item) => item.collection.id).toList(growable: false),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : Colors.black54;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: SizedBox(
        height: height.clamp(360.0, 640.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collections.reorderShelf,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    collections.reorderShelfDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            if (_isSaving) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                itemCount: _items.length,
                onReorder: _handleReorder,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final collection = item.collection;
                  final preview = item.preview;
                  final chips = <Widget>[
                    _CollectionMetaChip(
                      icon: collection.type == MemoCollectionType.smart
                          ? Icons.auto_awesome_rounded
                          : Icons.drag_indicator_rounded,
                      label: collectionTypeLabel(context, collection.type),
                    ),
                    _CollectionMetaChip(
                      icon: Icons.note_alt_outlined,
                      label: collections.memosCount(count: preview.itemCount),
                    ),
                    if (collection.pinned)
                      _CollectionMetaChip(
                        icon: Icons.push_pin_outlined,
                        label: collections.pinned,
                      ),
                    if (collection.archived)
                      _CollectionMetaChip(
                        icon: Icons.archive_outlined,
                        label: collections.archived,
                      ),
                    if (collection.hideWhenEmpty && preview.isEmpty)
                      _CollectionMetaChip(
                        icon: Icons.visibility_off_outlined,
                        label: collections.hideWhenEmpty,
                      ),
                  ];

                  return Card(
                    key: ValueKey<String>(collection.id),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: Text(
                        collection.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
                      ),
                      trailing: Tooltip(
                        message: collections.dragToReorder,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionMetaChip extends StatelessWidget {
  const _CollectionMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final background = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.03);
    final color = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.item,
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onCopy,
    required this.onCopyDiagnostics,
    required this.onTogglePinned,
    required this.onToggleArchived,
    required this.onDelete,
  });

  final MemoCollectionDashboardItem item;
  final Account? account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onCopyDiagnostics;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleArchived;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final collection = item.collection;
    final preview = item.preview;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = resolveCollectionAccentColor(
      preview.effectiveAccentColorHex,
      isDark: isDark,
    );
    final textMuted = isDark ? Colors.white70 : Colors.black54;
    final summary = buildLocalizedCollectionRuleSummary(context, collection);
    final updatedText = preview.latestUpdateTime == null
        ? collections.noMemoMatchedYet
        : collections.updatedAt(
            date: DateFormat.yMMMd().add_Hm().format(preview.latestUpdateTime!),
          );
    final memosLabel = collections.memosCount(count: preview.itemCount);
    final stateLabel = <String>[
      collectionTypeLabel(context, collection.type),
      if (collection.pinned) collections.pinned,
      if (collection.archived) collections.archived,
      if (collection.hideWhenEmpty && preview.isEmpty)
        collections.hideWhenEmpty,
    ].join(' · ');
    final semanticsLabel = <String>[
      collection.title,
      summary,
      updatedText,
      if (collection.pinned) collections.pinned,
      if (collection.archived) collections.archived,
      if (collection.hideWhenEmpty && preview.isEmpty)
        collections.hideWhenEmpty,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: collections.openCollection,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 66,
                    child: _CollectionCover(
                      accent: accent,
                      attachment: preview.coverAttachment,
                      account: account,
                      iconKey: collection.cover.mode == CollectionCoverMode.icon
                          ? (collection.cover.iconKey ?? collection.iconKey)
                          : collection.iconKey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                collection.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: _CompactBadge(
                                label: '${preview.itemCount}',
                              ),
                            ),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: PopupMenuButton<String>(
                                  tooltip: collections.collectionActions,
                                  padding: EdgeInsets.zero,
                                  splashRadius: 16,
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    size: 20,
                                    color: textMuted,
                                  ),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        onEdit();
                                        return;
                                      case 'copy':
                                        onCopy();
                                        return;
                                      case 'diagnostics':
                                        onCopyDiagnostics();
                                        return;
                                      case 'pin':
                                        onTogglePinned();
                                        return;
                                      case 'archive':
                                        onToggleArchived();
                                        return;
                                      case 'delete':
                                        onDelete();
                                        return;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(
                                        context.t.strings.legacy.msg_edit,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'copy',
                                      child: Text(
                                        context.t.strings.legacy.msg_copy,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'diagnostics',
                                      child: Text(
                                        context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_copy_diagnostics,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Text(
                                        collection.pinned
                                            ? context.t.strings.legacy.msg_unpin
                                            : collections.pinToTop,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(
                                        collection.archived
                                            ? context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_restore
                                            : context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_archive,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        context.t.strings.legacy.msg_delete,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _InlineMetaRow(
                          icon: collection.type == MemoCollectionType.smart
                              ? Icons.auto_awesome_rounded
                              : Icons.collections_bookmark_rounded,
                          text: stateLabel,
                          color: textMuted,
                        ),
                        const SizedBox(height: 4),
                        _InlineMetaRow(
                          icon: Icons.notes_rounded,
                          text: memosLabel,
                          color: textMuted,
                        ),
                        const SizedBox(height: 4),
                        _InlineMetaRow(
                          icon: Icons.schedule_rounded,
                          text: updatedText,
                          color: textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMetaRow extends StatelessWidget {
  const _InlineMetaRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: color, height: 1.2),
          ),
        ),
      ],
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final foreground = isDark ? Colors.white70 : Colors.black54;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _CollectionCover extends StatelessWidget {
  const _CollectionCover({
    required this.accent,
    required this.attachment,
    required this.account,
    required this.iconKey,
    required this.borderRadius,
  });

  final Color accent;
  final Attachment? attachment;
  final Account? account;
  final String iconKey;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.9),
                  accent.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
          if (image != null) image,
          if (image == null)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  resolveCollectionIcon(iconKey),
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          if (image != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildImage() {
    final target = attachment;
    if (target == null) return null;
    final remoteUrl = resolveAttachmentRemoteUrl(account?.baseUrl, target);
    if (remoteUrl != null && remoteUrl.trim().isNotEmpty) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    }

    final raw = target.externalLink.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('file://')) {
      final file = File(Uri.parse(raw).toFilePath());
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    if (raw.contains(':\\') || raw.startsWith('/')) {
      final file = File(raw);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    return null;
  }
}
