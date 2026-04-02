import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/tag_colors.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_menu_button.dart';
import '../memos/memos_list_screen.dart';
import '../memos/recycle_bin_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import 'tag_edit_sheet.dart';
import '../../i18n/strings.g.dart';

enum _TagsFilterMode { all, frequent, recent, pinned }

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final TextEditingController _searchController = TextEditingController();
  _TagsFilterMode _filterMode = _TagsFilterMode.all;

  List<TagStat> _applyFilterMode(List<TagStat> tags) {
    final items = List<TagStat>.of(tags, growable: false);
    switch (_filterMode) {
      case _TagsFilterMode.all:
        return items;
      case _TagsFilterMode.frequent:
        final sorted = items.toList(growable: false);
        sorted.sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          final byRecent = (b.lastUsedTimeSec ?? 0).compareTo(
            a.lastUsedTimeSec ?? 0,
          );
          if (byRecent != 0) return byRecent;
          return a.tag.compareTo(b.tag);
        });
        return sorted;
      case _TagsFilterMode.recent:
        final sorted = items.toList(growable: false);
        sorted.sort((a, b) {
          final byRecent = (b.lastUsedTimeSec ?? 0).compareTo(
            a.lastUsedTimeSec ?? 0,
          );
          if (byRecent != 0) return byRecent;
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return a.tag.compareTo(b.tag);
        });
        return sorted;
      case _TagsFilterMode.pinned:
        return items.where((tag) => tag.pinned).toList(growable: false);
    }
  }

  String _filterLabel(BuildContext context, _TagsFilterMode filter) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return switch (filter) {
      _TagsFilterMode.all => context.t.strings.legacy.msg_all_tags,
      _TagsFilterMode.frequent => switch (languageCode) {
        'de' => 'Häufig',
        'ja' => 'よく使う',
        'zh' => '常用',
        _ => 'Frequent',
      },
      _TagsFilterMode.recent => switch (languageCode) {
        'de' => 'Zuletzt',
        'ja' => '最近',
        'zh' => '最近',
        _ => 'Recent',
      },
      _TagsFilterMode.pinned => context.t.strings.legacy.msg_pinned,
    };
  }

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
    final route = switch (dest) {
      AppDrawerDestination.memos => const MemosListScreen(
        title: 'MemoFlow',
        state: 'NORMAL',
        showDrawer: true,
        enableCompose: true,
      ),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
        title: context.t.strings.legacy.msg_archive,
        state: 'ARCHIVED',
        showDrawer: true,
      ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.recycleBin => const RecycleBinScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    closeDrawerThenPushReplacement(context, route);
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

  List<TagStat> _buildVisibleTags(List<TagStat> tags) {
    Iterable<TagStat> visible = _applyFilterMode(tags);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      visible = visible.where((tag) {
        final path = tag.path.toLowerCase();
        return path.contains(query);
      });
    }

    return visible.toList(growable: false);
  }

  void _resetFilters() {
    if (_searchController.text.isEmpty && _filterMode == _TagsFilterMode.all) {
      return;
    }
    setState(() {
      _filterMode = _TagsFilterMode.all;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagStatsProvider);
    final tagColors = ref.watch(tagColorLookupProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final enableWindowsDragToMove =
        Theme.of(context).platform == TargetPlatform.windows;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

        final visibleTags = _buildVisibleTags(tags);
        final pinnedCount = tags.where((tag) => tag.pinned).length;
        final memoCount = tags.fold<int>(0, (sum, tag) => sum + tag.count);

        return LayoutBuilder(
          builder: (context, constraints) {
            final pillMaxWidth = constraints.maxWidth < 280
                ? constraints.maxWidth
                : 240.0;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TagMetricChip(
                              icon: Icons.sell_outlined,
                              label: context.t.strings.legacy.msg_all_tags,
                              value: '${tags.length}',
                              accent: MemoFlowPalette.primary,
                            ),
                            _TagMetricChip(
                              icon: Icons.push_pin_outlined,
                              label: context.t.strings.legacy.msg_pinned,
                              value: '$pinnedCount',
                              accent: isDark
                                  ? const Color(0xFFFFC66D)
                                  : const Color(0xFFB87400),
                            ),
                            _TagMetricChip(
                              icon: Icons.notes_outlined,
                              label: context.t.strings.legacy.msg_memo_count,
                              value: '$memoCount',
                              accent: isDark
                                  ? const Color(0xFF7AC7FF)
                                  : const Color(0xFF1864AB),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TagsSearchBar(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          onClear: _searchController.text.isEmpty
                              ? null
                              : () {
                                  setState(() => _searchController.clear());
                                },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(
                                _filterLabel(context, _TagsFilterMode.all),
                              ),
                              selected: _filterMode == _TagsFilterMode.all,
                              onSelected: (_) {
                                setState(
                                  () => _filterMode = _TagsFilterMode.all,
                                );
                              },
                            ),
                            ChoiceChip(
                              label: Text(
                                _filterLabel(context, _TagsFilterMode.frequent),
                              ),
                              selected: _filterMode == _TagsFilterMode.frequent,
                              onSelected: (_) {
                                setState(
                                  () => _filterMode = _TagsFilterMode.frequent,
                                );
                              },
                            ),
                            ChoiceChip(
                              label: Text(
                                _filterLabel(context, _TagsFilterMode.recent),
                              ),
                              selected: _filterMode == _TagsFilterMode.recent,
                              onSelected: (_) {
                                setState(
                                  () => _filterMode = _TagsFilterMode.recent,
                                );
                              },
                            ),
                            ChoiceChip(
                              label: Text(
                                _filterLabel(context, _TagsFilterMode.pinned),
                              ),
                              selected: _filterMode == _TagsFilterMode.pinned,
                              onSelected: (_) {
                                setState(
                                  () => _filterMode = _TagsFilterMode.pinned,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (visibleTags.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
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
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh),
                              label: Text(context.t.strings.legacy.msg_clear_2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final tag in visibleTags)
                            _TagPill(
                              tag: tag,
                              colors: tagColors.resolveChipColorsByPath(
                                tag.path,
                                surfaceColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                isDark: isDark,
                              ),
                              maxWidth: pillMaxWidth,
                              onTap: () => _openTag(context, tag.path),
                              onEdit: tag.tagId == null
                                  ? null
                                  : () => _openTagEditor(context, tag),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
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
                    color: isDark
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

class _TagMetricChip extends StatelessWidget {
  const _TagMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
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

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.tag,
    required this.colors,
    required this.maxWidth,
    required this.onTap,
    this.onEdit,
  });

  final TagStat tag;
  final TagChipColors? colors;
  final double maxWidth;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final background =
        colors?.background ??
        (isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.92));
    final border = colors?.border ?? fallbackBorder;
    final titleColor = colors?.text ?? Theme.of(context).colorScheme.onSurface;
    final mutedColor =
        colors?.text.withValues(alpha: 0.72) ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final dotColor = colors?.border ?? MemoFlowPalette.primary;

    return Tooltip(
      message: tag.path,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      tag.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${tag.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                    ),
                  ),
                  if (tag.pinned) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.push_pin_outlined, size: 15, color: mutedColor),
                  ],
                  if (onEdit != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: context.t.strings.legacy.msg_edit_tag,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
