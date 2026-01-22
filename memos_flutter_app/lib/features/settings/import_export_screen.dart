import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_localization.dart';
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

  String _formatRange(DateTimeRange? range, AppLanguage language) {
    if (range == null) return trByLanguage(language: language, zh: '全部', en: 'All');
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

  Future<Directory?> _tryGetDownloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      final candidates = <Directory>[
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
      ];
      for (final dir in candidates) {
        if (await dir.exists()) return dir;
      }

      final external = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (external != null && external.isNotEmpty) return external.first;

      final fallback = await getExternalStorageDirectory();
      if (fallback != null) return fallback;
    }

    final downloads = await _tryGetDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final language = ref.read(appPreferencesProvider).language;
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
        trByLanguage(language: language, zh: '# MemoFlow 导出', en: '# MemoFlow Export'),
        '',
        '${trByLanguage(language: language, zh: '- 导出时间', en: '- Export time')}: ${DateTime.now().toIso8601String()}',
        '${trByLanguage(language: language, zh: '- 时间范围', en: '- Date range')}: ${_formatRange(_range, language)}',
        '${trByLanguage(language: language, zh: '- 包含归档', en: '- Include archived')}: ${_includeArchived ? trByLanguage(language: language, zh: '是', en: 'Yes') : trByLanguage(language: language, zh: '否', en: 'No')}',
        '${trByLanguage(language: language, zh: '- 数量', en: '- Count')}: ${memos.length}',
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

      final rootDir = await _resolveExportDirectory();
      final exportDir = Directory(p.join(rootDir.path, 'exports'));
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outPath = p.join(exportDir.path, 'MemoFlow_export_$now.zip');
      await File(outPath).writeAsBytes(zipData, flush: true);

      if (!mounted) return;
      setState(() => _lastExportPath = outPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '导出完成', en: 'Export finished'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '导出失败：$e', en: 'Export failed: $e'))),
      );
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
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '导入 / 导出', en: 'Import / Export')),
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
              Text(
                context.tr(zh: '导出', en: 'Export'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    icon: Icons.date_range_outlined,
                    label: context.tr(zh: '时间范围', en: 'Date Range'),
                    value: _formatRange(_range, ref.read(appPreferencesProvider).language),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      _pickRange();
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.delete_outline,
                    label: context.tr(zh: '包含归档', en: 'Include Archived'),
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
                    label: context.tr(zh: '导出格式', en: 'Export Format'),
                    value: 'Markdown + ZIP',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr(zh: '格式固定为 Markdown + ZIP', en: 'Format is fixed to Markdown + ZIP'))),
                      );
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
                          : Text(
                              context.tr(zh: '导出', en: 'Export'),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                            ),
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
                        tooltip: context.tr(zh: '复制路径', en: 'Copy path'),
                        icon: Icon(Icons.copy, size: 18, color: textMuted),
                        onPressed: () async {
                          haptic();
                          await Clipboard.setData(ClipboardData(text: _lastExportPath!));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr(zh: '路径已复制', en: 'Path copied'))),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                context.tr(zh: '导入（即将上线）', en: 'Import (coming soon)'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    icon: Icons.file_upload_outlined,
                    label: context.tr(zh: '从文件导入', en: 'Import from file'),
                    value: context.tr(zh: '暂不支持', en: 'Not supported'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr(zh: '导入功能即将上线', en: 'Import: coming soon'))),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  zh: '提示：导出包含已同步到本地数据库的内容（含离线数据）。',
                  en: 'Note: Export includes content already synced to the local database (offline data included).',
                ),
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
