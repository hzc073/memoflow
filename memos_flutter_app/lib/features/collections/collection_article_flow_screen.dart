import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../data/models/collection_article_flow.dart';
import '../../data/models/collection_readable_item.dart';
import '../../data/models/collection_reader.dart';
import '../../data/models/memo_collection.dart';
import '../../data/models/rss_article.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collection_article_flow.dart';
import '../../state/collections/collection_article_flow_progress_provider.dart';
import '../../state/collections/collection_rss_providers.dart';
import '../../state/collections/collections_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../memos/widgets/memo_reader_content.dart';
import 'collection_editor_screen.dart';
import 'collection_rss_html_content.dart';
import 'collection_rss_subscription_sheet.dart';

class CollectionArticleFlowScreen extends ConsumerStatefulWidget {
  const CollectionArticleFlowScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<CollectionArticleFlowScreen> createState() =>
      _CollectionArticleFlowScreenState();
}

class _CollectionArticleFlowScreenState
    extends ConsumerState<CollectionArticleFlowScreen> {
  static const double _twoPaneBreakpoint = 760;
  static const Duration _saveDebounceDelay = Duration(milliseconds: 350);

  final ScrollController _listController = ScrollController();
  late final CollectionArticleFlowProgressRepository _progressRepository;
  Timer? _saveDebounce;

  CollectionArticleFlowStatusFilter _statusFilter =
      CollectionArticleFlowStatusFilter.all;
  String? _feedId;
  String? _dateBucketKey;
  String? _selectedUid;
  bool _progressReady = false;
  bool _restoredScroll = false;
  double _lastKnownListScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _progressRepository = ref.read(
      collectionArticleFlowProgressRepositoryProvider,
    );
    _listController.addListener(_handleListScroll);
    unawaited(_loadProgress());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_persistProgress(force: true));
    _listController
      ..removeListener(_handleListScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final progress = await _progressRepository.load(widget.collectionId);
    if (!mounted) return;
    setState(() {
      if (progress != null) {
        _statusFilter = progress.statusFilter;
        _feedId = progress.feedId;
        _dateBucketKey = progress.dateBucketKey;
        _selectedUid = progress.currentItemUid;
        _lastKnownListScrollOffset = progress.listScrollOffset;
      }
      _progressReady = true;
    });
  }

  void _handleListScroll() {
    if (!_listController.hasClients) return;
    _lastKnownListScrollOffset = _listController.offset;
    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    if (!_progressReady) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDelay, () {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress({bool force = false}) async {
    if (!_progressReady && !force) return;
    final progress = CollectionArticleFlowProgress(
      collectionId: widget.collectionId,
      statusFilter: _statusFilter,
      feedId: _feedId,
      dateBucketKey: _dateBucketKey,
      currentItemUid: _selectedUid,
      listScrollOffset: _listController.hasClients
          ? _listController.offset
          : _lastKnownListScrollOffset,
      updatedAt: DateTime.now(),
    );
    await _progressRepository.save(progress);
  }

  void _restoreListScrollIfNeeded() {
    if (_restoredScroll || !_progressReady || _lastKnownListScrollOffset <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients || _restoredScroll) return;
      final maxScroll = _listController.position.maxScrollExtent;
      _listController.jumpTo(
        _lastKnownListScrollOffset.clamp(0, math.max(0, maxScroll)),
      );
      _restoredScroll = true;
    });
  }

  void _setStatusFilter(CollectionArticleFlowStatusFilter filter) {
    setState(() {
      _statusFilter = filter;
      _selectedUid = null;
    });
    _scheduleProgressSave();
  }

  void _setFeedFilter(String? feedId) {
    setState(() {
      _feedId = feedId?.trim().isEmpty == true ? null : feedId?.trim();
      _selectedUid = null;
    });
    _scheduleProgressSave();
  }

  void _setDateFilter(String? bucketKey) {
    setState(() {
      _dateBucketKey = bucketKey?.trim().isEmpty == true
          ? null
          : bucketKey?.trim();
      _selectedUid = null;
    });
    _scheduleProgressSave();
  }

  Future<void> _selectItem(
    CollectionReadableItem item, {
    required List<CollectionReadableItem> filteredItems,
    required bool twoPane,
  }) async {
    setState(() => _selectedUid = item.uid);
    _scheduleProgressSave();
    if (twoPane) {
      await _markReadOnOpen(item);
    }
    if (!mounted || twoPane) return;
    final index = filteredItems.indexWhere((entry) => entry.uid == item.uid);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CollectionArticleDetailPage(
          collectionId: widget.collectionId,
          initialItems: filteredItems,
          initialIndex: math.max(0, index),
          statusFilter: _statusFilter,
          feedId: _feedId,
          dateBucketKey: _dateBucketKey,
        ),
      ),
    );
  }

  Future<void> _markReadOnOpen(CollectionReadableItem item) {
    if (item.kind != CollectionReadableItemKind.rssArticle || item.isRead) {
      return Future<void>.value();
    }
    return ref.read(collectionRssActionsProvider).markRead(item, true);
  }

  Future<void> _toggleRead(CollectionReadableItem item) {
    return ref.read(collectionRssActionsProvider).markRead(item, !item.isRead);
  }

  Future<void> _saveAsMemo(CollectionReadableItem item) async {
    final memoUid = await ref
        .read(collectionRssActionsProvider)
        .saveAsMemo(item);
    if (!mounted || memoUid == null) return;
    _showSnack(context.t.strings.collections.rss.savedAsMemo);
  }

  Future<void> _markRelativeAsRead(
    List<CollectionReadableItem> items,
    bool above,
  ) async {
    final selectedUid = _selectedUid;
    if (selectedUid == null || selectedUid.isEmpty) return;
    final selectedIndex = items.indexWhere((item) => item.uid == selectedUid);
    if (selectedIndex < 0) return;
    final range = above
        ? items.take(selectedIndex)
        : items.skip(selectedIndex + 1);
    final actions = ref.read(collectionRssActionsProvider);
    for (final item in range) {
      if (item.kind == CollectionReadableItemKind.rssArticle && !item.isRead) {
        await actions.markRead(item, true);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final collectionsStrings = context.t.strings.collections;
    final articleFlowStrings = collectionsStrings.articleFlow;
    final collectionAsync = ref.watch(
      collectionByIdProvider(widget.collectionId),
    );
    final itemsAsync = ref.watch(
      collectionResolvedReadableItemsProvider(widget.collectionId),
    );
    if (collectionAsync.isLoading || itemsAsync.isLoading || !_progressReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (collectionAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              resolveDesktopRouteAutomaticallyImplyLeading(
                context: context,
                automaticallyImplyLeading: true,
              ),
        ),
        body: Center(child: Text('${collectionAsync.error}')),
      );
    }
    if (itemsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              resolveDesktopRouteAutomaticallyImplyLeading(
                context: context,
                automaticallyImplyLeading: true,
              ),
        ),
        body: Center(child: Text('${itemsAsync.error}')),
      );
    }
    final collection = collectionAsync.valueOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              resolveDesktopRouteAutomaticallyImplyLeading(
                context: context,
                automaticallyImplyLeading: true,
              ),
        ),
        body: Center(child: Text(collectionsStrings.collectionNotFound)),
      );
    }
    final sourceItems =
        itemsAsync.valueOrNull ?? const <CollectionReadableItem>[];
    final listModel = buildCollectionArticleFlowList(
      sourceItems: sourceItems,
      statusFilter: _statusFilter,
      feedId: _feedId,
      dateBucketKey: _dateBucketKey,
    );
    _restoreListScrollIfNeeded();
    final title = collection.title.trim().isEmpty
        ? collectionsStrings.collection
        : collection.title.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= _twoPaneBreakpoint;
        final selectedItem = _resolveSelectedItem(listModel.items, twoPane);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading:
                resolveDesktopRouteAutomaticallyImplyLeading(
                  context: context,
                  automaticallyImplyLeading: true,
                ),
            title: Text(title),
            actions: [
              PopupMenuButton<_ArticleFlowMenuAction>(
                tooltip: articleFlowStrings.listActions,
                onSelected: (action) async {
                  switch (action) {
                    case _ArticleFlowMenuAction.markAboveRead:
                      await _markRelativeAsRead(listModel.items, true);
                    case _ArticleFlowMenuAction.markBelowRead:
                      await _markRelativeAsRead(listModel.items, false);
                    case _ArticleFlowMenuAction.articleFlowExperience:
                      await ref
                          .read(collectionViewPreferenceActionsProvider)
                          .setReadingExperience(
                            collection.id,
                            CollectionReadingExperience.articleFlow,
                          );
                    case _ArticleFlowMenuAction.continuousReaderExperience:
                      await ref
                          .read(collectionViewPreferenceActionsProvider)
                          .setReadingExperience(
                            collection.id,
                            CollectionReadingExperience.continuousReader,
                          );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ArticleFlowMenuAction.markAboveRead,
                    enabled: _selectedUid != null,
                    child: Text(articleFlowStrings.markAboveRead),
                  ),
                  PopupMenuItem(
                    value: _ArticleFlowMenuAction.markBelowRead,
                    enabled: _selectedUid != null,
                    child: Text(articleFlowStrings.markBelowRead),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _ArticleFlowMenuAction.articleFlowExperience,
                    child: Text(articleFlowStrings.articleFlowExperience),
                  ),
                  PopupMenuItem(
                    value: _ArticleFlowMenuAction.continuousReaderExperience,
                    child: Text(articleFlowStrings.continuousReaderExperience),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _ArticleFlowFilterBar(
                collection: collection,
                listModel: listModel,
                statusFilter: _statusFilter,
                feedId: _feedId,
                dateBucketKey: _dateBucketKey,
                onStatusChanged: _setStatusFilter,
                onFeedChanged: _setFeedFilter,
                onDateChanged: _setDateFilter,
              ),
              const Divider(height: 1),
              Expanded(
                child: sourceItems.isEmpty
                    ? _ArticleFlowEmptyState(collection: collection)
                    : twoPane
                    ? Row(
                        children: [
                          SizedBox(
                            width: math.min(430, constraints.maxWidth * 0.42),
                            child: _ArticleFlowList(
                              controller: _listController,
                              collection: collection,
                              items: listModel.items,
                              selectedUid: selectedItem?.uid,
                              display: collection.view.articleFlowDisplay,
                              onTap: (item) => _selectItem(
                                item,
                                filteredItems: listModel.items,
                                twoPane: true,
                              ),
                              onToggleRead: _toggleRead,
                              onSaveAsMemo: _saveAsMemo,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: selectedItem == null
                                ? Center(
                                    child: Text(articleFlowStrings.noSelected),
                                  )
                                : CollectionArticleDetailView(
                                    collectionId: collection.id,
                                    collectionTitle: title,
                                    item: selectedItem,
                                    items: listModel.items,
                                    display: collection.view.articleFlowDisplay,
                                    showBack: false,
                                    onBack: null,
                                    onSelected: (item) async {
                                      await _selectItem(
                                        item,
                                        filteredItems: listModel.items,
                                        twoPane: true,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      )
                    : _ArticleFlowList(
                        controller: _listController,
                        collection: collection,
                        items: listModel.items,
                        selectedUid: _selectedUid,
                        display: collection.view.articleFlowDisplay,
                        onTap: (item) => _selectItem(
                          item,
                          filteredItems: listModel.items,
                          twoPane: false,
                        ),
                        onToggleRead: _toggleRead,
                        onSaveAsMemo: _saveAsMemo,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  CollectionReadableItem? _resolveSelectedItem(
    List<CollectionReadableItem> items,
    bool twoPane,
  ) {
    if (items.isEmpty) return null;
    final selectedUid = _selectedUid;
    if (selectedUid != null) {
      for (final item in items) {
        if (item.uid == selectedUid) return item;
      }
    }
    if (!twoPane) return null;
    final first = items.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedUid == null) {
        setState(() => _selectedUid = first.uid);
        _scheduleProgressSave();
        unawaited(_markReadOnOpen(first));
      }
    });
    return first;
  }
}

class _ArticleFlowFilterBar extends StatelessWidget {
  const _ArticleFlowFilterBar({
    required this.collection,
    required this.listModel,
    required this.statusFilter,
    required this.feedId,
    required this.dateBucketKey,
    required this.onStatusChanged,
    required this.onFeedChanged,
    required this.onDateChanged,
  });

  final MemoCollection collection;
  final CollectionArticleFlowListModel listModel;
  final CollectionArticleFlowStatusFilter statusFilter;
  final String? feedId;
  final String? dateBucketKey;
  final ValueChanged<CollectionArticleFlowStatusFilter> onStatusChanged;
  final ValueChanged<String?> onFeedChanged;
  final ValueChanged<String?> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.strings.collections.articleFlow;
    final isRss = collection.type == MemoCollectionType.rss;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          if (isRss)
            for (final filter in CollectionArticleFlowStatusFilter.values) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: statusFilter == filter,
                  label: Text(_statusLabel(strings, filter)),
                  onSelected: (_) => onStatusChanged(filter),
                ),
              ),
            ],
          if (isRss && listModel.feedOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MenuChip<String?>(
                icon: Icons.rss_feed_rounded,
                label: _feedLabel(strings, listModel.feedOptions, feedId),
                values: <String?>[
                  null,
                  ...listModel.feedOptions.map((option) => option.feedId),
                ],
                itemLabel: (value) =>
                    _feedLabel(strings, listModel.feedOptions, value),
                onSelected: onFeedChanged,
              ),
            ),
          if (listModel.dateOptions.isNotEmpty)
            _MenuChip<String?>(
              icon: Icons.calendar_today_rounded,
              label: _dateLabel(strings, listModel.dateOptions, dateBucketKey),
              values: <String?>[
                null,
                ...listModel.dateOptions.map((option) => option.bucketKey),
              ],
              itemLabel: (value) =>
                  _dateLabel(strings, listModel.dateOptions, value),
              onSelected: onDateChanged,
            ),
        ],
      ),
    );
  }

  String _statusLabel(
    dynamic strings,
    CollectionArticleFlowStatusFilter filter,
  ) {
    return switch (filter) {
      CollectionArticleFlowStatusFilter.all => strings.filterAll,
      CollectionArticleFlowStatusFilter.unread => strings.filterUnread,
      CollectionArticleFlowStatusFilter.read => strings.filterRead,
      CollectionArticleFlowStatusFilter.saved => strings.filterSaved,
    };
  }

  String _feedLabel(
    dynamic strings,
    List<CollectionArticleFlowFeedOption> options,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return strings.feedAll;
    }
    for (final option in options) {
      if (option.feedId == normalized) {
        return '${option.title} (${option.count})';
      }
    }
    return strings.feedAll;
  }

  String _dateLabel(
    dynamic strings,
    List<CollectionArticleFlowDateOption> options,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return strings.dateAll;
    }
    for (final option in options) {
      if (option.bucketKey == normalized) {
        return '${DateFormat.yMMMd().format(option.date)} (${option.count})';
      }
    }
    return strings.dateAll;
  }
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.values,
    required this.itemLabel,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem<T>(value: value, child: Text(itemLabel(value))),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _ArticleFlowList extends StatelessWidget {
  const _ArticleFlowList({
    required this.controller,
    required this.collection,
    required this.items,
    required this.selectedUid,
    required this.display,
    required this.onTap,
    required this.onToggleRead,
    required this.onSaveAsMemo,
  });

  final ScrollController controller;
  final MemoCollection collection;
  final List<CollectionReadableItem> items;
  final String? selectedUid;
  final CollectionArticleFlowDisplaySettings display;
  final ValueChanged<CollectionReadableItem> onTap;
  final Future<void> Function(CollectionReadableItem item) onToggleRead;
  final Future<void> Function(CollectionReadableItem item) onSaveAsMemo;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.strings.collections.articleFlow;
    if (items.isEmpty) {
      return Center(child: Text(strings.noItems));
    }
    return ListView.builder(
      controller: controller,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bucket = CollectionArticleFlowDateBucket.fromDate(
          item.effectiveDisplayTime,
        );
        final previousBucket = index <= 0
            ? null
            : CollectionArticleFlowDateBucket.fromDate(
                items[index - 1].effectiveDisplayTime,
              ).key;
        final showHeader = previousBucket != bucket.key;
        final row = _ArticleFlowRow(
          item: item,
          selected: item.uid == selectedUid,
          display: display,
          onTap: () => onTap(item),
        );
        final child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: EdgeInsets.fromLTRB(16, index == 0 ? 14 : 20, 16, 6),
                child: Text(
                  DateFormat.yMMMd().format(
                    bucket.date ?? item.effectiveDisplayTime,
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            row,
          ],
        );
        if (item.kind != CollectionReadableItemKind.rssArticle) {
          return child;
        }
        return Dismissible(
          key: ValueKey<String>('article-flow-${item.uid}'),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await onToggleRead(item);
            } else {
              await onSaveAsMemo(item);
            }
            return false;
          },
          background: _DismissBackground(
            alignment: Alignment.centerLeft,
            icon: item.isRead
                ? Icons.mark_email_unread_outlined
                : Icons.done_all_rounded,
            label: item.isRead
                ? context.t.strings.collections.rss.markUnread
                : context.t.strings.collections.rss.markRead,
          ),
          secondaryBackground: _DismissBackground(
            alignment: Alignment.centerRight,
            icon: Icons.bookmark_add_outlined,
            label: context.t.strings.collections.rss.saveAsMemo,
          ),
          child: child,
        );
      },
    );
  }
}

class _ArticleFlowRow extends StatelessWidget {
  const _ArticleFlowRow({
    required this.item,
    required this.selected,
    required this.display,
    required this.onTap,
  });

  final CollectionReadableItem item;
  final bool selected;
  final CollectionArticleFlowDisplaySettings display;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dense = display.density == CollectionArticleFlowDensity.compact;
    final rssArticle = item.rssArticle;
    final feed = item.rssFeed;
    final saved = item.savedMemoUid?.trim().isNotEmpty == true;
    final excerpt = buildCollectionArticleFlowExcerpt(item);
    final thumbnail = rssArticle?.leadImageUrl.trim() ?? '';
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.58)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: dense ? 8 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (display.showFeedIcon && feed != null) ...[
                _NetworkCircleImage(
                  url: feed.iconUrl,
                  fallback: Icons.rss_feed,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.kind ==
                                CollectionReadableItemKind.rssArticle &&
                            !item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            item.title.trim().isEmpty
                                ? context.t.strings.collections.collection
                                : item.title.trim(),
                            maxLines: dense ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (feed != null)
                          Text(
                            feed.displayTitle,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          DateFormat.MMMd().add_Hm().format(
                            item.effectiveDisplayTime,
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (saved)
                          Icon(
                            Icons.bookmark_added_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                    if (display.showExcerpt && excerpt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        excerpt,
                        maxLines: dense ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (display.showThumbnail && thumbnail.isNotEmpty) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumbnail,
                    width: dense ? 64 : 82,
                    height: dense ? 50 : 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.primaryContainer,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkCircleImage extends StatelessWidget {
  const _NetworkCircleImage({required this.url, required this.fallback});

  final String url;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    final colorScheme = Theme.of(context).colorScheme;
    if (trimmed.isEmpty) {
      return CircleAvatar(radius: 16, child: Icon(fallback, size: 18));
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: NetworkImage(trimmed),
      onBackgroundImageError: (exception, stackTrace) {},
    );
  }
}

class _ArticleFlowEmptyState extends StatelessWidget {
  const _ArticleFlowEmptyState({required this.collection});

  final MemoCollection collection;

  @override
  Widget build(BuildContext context) {
    final collectionsStrings = context.t.strings.collections;
    final isRss = collection.type == MemoCollectionType.rss;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRss
                  ? collectionsStrings.rss.noArticles
                  : collectionsStrings.emptyManualDetail,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (isRss)
              FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => CollectionRssSubscriptionSheet(
                    collectionId: collection.id,
                  ),
                ),
                icon: const Icon(Icons.rss_feed_rounded),
                label: Text(collectionsStrings.rss.addFeed),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CollectionEditorScreen(initialCollection: collection),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded),
                label: Text(collectionsStrings.editCollection),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionArticleDetailPage extends ConsumerStatefulWidget {
  const _CollectionArticleDetailPage({
    required this.collectionId,
    required this.initialItems,
    required this.initialIndex,
    required this.statusFilter,
    required this.feedId,
    required this.dateBucketKey,
  });

  final String collectionId;
  final List<CollectionReadableItem> initialItems;
  final int initialIndex;
  final CollectionArticleFlowStatusFilter statusFilter;
  final String? feedId;
  final String? dateBucketKey;

  @override
  ConsumerState<_CollectionArticleDetailPage> createState() =>
      _CollectionArticleDetailPageState();
}

class _CollectionArticleDetailPageState
    extends ConsumerState<_CollectionArticleDetailPage> {
  late String _currentUid;

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialIndex
        .clamp(0, math.max(0, widget.initialItems.length - 1))
        .toInt();
    _currentUid = widget.initialItems.isEmpty
        ? ''
        : widget.initialItems[safeIndex].uid;
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref
        .watch(collectionByIdProvider(widget.collectionId))
        .valueOrNull;
    final liveItems =
        ref
            .watch(collectionResolvedReadableItemsProvider(widget.collectionId))
            .valueOrNull ??
        widget.initialItems;
    final filtered = buildCollectionArticleFlowList(
      sourceItems: liveItems,
      statusFilter: widget.statusFilter,
      feedId: widget.feedId,
      dateBucketKey: widget.dateBucketKey,
    ).items;
    CollectionReadableItem? item;
    for (final entry in filtered) {
      if (entry.uid == _currentUid) {
        item = entry;
        break;
      }
    }
    item ??= filtered.isNotEmpty
        ? filtered.first
        : widget.initialItems.isNotEmpty
        ? widget.initialItems.first
        : null;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              resolveDesktopRouteAutomaticallyImplyLeading(
                context: context,
                automaticallyImplyLeading: true,
              ),
        ),
        body: Center(
          child: Text(context.t.strings.collections.articleFlow.noItems),
        ),
      );
    }
    final title = collection?.title.trim().isNotEmpty == true
        ? collection!.title.trim()
        : context.t.strings.collections.collection;
    return Scaffold(
      body: CollectionArticleDetailView(
        collectionId: widget.collectionId,
        collectionTitle: title,
        item: item,
        items: filtered.isEmpty ? widget.initialItems : filtered,
        display:
            collection?.view.articleFlowDisplay ??
            CollectionArticleFlowDisplaySettings.defaults,
        showBack: true,
        onBack: () => Navigator.of(context).maybePop(),
        onSelected: (next) => setState(() => _currentUid = next.uid),
      ),
    );
  }
}

class CollectionArticleDetailView extends ConsumerStatefulWidget {
  const CollectionArticleDetailView({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
    required this.item,
    required this.items,
    required this.display,
    required this.showBack,
    required this.onBack,
    required this.onSelected,
  });

  final String collectionId;
  final String collectionTitle;
  final CollectionReadableItem item;
  final List<CollectionReadableItem> items;
  final CollectionArticleFlowDisplaySettings display;
  final bool showBack;
  final VoidCallback? onBack;
  final ValueChanged<CollectionReadableItem> onSelected;

  @override
  ConsumerState<CollectionArticleDetailView> createState() =>
      _CollectionArticleDetailViewState();
}

class _CollectionArticleDetailViewState
    extends ConsumerState<CollectionArticleDetailView> {
  final ScrollController _scrollController = ScrollController();
  bool _barsVisible = true;
  String? _openedUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markOpenedRead());
  }

  @override
  void didUpdateWidget(covariant CollectionArticleDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.uid != widget.item.uid) {
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _markOpenedRead());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markOpenedRead() async {
    if (!mounted || _openedUid == widget.item.uid) return;
    _openedUid = widget.item.uid;
    if (widget.item.kind == CollectionReadableItemKind.rssArticle &&
        !widget.item.isRead) {
      await ref.read(collectionRssActionsProvider).markRead(widget.item, true);
    }
  }

  void _handleScroll(UserScrollNotification notification) {
    if (!widget.display.autoHideToolbar) return;
    final nextVisible = switch (notification.direction) {
      ScrollDirection.forward => true,
      ScrollDirection.reverse => false,
      ScrollDirection.idle => _barsVisible,
    };
    if (nextVisible != _barsVisible) {
      setState(() => _barsVisible = nextVisible);
    }
  }

  Future<void> _share() async {
    final url = widget.item.originalUrl?.trim();
    final text = [
      widget.item.title.trim(),
      if (url != null && url.isNotEmpty) url,
    ].where((part) => part.isNotEmpty).join('\n');
    if (text.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(text: text, subject: widget.item.title.trim()),
    );
  }

  Future<void> _openOriginal() async {
    final url = widget.item.originalUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleRead() {
    return ref
        .read(collectionRssActionsProvider)
        .markRead(widget.item, !widget.item.isRead);
  }

  Future<void> _saveAsMemo() async {
    final memoUid = await ref
        .read(collectionRssActionsProvider)
        .saveAsMemo(widget.item);
    if (!mounted || memoUid == null) return;
    _showSnack(context.t.strings.collections.rss.savedAsMemo);
  }

  Future<void> _fetchFullContent() async {
    final result = await ref
        .read(collectionRssActionsProvider)
        .fetchFullContent(widget.item);
    if (!mounted || result == null) return;
    final rssStrings = context.t.strings.collections.rss;
    _showSnack(switch (result.status) {
      RssArticleFullContentStatus.fetched => rssStrings.fullContentFetched,
      RssArticleFullContentStatus.failed => rssStrings.fullContentFailed,
      RssArticleFullContentStatus.skipped => rssStrings.fullContentSkipped,
      _ => rssStrings.fetchingFullContent,
    });
  }

  void _nextArticle() {
    final index = widget.items.indexWhere(
      (item) => item.uid == widget.item.uid,
    );
    if (index < 0 || index >= widget.items.length - 1) return;
    widget.onSelected(widget.items[index + 1]);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(
      devicePreferencesProvider.select(
        (prefs) => prefs.collectionReaderPreferences,
      ),
    );
    final theme = Theme.of(context);
    final bodyTextStyle = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 18 * preferences.textScale,
      height: preferences.lineSpacing,
      fontFamily: preferences.readerFontFamily,
      fontWeight: _resolveReaderFontWeight(preferences.fontWeightMode),
      letterSpacing: preferences.letterSpacing,
    );
    final metaTextStyle = theme.textTheme.bodySmall!.copyWith(
      fontSize: 13 * preferences.textScale,
      height: 1.4,
      fontFamily: preferences.readerFontFamily,
      letterSpacing: preferences.letterSpacing,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final article = widget.item.rssArticle;
    final fullContentStatus = article?.fullContentStatus;
    final fetchingFullContent =
        fullContentStatus == RssArticleFullContentStatus.fetching;
    final fullContentFailed =
        fullContentStatus == RssArticleFullContentStatus.failed;
    final fullContentSkipped =
        fullContentStatus == RssArticleFullContentStatus.skipped;
    final canFetchFullContent =
        collectionArticleFlowItemCanFetchFullContent(widget.item) &&
        !fetchingFullContent;
    final currentIndex = widget.items.indexWhere(
      (item) => item.uid == widget.item.uid,
    );
    final canGoNext =
        currentIndex >= 0 && currentIndex < widget.items.length - 1;
    final topBar = _ArticleDetailTopBar(
      title: widget.item.title.trim().isEmpty
          ? widget.collectionTitle
          : widget.item.title.trim(),
      showBack: widget.showBack,
      onBack: widget.onBack,
      canOpenOriginal: widget.item.originalUrl?.trim().isNotEmpty == true,
      onShare: _share,
      onOpenOriginal: _openOriginal,
    );
    final bottomBar = _ArticleDetailBottomBar(
      item: widget.item,
      canGoNext: canGoNext,
      fetchingFullContent: fetchingFullContent,
      canFetchFullContent: canFetchFullContent,
      retryFullContent: fullContentFailed || fullContentSkipped,
      onToggleRead: _toggleRead,
      onSaveAsMemo: _saveAsMemo,
      onNext: _nextArticle,
      onFetchFullContent: _fetchFullContent,
    );
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _handleScroll(notification);
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                preferences.pagePadding.left,
                preferences.pagePadding.top + 72,
                preferences.pagePadding.right,
                preferences.pagePadding.bottom + 92,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _ArticleDetailBody(
                    item: widget.item,
                    bodyTextStyle: bodyTextStyle,
                    metaTextStyle: metaTextStyle,
                    allowTextSelection:
                        preferences.displayConfig.allowTextSelection,
                    previewImageOnTap:
                        preferences.displayConfig.previewImageOnTap,
                    fullContentFailed: fullContentFailed,
                    fullContentSkipped: fullContentSkipped,
                    canFetchFullContent: canFetchFullContent,
                    onRetryFullContent: _fetchFullContent,
                    onOpenOriginal: _openOriginal,
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            top: _barsVisible ? 0 : -80,
            left: 0,
            right: 0,
            child: topBar,
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            bottom: _barsVisible ? 0 : -92,
            left: 0,
            right: 0,
            child: bottomBar,
          ),
        ],
      ),
    );
  }
}

class _ArticleDetailTopBar extends StatelessWidget {
  const _ArticleDetailTopBar({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.canOpenOriginal,
    required this.onShare,
    required this.onOpenOriginal,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final bool canOpenOriginal;
  final VoidCallback onShare;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.96),
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.t.strings.collections.articleFlow.share,
                icon: const Icon(Icons.share_outlined),
                onPressed: onShare,
              ),
              IconButton(
                tooltip: context.t.strings.collections.rss.openOriginal,
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: canOpenOriginal ? onOpenOriginal : null,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleDetailBottomBar extends StatelessWidget {
  const _ArticleDetailBottomBar({
    required this.item,
    required this.canGoNext,
    required this.fetchingFullContent,
    required this.canFetchFullContent,
    required this.retryFullContent,
    required this.onToggleRead,
    required this.onSaveAsMemo,
    required this.onNext,
    required this.onFetchFullContent,
  });

  final CollectionReadableItem item;
  final bool canGoNext;
  final bool fetchingFullContent;
  final bool canFetchFullContent;
  final bool retryFullContent;
  final VoidCallback onToggleRead;
  final VoidCallback onSaveAsMemo;
  final VoidCallback onNext;
  final VoidCallback onFetchFullContent;

  @override
  Widget build(BuildContext context) {
    final rssStrings = context.t.strings.collections.rss;
    final articleFlowStrings = context.t.strings.collections.articleFlow;
    final isRss = item.kind == CollectionReadableItemKind.rssArticle;
    final saved = item.savedMemoUid?.trim().isNotEmpty == true;
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: item.isRead
                    ? rssStrings.markUnread
                    : rssStrings.markRead,
                icon: Icon(
                  item.isRead
                      ? Icons.mark_email_unread_outlined
                      : Icons.done_all_rounded,
                ),
                onPressed: isRss ? onToggleRead : null,
              ),
              IconButton(
                tooltip: saved ? rssStrings.savedAsMemo : rssStrings.saveAsMemo,
                icon: Icon(
                  saved
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                ),
                onPressed: isRss && !saved ? onSaveAsMemo : null,
              ),
              IconButton(
                tooltip: articleFlowStrings.nextArticle,
                icon: const Icon(Icons.navigate_next_rounded),
                onPressed: canGoNext ? onNext : null,
              ),
              IconButton(
                tooltip: retryFullContent
                    ? rssStrings.retryFullContent
                    : rssStrings.fetchFullContent,
                icon: fetchingFullContent
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                onPressed: isRss && canFetchFullContent
                    ? onFetchFullContent
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleDetailBody extends StatelessWidget {
  const _ArticleDetailBody({
    required this.item,
    required this.bodyTextStyle,
    required this.metaTextStyle,
    required this.allowTextSelection,
    required this.previewImageOnTap,
    required this.fullContentFailed,
    required this.fullContentSkipped,
    required this.canFetchFullContent,
    required this.onRetryFullContent,
    required this.onOpenOriginal,
  });

  final CollectionReadableItem item;
  final TextStyle bodyTextStyle;
  final TextStyle metaTextStyle;
  final bool allowTextSelection;
  final bool previewImageOnTap;
  final bool fullContentFailed;
  final bool fullContentSkipped;
  final bool canFetchFullContent;
  final VoidCallback onRetryFullContent;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final memo = item.localMemo;
    Widget content;
    if (memo != null) {
      content = MemoReaderContent(
        memo: memo,
        highlightQuery: null,
        padding: const EdgeInsets.symmetric(vertical: 8),
        contentTextStyle: bodyTextStyle,
        metaTextStyle: metaTextStyle,
        selectable: allowTextSelection,
        previewImageOnTap: previewImageOnTap,
        mediaMaxHeightFactor: 0.38,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fullContentFailed || fullContentSkipped)
            _FullContentFallbackBanner(
              failed: fullContentFailed,
              canRetry: canFetchFullContent,
              onRetry: onRetryFullContent,
              onOpenOriginal: onOpenOriginal,
            ),
          CollectionRssHtmlContent(
            html: item.content,
            textStyle: bodyTextStyle,
          ),
        ],
      );
    }
    if (!allowTextSelection || memo != null) {
      return content;
    }
    return SelectionArea(child: content);
  }
}

class _FullContentFallbackBanner extends StatelessWidget {
  const _FullContentFallbackBanner({
    required this.failed,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenOriginal,
  });

  final bool failed;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final rssStrings = context.t.strings.collections.rss;
    final strings = context.t.strings.collections.articleFlow;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failed
                ? rssStrings.fullContentFailed
                : rssStrings.fullContentSkipped,
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.fullContentFallback,
            style: TextStyle(color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canRetry ? onRetry : null,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(rssStrings.retryFullContent),
              ),
              OutlinedButton.icon(
                onPressed: onOpenOriginal,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(rssStrings.openOriginal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

FontWeight _resolveReaderFontWeight(CollectionReaderFontWeightMode mode) {
  return switch (mode) {
    CollectionReaderFontWeightMode.normal => FontWeight.w400,
    CollectionReaderFontWeightMode.medium => FontWeight.w500,
    CollectionReaderFontWeightMode.bold => FontWeight.w700,
  };
}

enum _ArticleFlowMenuAction {
  markAboveRead,
  markBelowRead,
  articleFlowExperience,
  continuousReaderExperience,
}
