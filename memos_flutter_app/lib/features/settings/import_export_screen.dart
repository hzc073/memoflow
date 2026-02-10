import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../import/import_flow_screens.dart';
import '../../i18n/strings.g.dart';

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
    if (range == null) return trByLanguageKey(language: language, key: 'legacy.msg_all_2');
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

  String _sanitizePathSegment(String raw, {String fallback = 'attachment'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _attachmentArchiveName(Attachment attachment) {
    final rawName = attachment.filename.trim().isNotEmpty
        ? attachment.filename.trim()
        : (attachment.uid.isNotEmpty ? attachment.uid : attachment.name);
    final safeName = _sanitizePathSegment(rawName, fallback: 'attachment');
    final uid = attachment.uid.trim();
    if (uid.isEmpty) return safeName;
    if (safeName.startsWith('$uid.')) return safeName;
    if (safeName == uid) return safeName;
    return '${uid}_$safeName';
  }

  File? _localAttachmentFile(Attachment attachment) {
    final raw = attachment.externalLink.trim();
    if (!raw.startsWith('file://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final path = uri.toFilePath();
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String? _resolveAttachmentUrl(Uri? baseUrl, Attachment attachment) {
    final link = attachment.externalLink.trim();
    if (link.isNotEmpty && !link.startsWith('file://') && !link.startsWith('content://')) {
      return resolveMaybeRelativeUrl(baseUrl, link);
    }
    if (baseUrl == null) return null;
    final filename = attachment.filename.trim();
    if (filename.isEmpty) return null;
    return joinBaseUrl(baseUrl, 'file/${attachment.name}/$filename');
  }

  Future<List<int>?> _readAttachmentBytes(
    Attachment attachment, {
    required Uri? baseUrl,
    required String? authHeader,
    Dio? dio,
  }) async {
    final localFile = _localAttachmentFile(attachment);
    if (localFile != null) {
      return localFile.readAsBytes();
    }

    final url = _resolveAttachmentUrl(baseUrl, attachment);
    if (url == null || url.isEmpty) return null;

    final client = dio ?? Dio();
    final response = await client.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: authHeader == null ? null : {'Authorization': authHeader},
      ),
    );
    return response.data;
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    showTopToast(
      context,
      context.t.strings.legacy.msg_exporting,
      duration: const Duration(seconds: 30),
    );
    final language = ref.read(appPreferencesProvider).language;
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final authHeader =
        (account?.personalAccessToken ?? '').isEmpty ? null : 'Bearer ${account!.personalAccessToken}';
    try {
      final db = ref.read(databaseProvider);
      final (startSec, endSecExclusive) = _rangeToUtcSec(_range);
      final rows = await db.listMemosForExport(
        startTimeSec: startSec,
        endTimeSecExclusive: endSecExclusive,
        includeArchived: _includeArchived,
      );
      final memos = rows.map(LocalMemo.fromDb).where((m) => m.uid.isNotEmpty).toList(growable: false);
      final totalMemoCount = rows.length;
      final exportedMemoCount = memos.length;
      final skippedMemoCount = totalMemoCount - exportedMemoCount;

      final archive = Archive();
      final indexLines = <String>[
        trByLanguageKey(language: language, key: 'legacy.msg_memoflow_export'),
        '',
        '${trByLanguageKey(language: language, key: 'legacy.msg_export_time')}: ${DateTime.now().toIso8601String()}',
        '${trByLanguageKey(language: language, key: 'legacy.msg_date_range_4')}: ${_formatRange(_range, language)}',
        '${trByLanguageKey(language: language, key: 'legacy.msg_include_archived_2')}: ${_includeArchived ? trByLanguageKey(language: language, key: 'legacy.msg_yes') : trByLanguageKey(language: language, key: 'legacy.msg_no')}',
        '${trByLanguageKey(language: language, key: 'legacy.msg_count')}: $exportedMemoCount',
        '',
      ];
      final indexBytes = utf8.encode(indexLines.join('\n'));
      archive.addFile(ArchiveFile('index.md', indexBytes.length, indexBytes));

      for (final memo in memos) {
        final filename = _memoFilename(memo);
        final content = utf8.encode(_memoMarkdown(memo));
        archive.addFile(ArchiveFile('memos/$filename', content.length, content));
      }

      var exportedAttachmentCount = 0;
      var skippedAttachmentCount = 0;
      final usedAttachmentPaths = <String>{};
      final httpClient = Dio();
      for (final memo in memos) {
        if (memo.attachments.isEmpty) continue;
        final memoDir = _sanitizePathSegment(memo.uid, fallback: 'memo');
        for (final attachment in memo.attachments) {
          try {
            final bytes = await _readAttachmentBytes(
              attachment,
              baseUrl: baseUrl,
              authHeader: authHeader,
              dio: httpClient,
            );
            if (bytes == null) {
              skippedAttachmentCount++;
              continue;
            }
            final name = _attachmentArchiveName(attachment);
            var entryPath = 'attachments/$memoDir/$name';
            if (usedAttachmentPaths.contains(entryPath)) {
              final base = p.basenameWithoutExtension(name);
              final ext = p.extension(name);
              var index = 1;
              do {
                entryPath = 'attachments/$memoDir/$base ($index)$ext';
                index++;
              } while (usedAttachmentPaths.contains(entryPath));
            }
            usedAttachmentPaths.add(entryPath);
            archive.addFile(ArchiveFile(entryPath, bytes.length, bytes));
            exportedAttachmentCount++;
          } catch (_) {
            // Skip attachments that cannot be resolved or downloaded.
            skippedAttachmentCount++;
          }
        }
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
      messenger.hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(context.t.strings.legacy.msg_export_finished),
            content: Text(
              context.t.strings.legacy.msg_memos_skipped_attachments_skipped(exportedMemoCount: exportedMemoCount, skippedMemoCount: skippedMemoCount, exportedAttachmentCount: exportedAttachmentCount, skippedAttachmentCount: skippedAttachmentCount),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.t.strings.legacy.msg_ok),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_export_failed(e: e))),
      );
    } finally {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        setState(() => _exporting = false);
      }
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
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_import_export),
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
                context.t.strings.legacy.msg_export,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    icon: Icons.date_range_outlined,
                    label: context.t.strings.legacy.msg_date_range,
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
                    label: context.t.strings.legacy.msg_include_archived,
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
                    label: context.t.strings.legacy.msg_export_format,
                    value: 'Markdown + ZIP',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                        showTopToast(
                          context,
                          context.t.strings.legacy.msg_format_fixed_markdown_zip,
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
                              context.t.strings.legacy.msg_export,
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
                        tooltip: context.t.strings.legacy.msg_copy_path,
                        icon: Icon(Icons.copy, size: 18, color: textMuted),
                        onPressed: () async {
                          haptic();
                          await Clipboard.setData(ClipboardData(text: _lastExportPath!));
                          if (!context.mounted) return;
                          showTopToast(
                            context,
                            context.t.strings.legacy.msg_path_copied,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                context.t.strings.legacy.msg_import,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    icon: Icons.file_upload_outlined,
                    label: context.t.strings.legacy.msg_import_file_2,
                    value: context.t.strings.legacy.msg_html_zip,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ImportSourceScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.t.strings.legacy.msg_note_export_includes_content_already_synced,
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
