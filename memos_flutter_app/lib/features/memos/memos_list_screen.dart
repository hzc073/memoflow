import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/local_memo.dart';
import '../../features/home/app_drawer.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../about/about_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import 'memo_detail_screen.dart';
import 'memo_markdown.dart';
import 'note_input_sheet.dart';

const _maxPreviewLines = 6;
const _maxPreviewRunes = 220;

String _truncatePreview(String text, {required bool collapseLongContent}) {
  if (!collapseLongContent) return text;

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
  return result;
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

  var _searching = false;
  var _openedDrawerOnStart = false;
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

  bool get _isAllMemos {
    final tag = widget.tag;
    return widget.state == 'NORMAL' && (tag == null || tag.isEmpty);
  }

  void _backToAllMemos() {
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

  Future<bool> _handleWillPop() async {
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
        const SnackBar(
          content: Text('再按一次返回退出'),
          duration: Duration(seconds: 2),
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
    Navigator.of(context).pop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'MemoFlow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => const MemosListScreen(title: '回收站', state: 'ARCHIVED', showDrawer: true),
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
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  }

  void _openTagFromDrawer(String tag) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    Navigator.of(context).pop();
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('切换账号')),
            ),
            ...accounts.map(
              (a) => ListTile(
                leading: Icon(a.key == session?.currentKey ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(a.user.displayName.isNotEmpty ? a.user.displayName : a.user.name),
                subtitle: Text(a.baseUrl.toString()),
                onTap: () async {
                  Navigator.of(context).pop();
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
            title: const Text('删除 Memo？'),
            content: const Text('本地会立即移除，联网后将同步删除服务器内容。'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败：${next.error}')));
      }
    });

    final syncing = ref.watch(syncControllerProvider).isLoading;
    final searchQuery = _searchController.text;
    final memosAsync = ref.watch(
      memosStreamProvider(
        (
          searchQuery: searchQuery,
          state: widget.state,
          tag: widget.tag,
        ),
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = (isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight).withValues(alpha: 0.9);
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    return WillPopScope(
      onWillPop: _handleWillPop,
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
          onRefresh: () => ref.read(syncControllerProvider.notifier).syncNow(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: headerBg,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _searching
                      ? TextField(
                          key: const ValueKey('search'),
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: '搜索',
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        )
                      : InkWell(
                          key: const ValueKey('title'),
                          onTap: () {
                            maybeHaptic();
                            _openAccountSwitcher();
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
                ),
                actions: [
                  IconButton(
                    tooltip: _searching ? '关闭搜索' : '搜索',
                    onPressed: () {
                      setState(() => _searching = !_searching);
                      if (!_searching) {
                        _searchController.clear();
                        setState(() {});
                      }
                    },
                    icon: Icon(_searching ? Icons.close : Icons.search),
                  ),
                ],
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(color: headerBg),
                  ),
                ),
                bottom: PreferredSize(
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
              if (memos.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 140),
                    child: Center(child: Text('暂无内容')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) {
                      final memo = memos[index];
                      return _MemoCard(
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
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.enableCompose
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
            label: '每月统计',
            onPressed: onWeeklyInsights,
            backgroundColor: bgColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const SizedBox(width: 10),
          _PillButton(
            icon: Icons.auto_awesome,
            iconColor: isDark ? MemoFlowPalette.aiChipBlueDark : MemoFlowPalette.aiChipBlueLight,
            label: 'AI 总结',
            onPressed: onAiSummary,
            backgroundColor: bgColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const SizedBox(width: 10),
          _PillButton(
            icon: Icons.explore,
            iconColor: isDark ? MemoFlowPalette.reviewChipOrangeDark : MemoFlowPalette.reviewChipOrangeLight,
            label: '随机漫步',
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

class _MemoCard extends StatelessWidget {
  const _MemoCard({
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

  static String _previewText(String content, {required bool collapseReferences}) {
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
    return '$main\n\n引用 $quoteLines 行';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final cardColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;

    final audio = memo.attachments.where((a) => a.type.startsWith('audio')).toList(growable: false);
    final hasAudio = audio.isNotEmpty;
    final preview = _truncatePreview(
      _previewText(memo.content, collapseReferences: collapseReferences),
      collapseLongContent: collapseLongContent,
    );

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
                      tooltip: '更多',
                      icon: Icon(Icons.more_horiz, size: 20, color: textMain.withValues(alpha: 0.4)),
                      onSelected: onAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _MemoCardAction.togglePinned,
                          child: Text(memo.pinned ? '取消置顶' : '置顶'),
                        ),
                        PopupMenuItem(
                          value: _MemoCardAction.toggleArchived,
                          child: Text(memo.state == 'ARCHIVED' ? '取消归档' : '归档'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: _MemoCardAction.delete,
                          child: Text('删除'),
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
                  MemoMarkdown(
                    data: preview,
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textMain),
                    blockSpacing: 4,
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
    final m = RegExp(r'[-•]\\s*时长[:：]\\s*(\\d{2}):(\\d{2}):(\\d{2})').firstMatch(content);
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
              Text('无内容', style: TextStyle(fontSize: 11, color: text)),
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


