import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/shortcut.dart';
import '../../features/home/app_drawer.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/search_history_provider.dart';
import '../../state/session_provider.dart';
import '../../state/user_settings_provider.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/shortcut_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import 'memo_detail_screen.dart';
import 'memo_markdown.dart';
import 'note_input_sheet.dart';

const _maxPreviewLines = 6;
const _maxPreviewRunes = 220;

typedef _PreviewResult = ({String text, bool truncated});

_PreviewResult _truncatePreview(String text, {required bool collapseLongContent}) {
  if (!collapseLongContent) {
    return (text: text, truncated: false);
  }

  var result = text;
  var truncated = false;
  final lines = result.split('\n');
  if (lines.length > _maxPreviewLines) {
    result = lines.take(_maxPreviewLines).join('\n');
    truncated = true;
  }

  final compact = result.replaceAll(RegExp(r'\s+'), '');
  if (compact.runes.length > _maxPreviewRunes) {
    result = String.fromCharCodes(result.runes.take(_maxPreviewRunes));
    truncated = true;
  }

  if (truncated) {
    result = result.trimRight();
    result = result.endsWith('...') ? result : '$result...';
  }
  return (text: result, truncated: truncated);
}

class MemosListScreen extends ConsumerStatefulWidget {
  const MemosListScreen({
    super.key,
    required this.title,
    required this.state,
    this.tag,
    this.showDrawer = false,
    this.enableCompose = false,
    this.openDrawerOnStart = false,
  });

  final String title;
  final String state;
  final String? tag;
  final bool showDrawer;
  final bool enableCompose;
  final bool openDrawerOnStart;

  @override
  ConsumerState<MemosListScreen> createState() => _MemosListScreenState();
}

class _MemosListScreenState extends ConsumerState<MemosListScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _titleKey = GlobalKey();

  var _searching = false;
  var _openedDrawerOnStart = false;
  String? _selectedShortcutId;
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDrawerIfNeeded());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDrawerIfNeeded() {
    if (!mounted || _openedDrawerOnStart || !widget.openDrawerOnStart || !widget.showDrawer) {
      return;
    }
    _openedDrawerOnStart = true;
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _searching = false);
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(searchHistoryProvider.notifier).add(trimmed);
  }

  void _applySearchQuery(String query) {
    final trimmed = query.trim();
    _searchController.text = trimmed;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    setState(() {});
    _submitSearch(trimmed);
  }

  Shortcut? _findShortcutById(List<Shortcut> shortcuts) {
    final id = _selectedShortcutId;
    if (id == null || id.isEmpty) return null;
    for (final shortcut in shortcuts) {
      if (shortcut.shortcutId == id) return shortcut;
    }
    return null;
  }

  String _formatShortcutLoadError(BuildContext context, Object error) {
    if (error is UnsupportedError) {
      return context.tr(zh: '当前服务器不支持快捷筛选', en: 'Shortcuts are not supported on this server.');
    }
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return context.tr(zh: '当前服务器不支持快捷筛选', en: 'Shortcuts are not supported on this server.');
      }
    }
    return context.tr(zh: '快捷筛选加载失败', en: 'Failed to load shortcuts.');
  }

  bool get _isAllMemos {
    final tag = widget.tag;
    return widget.state == 'NORMAL' && (tag == null || tag.isEmpty);
  }

  void _backToAllMemos() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'memoflow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  Future<bool> _handleWillPop() async {
    if (_searching) {
      _closeSearch();
      return false;
    }
    if (!_isAllMemos) {
      if (widget.showDrawer) {
        _backToAllMemos();
        return false;
      }
      return true;
    }

    final now = DateTime.now();
    if (_lastBackPressedAt == null || now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(zh: '再按一次返回退出', en: 'Press back again to exit')),
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return true;
  }

  void _navigateDrawer(AppDrawerDestination dest) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    context.safePop();
      final route = switch (dest) {
        AppDrawerDestination.memos =>
          const MemosListScreen(title: 'memoflow', state: 'NORMAL', showDrawer: true, enableCompose: true),
        AppDrawerDestination.explore => const ExploreScreen(),
        AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived =>
        MemosListScreen(title: context.tr(zh: '回收站', en: 'Archive'), state: 'ARCHIVED', showDrawer: true),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
  }

  void _openNotifications() {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    context.safePop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  }

  void _openTagFromDrawer(String tag) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    context.safePop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MemosListScreen(
          title: '#$tag',
          state: 'NORMAL',
          tag: tag,
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  Future<void> _openNoteInput() async {
    if (!widget.enableCompose) return;
    await NoteInputSheet.show(context);
  }

  Future<void> _openAccountSwitcher() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    if (accounts.length < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.tr(zh: '切换账号', en: 'Switch account')),
              ),
            ),
            ...accounts.map(
              (a) => ListTile(
                leading: Icon(a.key == session?.currentKey ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(a.user.displayName.isNotEmpty ? a.user.displayName : a.user.name),
                subtitle: Text(a.baseUrl.toString()),
                onTap: () async {
                  context.safePop();
                  await ref.read(appSessionProvider.notifier).switchAccount(a.key);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _createShortcutFromMenu() async {
    final result = await Navigator.of(context).push<ShortcutEditorResult>(
      MaterialPageRoute<ShortcutEditorResult>(
        builder: (_) => const ShortcutEditorScreen(),
      ),
    );
    if (result == null) return;

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '未登录', en: 'Not authenticated'))),
      );
      return;
    }
    try {
      final created = await ref.read(memosApiProvider).createShortcut(
            userName: account.user.name,
            title: result.title,
            filter: result.filter,
          );
      ref.invalidate(shortcutsProvider);
      if (!mounted) return;
      setState(() => _selectedShortcutId = created.shortcutId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '创建失败：$e', en: 'Create failed: $e'))),
      );
    }
  }

  Future<void> _openTitleMenu() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final showShortcuts = _isAllMemos;
    if (!showShortcuts && accounts.length < 2) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || titleBox == null) return;

    final position = titleBox.localToGlobal(Offset.zero, ancestor: overlay);
    final maxWidth = overlay.size.width - 24;
    final width = (maxWidth < 220 ? maxWidth : 240).toDouble();
    final left = position.dx.clamp(12.0, overlay.size.width - width - 12.0);
    final top = position.dy + titleBox.size.height + 6;
    final availableHeight = overlay.size.height - top - 16;
    final menuMaxHeight = availableHeight > 120 ? availableHeight : overlay.size.height * 0.6;

    final action = await showGeneralDialog<_TitleMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'title_menu',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, __) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: _TitleMenuDropdown(
              selectedShortcutId: _selectedShortcutId,
              showShortcuts: showShortcuts,
              showAccountSwitcher: accounts.length > 1,
              maxHeight: menuMaxHeight,
              formatShortcutError: _formatShortcutLoadError,
            ),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action.type) {
      case _TitleMenuActionType.selectShortcut:
        setState(() => _selectedShortcutId = action.shortcutId);
        break;
      case _TitleMenuActionType.clearShortcut:
        setState(() => _selectedShortcutId = null);
        break;
      case _TitleMenuActionType.createShortcut:
        await _createShortcutFromMenu();
        break;
      case _TitleMenuActionType.openAccountSwitcher:
        await _openAccountSwitcher();
        break;
    }
  }

  Future<void> _updateMemo(LocalMemo memo, {bool? pinned, String? state}) async {
    final now = DateTime.now();
    final db = ref.read(databaseProvider);

    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned ?? memo.pinned,
      state: state ?? memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: memo.attachments.map((a) => a.toJson()).toList(growable: false),
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(type: 'update_memo', payload: {
      'uid': memo.uid,
      if (pinned != null) 'pinned': pinned,
      if (state != null) 'state': state,
    });
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  Future<void> _deleteMemo(LocalMemo memo) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr(zh: '删除 Memo？', en: 'Delete memo?')),
            content: Text(context.tr(
              zh: '本地会立即移除，联网后将同步删除服务器内容。',
              en: 'It will be removed locally now and deleted on the server when online.',
            )),
            actions: [
              TextButton(onPressed: () => context.safePop(false), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
              FilledButton(onPressed: () => context.safePop(true), child: Text(context.tr(zh: '删除', en: 'Delete'))),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final db = ref.read(databaseProvider);
    await db.deleteMemoByUid(memo.uid);
    await db.enqueueOutbox(type: 'delete_memo', payload: {'uid': memo.uid, 'force': false});
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider, (prev, next) {
      if (next.hasError && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '同步失败：${next.error}', en: 'Sync failed: ${next.error}'))),
        );
      }
    });

    final syncing = ref.watch(syncControllerProvider).isLoading;
    final searchQuery = _searchController.text;
    final shortcutsAsync = ref.watch(shortcutsProvider);
    final shortcuts = shortcutsAsync.valueOrNull ?? const <Shortcut>[];
    final selectedShortcut = _findShortcutById(shortcuts);
    final shortcutFilter = selectedShortcut?.filter ?? '';
    final useShortcutFilter = shortcutFilter.trim().isNotEmpty;
    final shortcutQuery = (
      searchQuery: searchQuery,
      state: widget.state,
      tag: widget.tag,
      shortcutFilter: shortcutFilter,
    );
    final memosAsync = useShortcutFilter
        ? ref.watch(shortcutMemosProvider(shortcutQuery))
        : ref.watch(
            memosStreamProvider(
              (
                searchQuery: searchQuery,
                state: widget.state,
                tag: widget.tag,
              ),
            ),
          );
    final searchHistory = ref.watch(searchHistoryProvider);
    final tagStats = ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final recommendedTags = [...tagStats]
      ..sort((a, b) => b.count.compareTo(a.count));
    final showSearchLanding = _searching && searchQuery.trim().isEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = (isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight).withValues(alpha: 0.9);
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (!mounted || !shouldPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      key: _scaffoldKey,
      drawer: widget.showDrawer
          ? AppDrawer(
              selected: widget.state == 'ARCHIVED' ? AppDrawerDestination.archived : AppDrawerDestination.memos,
              onSelect: _navigateDrawer,
              onSelectTag: _openTagFromDrawer,
              onOpenNotifications: _openNotifications,
            )
          : null,
      body: memosAsync.when(
        data: (memos) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncControllerProvider.notifier).syncNow();
            if (useShortcutFilter) {
              ref.invalidate(shortcutMemosProvider(shortcutQuery));
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: headerBg,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: !_searching,
                leading: _searching
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: _closeSearch,
                      )
                    : null,
                title: _searching
                    ? Container(
                        key: const ValueKey('search'),
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? MemoFlowPalette.borderDark.withValues(alpha: 0.7)
                                : MemoFlowPalette.borderLight,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: context.tr(zh: '搜索', en: 'Search'),
                            border: InputBorder.none,
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _submitSearch,
                        ),
                      )
                    : InkWell(
                        key: _titleKey,
                        onTap: () {
                          maybeHaptic();
                          _openTitleMenu();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Icon(Icons.expand_more, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                actions: _searching
                    ? [
                        TextButton(
                          onPressed: _closeSearch,
                          child: Text(
                            context.tr(zh: '取消', en: 'Cancel'),
                            style: TextStyle(
                              color: MemoFlowPalette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]
                    : [
                        IconButton(
                          tooltip: context.tr(zh: '搜索', en: 'Search'),
                          onPressed: _openSearch,
                          icon: const Icon(Icons.search),
                        ),
                      ],
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(color: headerBg),
                  ),
                ),
                bottom: _searching
                    ? null
                    : PreferredSize(
                        preferredSize: const Size.fromHeight(56),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _PillRow(
                            onWeeklyInsights: () {
                              maybeHaptic();
                              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
                            },
                            onAiSummary: () {
                              maybeHaptic();
                              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AiSummaryScreen()));
                            },
                            onDailyReview: () {
                              maybeHaptic();
                              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()));
                            },
                          ),
                        ),
                      ),
              ),
              if (showSearchLanding)
                SliverToBoxAdapter(
                  child: _SearchLanding(
                    history: searchHistory,
                    onClearHistory: () => ref.read(searchHistoryProvider.notifier).clear(),
                    onRemoveHistory: (value) => ref.read(searchHistoryProvider.notifier).remove(value),
                    onSelectHistory: _applySearchQuery,
                    tags: recommendedTags.take(6).map((e) => e.tag).toList(growable: false),
                    onSelectTag: _applySearchQuery,
                  ),
                )
              else if (memos.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 140),
                    child: Center(
                      child: Text(
                        _searching
                            ? context.tr(zh: '未找到相关内容', en: 'No results found')
                            : context.tr(zh: '暂无内容', en: 'No content yet'),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) {
                      final memo = memos[index];
                      return _MemoCard(
                        key: ValueKey(memo.uid),
                        memo: memo,
                        dateText: _dateFmt.format(memo.updateTime),
                        collapseLongContent: prefs.collapseLongContent,
                        collapseReferences: prefs.collapseReferences,
                        onTap: () {
                          maybeHaptic();
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemoDetailScreen(initialMemo: memo)));
                        },
                        onAction: (action) async {
                          switch (action) {
                            case _MemoCardAction.togglePinned:
                              await _updateMemo(memo, pinned: !memo.pinned);
                              return;
                            case _MemoCardAction.toggleArchived:
                              await _updateMemo(memo, state: memo.state == 'ARCHIVED' ? 'NORMAL' : 'ARCHIVED');
                              return;
                            case _MemoCardAction.delete:
                              await _deleteMemo(memo);
                              return;
                          }
                        },
                      );
                    },
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemCount: memos.length,
                  ),
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.enableCompose && !_searching
          ? _MemoFlowFab(
              onPressed: syncing ? null : _openNoteInput,
              hapticsEnabled: hapticsEnabled,
            )
          : null,
    ));
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.onWeeklyInsights,
    required this.onAiSummary,
    required this.onDailyReview,
  });

  final VoidCallback onWeeklyInsights;
  final VoidCallback onAiSummary;
  final VoidCallback onDailyReview;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final bgColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textColor = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PillButton(
            icon: Icons.insights,
            iconColor: MemoFlowPalette.primary,
            label: context.tr(zh: '每月统计', en: 'Monthly stats'),
            onPressed: onWeeklyInsights,
            backgroundColor: bgColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const SizedBox(width: 10),
          _PillButton(
            icon: Icons.auto_awesome,
            iconColor: isDark ? MemoFlowPalette.aiChipBlueDark : MemoFlowPalette.aiChipBlueLight,
            label: context.tr(zh: 'AI 总结', en: 'AI Summary'),
            onPressed: onAiSummary,
            backgroundColor: bgColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const SizedBox(width: 10),
          _PillButton(
            icon: Icons.explore,
            iconColor: isDark ? MemoFlowPalette.reviewChipOrangeDark : MemoFlowPalette.reviewChipOrangeLight,
            label: context.tr(zh: '随机漫步', en: 'Random Review'),
            onPressed: onDailyReview,
            backgroundColor: bgColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

enum _TitleMenuActionType {
  selectShortcut,
  clearShortcut,
  createShortcut,
  openAccountSwitcher,
}

class _TitleMenuAction {
  const _TitleMenuAction._(this.type, {this.shortcutId});

  const _TitleMenuAction.selectShortcut(String id)
      : this._(_TitleMenuActionType.selectShortcut, shortcutId: id);
  const _TitleMenuAction.clearShortcut() : this._(_TitleMenuActionType.clearShortcut);
  const _TitleMenuAction.createShortcut() : this._(_TitleMenuActionType.createShortcut);
  const _TitleMenuAction.openAccountSwitcher() : this._(_TitleMenuActionType.openAccountSwitcher);

  final _TitleMenuActionType type;
  final String? shortcutId;
}

class _TitleMenuDropdown extends ConsumerWidget {
  const _TitleMenuDropdown({
    required this.selectedShortcutId,
    required this.showShortcuts,
    required this.showAccountSwitcher,
    required this.maxHeight,
    required this.formatShortcutError,
  });

  final String? selectedShortcutId;
  final bool showShortcuts;
  final bool showAccountSwitcher;
  final double maxHeight;
  final String Function(BuildContext, Object) formatShortcutError;

  static const _shortcutIcons = [
    Icons.folder_outlined,
    Icons.lightbulb_outline,
    Icons.edit_note,
    Icons.bookmark_border,
    Icons.label_outline,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final dividerColor = border.withValues(alpha: 0.6);

    final shortcutsAsync = showShortcuts ? ref.watch(shortcutsProvider) : null;
    final items = <Widget>[];

    void addRow(Widget row) {
      if (items.isNotEmpty) {
        items.add(Divider(height: 1, color: dividerColor));
      }
      items.add(row);
    }

    if (showShortcuts && shortcutsAsync != null) {
      shortcutsAsync.when(
        data: (shortcuts) {
          final hasSelection = selectedShortcutId != null &&
              selectedShortcutId!.isNotEmpty &&
              shortcuts.any((shortcut) => shortcut.shortcutId == selectedShortcutId);
          addRow(
            _TitleMenuItem(
              icon: Icons.note_outlined,
              label: context.tr(zh: '全部笔记', en: 'All memos'),
              selected: !hasSelection,
              onTap: () => Navigator.of(context).pop(const _TitleMenuAction.clearShortcut()),
            ),
          );

          if (shortcuts.isEmpty) {
            addRow(
              _TitleMenuItem(
                icon: Icons.info_outline,
                label: context.tr(zh: '暂无快捷筛选', en: 'No shortcuts'),
                enabled: false,
                textColor: textMuted,
                iconColor: textMuted,
              ),
            );
          } else {
            for (var i = 0; i < shortcuts.length; i++) {
              final shortcut = shortcuts[i];
              final label = shortcut.title.trim().isNotEmpty
                  ? shortcut.title.trim()
                  : context.tr(zh: '未命名', en: 'Untitled');
              addRow(
                _TitleMenuItem(
                  icon: _shortcutIcons[i % _shortcutIcons.length],
                  label: label,
                  selected: shortcut.shortcutId == selectedShortcutId,
                  onTap: () => Navigator.of(context).pop(_TitleMenuAction.selectShortcut(shortcut.shortcutId)),
                ),
              );
            }
          }

          addRow(
            _TitleMenuItem(
              icon: Icons.add_circle_outline,
              label: context.tr(zh: '新建快捷筛选', en: 'New shortcut'),
              accent: true,
              onTap: () => Navigator.of(context).pop(const _TitleMenuAction.createShortcut()),
            ),
          );
        },
        loading: () {
          addRow(
            _TitleMenuItem(
              icon: Icons.note_outlined,
              label: context.tr(zh: '全部笔记', en: 'All memos'),
              selected: selectedShortcutId == null || selectedShortcutId!.isEmpty,
              onTap: () => Navigator.of(context).pop(const _TitleMenuAction.clearShortcut()),
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.hourglass_bottom,
              label: context.tr(zh: '加载中...', en: 'Loading...'),
              enabled: false,
              textColor: textMuted,
              iconColor: textMuted,
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.add_circle_outline,
              label: context.tr(zh: '新建快捷筛选', en: 'New shortcut'),
              accent: true,
              onTap: () => Navigator.of(context).pop(const _TitleMenuAction.createShortcut()),
            ),
          );
        },
        error: (error, _) {
          addRow(
            _TitleMenuItem(
              icon: Icons.note_outlined,
              label: context.tr(zh: '全部笔记', en: 'All memos'),
              selected: selectedShortcutId == null || selectedShortcutId!.isEmpty,
              onTap: () => Navigator.of(context).pop(const _TitleMenuAction.clearShortcut()),
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.info_outline,
              label: formatShortcutError(context, error),
              enabled: false,
              textColor: textMuted,
              iconColor: textMuted,
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.add_circle_outline,
              label: context.tr(zh: '新建快捷筛选', en: 'New shortcut'),
              accent: true,
              onTap: () => Navigator.of(context).pop(const _TitleMenuAction.createShortcut()),
            ),
          );
        },
      );
    }

    if (showAccountSwitcher) {
      addRow(
        _TitleMenuItem(
          icon: Icons.swap_horiz,
          label: context.tr(zh: '切换账号', en: 'Switch account'),
          onTap: () => Navigator.of(context).pop(const _TitleMenuAction.openAccountSwitcher()),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              child: Column(children: items),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleMenuItem extends StatelessWidget {
  const _TitleMenuItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.accent = false,
    this.enabled = true,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool accent;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final baseMuted = textMain.withValues(alpha: 0.6);
    final accentColor = MemoFlowPalette.primary;
    final labelColor = textColor ??
        (accent
            ? accentColor
            : selected
                ? textMain
                : baseMuted);
    final resolvedIconColor = iconColor ??
        (accent
            ? accentColor
            : selected
                ? accentColor
                : baseMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: resolvedIconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: labelColor),
                ),
              ),
              if (selected)
                Icon(Icons.check, size: 16, color: accentColor)
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLanding extends StatelessWidget {
  const _SearchLanding({
    required this.history,
    required this.onClearHistory,
    required this.onRemoveHistory,
    required this.onSelectHistory,
    required this.tags,
    required this.onSelectTag,
  });

  final List<String> history;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onRemoveHistory;
  final ValueChanged<String> onSelectHistory;
  final List<String> tags;
  final ValueChanged<String> onSelectTag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final chipBg = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final accent = MemoFlowPalette.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr(zh: '最近搜索', en: 'Recent searches'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (history.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearHistory,
                  icon: Icon(Icons.delete_outline, size: 18, color: textMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.tr(zh: '暂无搜索记录', en: 'No search history'),
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            )
          else
            Column(
              children: [
                for (final item in history)
                  InkWell(
                    onTap: () => onSelectHistory(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 18, color: textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(fontSize: 14, color: textMain),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onRemoveHistory(item),
                            icon: Icon(Icons.close, size: 18, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          Text(
            context.tr(zh: '推荐标签', en: 'Suggested tags'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 10),
          if (tags.isEmpty)
            Text(context.tr(zh: '暂无标签', en: 'No tags'), style: TextStyle(fontSize: 12, color: textMuted))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tag in tags)
                  InkWell(
                    onTap: () => onSelectTag('#${tag.trim()}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                  color: Colors.black.withValues(alpha: 0.06),
                                ),
                              ],
                      ),
                      child: Text(
                        '#${tag.trim()}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              context.tr(zh: '您可以搜索标题、内容或标签', en: 'Search by title, content, or tags'),
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
          ),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: iconColor),
        label: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

enum _MemoCardAction {
  togglePinned,
  toggleArchived,
  delete,
}

class _MemoCard extends StatefulWidget {
  const _MemoCard({
    super.key,
    required this.memo,
    required this.dateText,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.onTap,
    required this.onAction,
  });

  final LocalMemo memo;
  final String dateText;
  final bool collapseLongContent;
  final bool collapseReferences;
  final VoidCallback onTap;
  final ValueChanged<_MemoCardAction> onAction;

  @override
  State<_MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends State<_MemoCard> {
  var _expanded = false;

  static String _previewText(
    String content, {
    required bool collapseReferences,
    required AppLanguage language,
  }) {
    final trimmed = content.trim();
    if (!collapseReferences) return trimmed;

    final lines = trimmed.split('\n');
    final keep = <String>[];
    var quoteLines = 0;
    for (final line in lines) {
      if (line.trimLeft().startsWith('>')) {
        quoteLines++;
        continue;
      }
      keep.add(line);
    }

    final main = keep.join('\n').trim();
    if (quoteLines == 0) return main;
    if (main.isEmpty) {
      final cleaned = lines
          .map((l) => l.replaceFirst(RegExp(r'^\\s*>\\s?'), ''))
          .join('\n')
          .trim();
      return cleaned.isEmpty ? trimmed : cleaned;
    }
    return '$main\n\n${trByLanguage(language: language, zh: '引用 $quoteLines 行', en: 'Quoted $quoteLines lines')}';
  }

  @override
  void didUpdateWidget(covariant _MemoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memo.uid != widget.memo.uid) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    final dateText = widget.dateText;
    final collapseLongContent = widget.collapseLongContent;
    final collapseReferences = widget.collapseReferences;
    final onTap = widget.onTap;
    final onAction = widget.onAction;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final cardColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;

    final audio = memo.attachments.where((a) => a.type.startsWith('audio')).toList(growable: false);
    final hasAudio = audio.isNotEmpty;
    final language = context.appLanguage;
    final previewText = _previewText(memo.content, collapseReferences: collapseReferences, language: language);
    final preview = _truncatePreview(previewText, collapseLongContent: collapseLongContent);
    final showToggle = preview.truncated;
    final showCollapsed = showToggle && !_expanded;
    final displayText = showCollapsed ? preview.text : previewText;

    return Hero(
      tag: memo.uid,
      createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  blurRadius: isDark ? 20 : 12,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.03),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: textMain.withValues(alpha: isDark ? 0.4 : 0.5),
                        ),
                      ),
                    ),
                    PopupMenuButton<_MemoCardAction>(
                      tooltip: context.tr(zh: '更多', en: 'More'),
                      icon: Icon(Icons.more_horiz, size: 20, color: textMain.withValues(alpha: 0.4)),
                      onSelected: onAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _MemoCardAction.togglePinned,
                          child: Text(memo.pinned ? context.tr(zh: '取消置顶', en: 'Unpin') : context.tr(zh: '置顶', en: 'Pin')),
                        ),
                        PopupMenuItem(
                          value: _MemoCardAction.toggleArchived,
                          child: Text(
                            memo.state == 'ARCHIVED'
                                ? context.tr(zh: '取消归档', en: 'Unarchive')
                                : context.tr(zh: '归档', en: 'Archive'),
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: _MemoCardAction.delete,
                          child: Text(context.tr(zh: '删除', en: 'Delete')),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasAudio)
                  _AudioRow(
                    durationText: _parseVoiceDuration(memo.content) ?? '00:00',
                    isDark: isDark,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemoMarkdown(
                        data: displayText,
                        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textMain),
                        blockSpacing: 4,
                      ),
                      if (showToggle) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _expanded = !_expanded),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _expanded
                                  ? context.tr(zh: '收起', en: 'Collapse')
                                  : context.tr(zh: '展开', en: 'Expand'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MemoFlowPalette.primary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                _MemoRelationsSection(memoUid: memo.uid),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _parseVoiceDuration(String content) {
    final m = RegExp(r'[-?]\\s*时长[:：]\\s*(\\d{2}):(\\d{2}):(\\d{2})').firstMatch(content);
    if (m == null) return null;
    final hh = int.tryParse(m.group(1) ?? '') ?? 0;
    final mm = int.tryParse(m.group(2) ?? '') ?? 0;
    final ss = int.tryParse(m.group(3) ?? '') ?? 0;
    if (hh <= 0) return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }
}


class _MemoRelationsSection extends ConsumerWidget {
  const _MemoRelationsSection({required this.memoUid});

  final String memoUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationsAsync = ref.watch(memoRelationsProvider(memoUid));
    return relationsAsync.when(
      data: (relations) {
        if (relations.isEmpty) return const SizedBox.shrink();

        final currentName = 'memos/$memoUid';
        final referencing = <_RelationItem>[];
        final referencedBy = <_RelationItem>[];
        final seenReferencing = <String>{};
        final seenReferencedBy = <String>{};

        for (final relation in relations) {
          final type = relation.type.trim().toUpperCase();
          if (type != 'REFERENCE') {
            continue;
          }
          final memoName = relation.memo.name.trim();
          final relatedName = relation.relatedMemo.name.trim();

          if (memoName == currentName && relatedName.isNotEmpty) {
            if (seenReferencing.add(relatedName)) {
              referencing.add(
                _RelationItem(
                  name: relatedName,
                  snippet: relation.relatedMemo.snippet,
                ),
              );
            }
            continue;
          }
          if (relatedName == currentName && memoName.isNotEmpty) {
            if (seenReferencedBy.add(memoName)) {
              referencedBy.add(
                _RelationItem(
                  name: memoName,
                  snippet: relation.memo.snippet,
                ),
              );
            }
          }
        }

        if (referencing.isEmpty && referencedBy.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (referencing.isNotEmpty)
                _RelationGroup(
                  title: 'Referencing',
                  items: referencing,
                  isDark: isDark,
                ),
              if (referencing.isNotEmpty && referencedBy.isNotEmpty) const SizedBox(height: 8),
              if (referencedBy.isNotEmpty)
                _RelationGroup(
                  title: 'Referenced by',
                  items: referencedBy,
                  isDark: isDark,
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({
    required this.title,
    required this.items,
    required this.isDark,
  });

  final String title;
  final List<_RelationItem> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final bg = isDark ? MemoFlowPalette.audioSurfaceDark : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final headerColor = textMain.withValues(alpha: isDark ? 0.7 : 0.8);
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 14, color: headerColor),
              const SizedBox(width: 6),
              Text(
                '$title (${items.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: headerColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _shortMemoId(item.name),
                      style: TextStyle(fontSize: 10, color: headerColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _relationSnippet(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textMain),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _relationSnippet(_RelationItem item) {
    final snippet = item.snippet.trim();
    if (snippet.isNotEmpty) return snippet;
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    return '';
  }

  static String _shortMemoId(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '--';
    final raw = trimmed.startsWith('memos/') ? trimmed.substring('memos/'.length) : trimmed;
    return raw.length <= 6 ? raw : raw.substring(0, 6);
  }
}

class _RelationItem {
  const _RelationItem({
    required this.name,
    required this.snippet,
  });

  final String name;
  final String snippet;
}

class _AudioRow extends StatelessWidget {
  const _AudioRow({
    required this.durationText,
    required this.isDark,
  });

  final String durationText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight.withValues(alpha: 0.5);
    final bg = isDark ? MemoFlowPalette.audioSurfaceDark : MemoFlowPalette.audioSurfaceLight;
    final text = (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight).withValues(alpha: isDark ? 0.4 : 0.6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? Colors.transparent : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ],
            ),
            child: const Icon(Icons.play_arrow, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 4,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.2,
                    child: ColoredBox(color: MemoFlowPalette.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              Icon(Icons.refresh, size: 14, color: text.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(context.tr(zh: '无内容', en: 'No content'), style: TextStyle(fontSize: 11, color: text)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoFlowFab extends StatefulWidget {
  const _MemoFlowFab({required this.onPressed, required this.hapticsEnabled});

  final VoidCallback? onPressed;
  final bool hapticsEnabled;

  @override
  State<_MemoFlowFab> createState() => _MemoFlowFabState();
}

class _MemoFlowFabState extends State<_MemoFlowFab> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) {
              if (widget.hapticsEnabled) {
                HapticFeedback.selectionClick();
              }
              setState(() => _pressed = true);
            },
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: MemoFlowPalette.primary,
            shape: BoxShape.circle,
            border: Border.all(color: bg, width: 4),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 10),
                color: MemoFlowPalette.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.3),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}


