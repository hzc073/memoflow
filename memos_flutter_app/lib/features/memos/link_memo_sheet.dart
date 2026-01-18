import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/memo.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';

class LinkMemoSheet extends ConsumerStatefulWidget {
  const LinkMemoSheet({super.key, required this.existingNames});

  final Set<String> existingNames;

  static Future<Memo?> show(BuildContext context, {required Set<String> existingNames}) {
    return showModalBottomSheet<Memo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LinkMemoSheet(existingNames: existingNames),
    );
  }

  @override
  ConsumerState<LinkMemoSheet> createState() => _LinkMemoSheetState();
}

class _LinkMemoSheetState extends ConsumerState<LinkMemoSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Memo> _memos = const [];
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_scheduleSearch);
    _loadMemos('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_scheduleSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final query = _searchController.text;
    _debounce = Timer(const Duration(milliseconds: 300), () => _loadMemos(query));
  }

  Future<void> _loadMemos(String query) async {
    final api = ref.read(memosApiProvider);
    final prefs = ref.read(appPreferencesProvider);
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final userName = account?.user.name ?? '';
    final trimmed = query.trim();

    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? filter;
      String? oldFilter;
      String? parent;

      if (prefs.useLegacyApi) {
        if (userName.isNotEmpty) {
          parent = userName;
        }
        if (trimmed.isNotEmpty) {
          oldFilter = 'content_search == [${jsonEncode(trimmed)}]';
        }
      } else {
        final userId = _tryExtractUserId(userName);
        final conditions = <String>[];
        if (userId != null) {
          conditions.add('creator_id == $userId');
        }
        if (trimmed.isNotEmpty) {
          final escaped = _escapeFilterText(trimmed);
          conditions.add('content.contains("$escaped")');
        }
        if (conditions.isNotEmpty) {
          filter = conditions.join(' && ');
        }
      }

      final (memos, _) = await api.listMemos(
        pageSize: 200,
        filter: filter,
        oldFilter: oldFilter,
        parent: parent,
        preferModern: true,
      );

      if (!mounted || requestId != _requestId) return;
      final filtered = memos
          .where((memo) => memo.name.trim().isNotEmpty && !widget.existingNames.contains(memo.name.trim()))
          .toList(growable: false);
      setState(() => _memos = filtered);
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  static String? _tryExtractUserId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.startsWith('users/') ? trimmed.substring('users/'.length) : trimmed;
    final last = normalized.contains('/') ? normalized.split('/').last : normalized;
    return int.tryParse(last) != null ? last : null;
  }

  static String _escapeFilterText(String input) {
    return input.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  }

  String _snippetFor(Memo memo) {
    final raw = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    final name = memo.name.trim();
    if (name.isNotEmpty) return name;
    return memo.uid;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = isDark ? const Color(0xFF8E8E8E) : Colors.grey.shade600;
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final listHeight = math.min(MediaQuery.sizeOf(context).height * 0.5, 360.0).toDouble();

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(zh: '关联卡片', en: 'Link Card'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr(zh: '搜索笔记内容', en: 'Search memo content'),
                isDense: true,
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: MemoFlowPalette.primary.withValues(alpha: 0.6)),
                ),
                prefixIcon: Icon(Icons.search, color: textMuted),
              ),
              style: TextStyle(color: textMain, fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: listHeight,
              child: _buildList(context, textMain, textMuted, divider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Color textMain, Color textMuted, Color divider) {
    if (_loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          context.tr(zh: '加载失败', en: 'Failed to load'),
          style: TextStyle(color: textMuted),
        ),
      );
    }
    if (_memos.isEmpty) {
      return Center(
        child: Text(
          context.tr(zh: '暂无可关联的笔记', en: 'No memos available'),
          style: TextStyle(color: textMuted),
        ),
      );
    }

    final fmt = DateFormat('yyyy-MM-dd');
    return ListView.separated(
      itemCount: _memos.length,
      separatorBuilder: (_, index) => Divider(height: 1, color: divider),
      itemBuilder: (context, index) {
        final memo = _memos[index];
        final snippet = _snippetFor(memo);
        final dateLabel = memo.updateTime.millisecondsSinceEpoch > 0 ? fmt.format(memo.updateTime.toLocal()) : '';

        return InkWell(
          onTap: () => context.safePop(memo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateLabel.isNotEmpty)
                  Text(
                    dateLabel,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                const SizedBox(height: 4),
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: textMain, height: 1.3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
