import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/preferences_provider.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  DateTimeRange? _range;
  var _includeArchived = false;
  var _exporting = false;
  var _pressed = false;
  String? _lastExportPath;

  String _formatRange(DateTimeRange? range) {
    if (range == null) return '全部';
    final fmt = DateFormat('yyyy-MM-dd');
    return '${fmt.format(range.start)} ~ ${fmt.format(range.end)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  (int? startSec, int? endSecExclusive) _rangeToUtcSec(DateTimeRange? range) {
    if (range == null) return (null, null);
    final startLocal = DateTime(range.start.year, range.start.month, range.start.day);
    final endLocalExclusive = DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1));
    return (startLocal.toUtc().millisecondsSinceEpoch ~/ 1000, endLocalExclusive.toUtc().millisecondsSinceEpoch ~/ 1000);
  }

  String _memoFilename(LocalMemo memo) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(memo.createTime);
    final safeUid = memo.uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').padRight(8, '_').substring(0, 8);
    return '${ts}_$safeUid.md';
  }

  String _memoMarkdown(LocalMemo memo) {
    final tags = memo.tags.isEmpty ? '' : memo.tags.map((t) => '#$t').join(' ');
    final header = <String>[
      '---',
      'uid: ${memo.uid}',
      'created: ${memo.createTime.toIso8601String()}',
      'updated: ${memo.updateTime.toIso8601String()}',
      'visibility: ${memo.visibility}',
      'pinned: ${memo.pinned}',
      if (memo.state.isNotEmpty) 'state: ${memo.state}',
      if (tags.isNotEmpty) 'tags: $tags',
      '---',
      '',
    ].join('\n');
    return '$header${memo.content.trimRight()}\n';
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final (startSec, endSecExclusive) = _rangeToUtcSec(_range);
      final rows = await db.listMemosForExport(
        startTimeSec: startSec,
        endTimeSecExclusive: endSecExclusive,
        includeArchived: _includeArchived,
      );
      final memos = rows.map(LocalMemo.fromDb).where((m) => m.uid.isNotEmpty).toList(growable: false);

      final archive = Archive();
      final indexLines = <String>[
        '# MemoFlow 导出',
        '',
        '- 导出时间：${DateTime.now().toIso8601String()}',
        '- 时间范围：${_formatRange(_range)}',
        '- 包含回收站：${_includeArchived ? '是' : '否'}',
        '- 条数：${memos.length}',
        '',
      ];
      final indexBytes = utf8.encode(indexLines.join('\n'));
      archive.addFile(ArchiveFile('memos/index.md', indexBytes.length, indexBytes));

      for (final memo in memos) {
        final filename = _memoFilename(memo);
        final content = utf8.encode(_memoMarkdown(memo));
        archive.addFile(ArchiveFile('memos/$filename', content.length, content));
      }

      final zipData = ZipEncoder().encode(archive);

      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(dir.path, 'exports'));
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outPath = p.join(exportDir.path, 'memoflow_export_$now.zip');
      await File(outPath).writeAsBytes(zipData, flush: true);

      if (!mounted) return;
      setState(() => _lastExportPath = outPath);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(appPreferencesProvider.select((p) => p.hapticsEnabled));

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('导出/导入'),
        centerTitle: false,
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
              Text('导出', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted)),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    icon: Icons.date_range_outlined,
                    label: '时间范围',
                    value: _formatRange(_range),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      _pickRange();
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.delete_outline,
                    label: '包含回收站',
                    value: _includeArchived,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      haptic();
                      setState(() => _includeArchived = v);
                    },
                  ),
                  _SelectRow(
                    icon: Icons.description_outlined,
                    label: '导出格式',
                    value: 'Markdown + ZIP',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('格式固定为 Markdown + ZIP')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTapDown: _exporting ? null : (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: _exporting
                    ? null
                    : (_) {
                        setState(() => _pressed = false);
                        haptic();
                        _export();
                      },
                child: AnimatedScale(
                  scale: _pressed ? 0.98 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: MemoFlowPalette.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: _exporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('导出', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                ),
              ),
              if (_lastExportPath != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
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
                    children: [
                      Expanded(
                        child: Text(
                          _lastExportPath!,
                          style: TextStyle(fontSize: 12, height: 1.35, color: textMuted),
                        ),
                      ),
                      IconButton(
                        tooltip: '复制路径',
                        icon: Icon(Icons.copy, size: 18, color: textMuted),
                        onPressed: () async {
                          haptic();
                          await Clipboard.setData(ClipboardData(text: _lastExportPath!));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制路径')));
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text('导入（待实现）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted)),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    icon: Icons.file_upload_outlined,
                    label: '从文件导入',
                    value: '暂不支持',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入：待实现')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '说明：导出仅包含当前客户端已同步到本地数据库的内容（离线数据也会包含在内）。',
                style: TextStyle(fontSize: 12, height: 1.4, color: textMuted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain))),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveTrack = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);
    final inactiveThumb = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: MemoFlowPalette.primary,
            inactiveTrackColor: inactiveTrack,
            inactiveThumbColor: inactiveThumb,
          ),
        ],
      ),
    );
  }
}
