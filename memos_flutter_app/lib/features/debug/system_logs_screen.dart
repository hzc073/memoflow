import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../state/logging_provider.dart';
import '../../state/preferences_provider.dart';
import '../../i18n/strings.g.dart';

class SystemLogsScreen extends ConsumerStatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  ConsumerState<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends ConsumerState<SystemLogsScreen> {
  static const int _maxLines = 500;

  var _loading = false;
  var _exporting = false;
  List<String> _lines = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final lines = await ref
        .read(logManagerProvider)
        .readRecentLines(maxLines: _maxLines);
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _copyLines() async {
    if (_lines.isEmpty) return;
    final text = _lines.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showTopToast(context, 'System logs copied (${_lines.length} lines)');
  }

  String _generateExportId() {
    return DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now().toUtc());
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

      final external = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (external != null && external.isNotEmpty) return external.first;

      final fallback = await getExternalStorageDirectory();
      if (fallback != null) return fallback;
    }

    final downloads = await _tryGetDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  Future<void> _exportBundle() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final exportId = _generateExportId();
      final reportText = await ref
          .read(logReportGeneratorProvider)
          .buildReport(exportId: exportId);
      final rootDir = await _resolveExportDirectory();
      final logDir = Directory(p.join(rootDir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final networkEnabled = ref
          .read(appPreferencesProvider)
          .networkLoggingEnabled;

      final bundleFile = await ref
          .read(logBundleExporterProvider)
          .exportBundle(
            exportId: exportId,
            reportText: reportText,
            outputDirectory: logDir,
            includeNetworkStore: networkEnabled,
          );

      if (!mounted) return;
      showTopToast(
        context,
        'Log bundle created: ${bundleFile.path} (ExportId: $exportId)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export logs: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

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
        title: const Text('System Logs'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Copy last $_maxLines lines',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _lines.isEmpty ? null : _copyLines,
          ),
          IconButton(
            tooltip: 'Export logs bundle',
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.archive_outlined),
            onPressed: _exporting ? null : _exportBundle,
          ),
          IconButton(
            tooltip: context.t.strings.legacy.msg_refresh,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
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
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                'Showing last $_maxLines lines',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 10),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: MemoFlowPalette.primary,
                    ),
                  ),
                )
              else if (_lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text(
                      'No system logs yet',
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    _lines.join('\n'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: textMain,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
