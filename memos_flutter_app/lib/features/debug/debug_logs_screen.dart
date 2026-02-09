import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/logs/debug_log_store.dart';
import '../../state/debug_log_provider.dart';

enum _DebugLogFilter { all, action, api }

class DebugLogsScreen extends ConsumerStatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  ConsumerState<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends ConsumerState<DebugLogsScreen> {
  final _searchController = TextEditingController();
  final _timeFormat = DateFormat('MM-dd HH:mm:ss');
  var _loading = false;
  var _filter = _DebugLogFilter.all;
  List<DebugLogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final store = ref.read(debugLogStoreProvider);
    final entries = await store.list(limit: 500);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr(zh: '清空记录', en: 'Clear logs')),
          content: Text(context.tr(zh: '确认清空调试记录？', en: 'Clear all debug logs?')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.tr(zh: '清空', en: 'Clear'))),
          ],
        );
      },
    );
    if (confirm != true) return;
    await ref.read(debugLogStoreProvider).clear();
    await _refresh();
  }

  Future<void> _copyAll() async {
    if (_entries.isEmpty) return;
    final text = _entries.map((e) => jsonEncode(e.toJson())).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showTopToast(
      context,
      context.tr(zh: '记录已复制', en: 'Logs copied'),
    );
  }

  List<DebugLogEntry> _filteredEntries() {
    Iterable<DebugLogEntry> items = _entries;
    switch (_filter) {
      case _DebugLogFilter.action:
        items = items.where((e) => e.category == 'action');
        break;
      case _DebugLogFilter.api:
        items = items.where((e) => e.category == 'api');
        break;
      case _DebugLogFilter.all:
        break;
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return items.toList(growable: false);
    return items.where((e) {
      bool match(String? value) => value != null && value.toLowerCase().contains(q);
      return match(e.label) ||
          match(e.detail) ||
          match(e.method) ||
          match(e.url) ||
          match(e.requestBody) ||
          match(e.responseBody) ||
          match(e.error);
    }).toList(growable: false);
  }

  void _showEntry(DebugLogEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
        final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
        final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(entry.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain)),
                  const SizedBox(height: 6),
                  Text(_timeFormat.format(entry.timestamp.toLocal()), style: TextStyle(fontSize: 12, color: textMuted)),
                  if (entry.detail != null && entry.detail!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(entry.detail!, style: TextStyle(fontSize: 13, color: textMain)),
                  ],
                  if (entry.method != null || entry.url != null || entry.status != null || entry.durationMs != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      [
                        if (entry.method != null) entry.method,
                        if (entry.url != null) entry.url,
                      ].whereType<String>().join(' '),
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (entry.status != null) 'HTTP ${entry.status}',
                        if (entry.durationMs != null) '${entry.durationMs}ms',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                  if (entry.requestHeaders != null) _DetailBlock(title: 'Request Headers', content: entry.requestHeaders!, textMain: textMain, textMuted: textMuted),
                  if (entry.requestBody != null) _DetailBlock(title: 'Request Body', content: entry.requestBody!, textMain: textMain, textMuted: textMuted),
                  if (entry.responseHeaders != null) _DetailBlock(title: 'Response Headers', content: entry.responseHeaders!, textMain: textMain, textMuted: textMuted),
                  if (entry.responseBody != null) _DetailBlock(title: 'Response Body', content: entry.responseBody!, textMain: textMain, textMuted: textMuted),
                  if (entry.error != null) _DetailBlock(title: 'Error', content: entry.error!, textMain: textMain, textMuted: textMuted),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    final entries = _filteredEntries();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '调试记录', en: 'Debug Logs')),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.tr(zh: '复制', en: 'Copy'),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            tooltip: context.tr(zh: '清空', en: 'Clear'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _entries.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.tr(zh: '搜索内容', en: 'Search logs'),
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: textMuted),
                    prefixIcon: Icon(Icons.search, color: textMuted),
                  ),
                  style: TextStyle(color: textMain),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    context.tr(zh: '筛选', en: 'Filter'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<_DebugLogFilter>(
                    value: _filter,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: _DebugLogFilter.all,
                        child: Text(context.tr(zh: '全部', en: 'All'), style: TextStyle(color: textMain)),
                      ),
                      DropdownMenuItem(
                        value: _DebugLogFilter.action,
                        child: Text(context.tr(zh: '本地', en: 'Local'), style: TextStyle(color: textMain)),
                      ),
                      DropdownMenuItem(
                        value: _DebugLogFilter.api,
                        child: Text(context.tr(zh: '接口', en: 'API'), style: TextStyle(color: textMain)),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _filter = value);
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr(zh: '刷新', en: 'Refresh'),
                    icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                    onPressed: _loading ? null : _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator(color: MemoFlowPalette.primary)),
                )
              else if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(child: Text(context.tr(zh: '暂无记录', en: 'No logs yet'), style: TextStyle(color: textMuted))),
                )
              else
                for (final entry in entries.reversed) ...[
                  _LogCard(
                    entry: entry,
                    timeLabel: _timeFormat.format(entry.timestamp.toLocal()),
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _showEntry(entry),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.entry,
    required this.timeLabel,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final DebugLogEntry entry;
  final String timeLabel;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  IconData _iconFor(DebugLogEntry entry) {
    switch (entry.category) {
      case 'action':
        return Icons.toggle_on_outlined;
      case 'api':
        return Icons.cloud_outlined;
    }
    return Icons.article_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = entry.status;
    final statusLabel = status == null ? '' : 'HTTP $status';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(entry), size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                    if (entry.detail != null && entry.detail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(entry.detail!, style: TextStyle(fontSize: 12, color: textMuted)),
                    ],
                    if (statusLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(statusLabel, style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                  ],
                ),
              ),
              Text(timeLabel, style: TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.content,
    required this.textMain,
    required this.textMuted,
  });

  final String title;
  final String content;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
          const SizedBox(height: 6),
          SelectableText(content, style: TextStyle(fontSize: 12, height: 1.4, color: textMain)),
        ],
      ),
    );
  }
}
