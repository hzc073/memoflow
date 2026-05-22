import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../state/system/debug_log_provider.dart';
import '../../state/system/logging_provider.dart';
import '../../state/system/network_log_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/webdav/webdav_log_provider.dart';
import '../../i18n/strings.g.dart';

class ExportLogsScreen extends ConsumerStatefulWidget {
  const ExportLogsScreen({super.key});

  @override
  ConsumerState<ExportLogsScreen> createState() => _ExportLogsScreenState();
}

class _ExportLogsScreenState extends ConsumerState<ExportLogsScreen> {
  final _noteController = TextEditingController();

  var _includeErrors = true;
  var _includeOutbox = true;
  var _busy = false;
  var _clearing = false;
  String? _lastPath;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<String> _buildReport({String? exportId}) async {
    final generator = ref.read(logReportGeneratorProvider);
    return generator.buildReport(
      includeErrors: _includeErrors,
      includeOutbox: _includeOutbox,
      userNote: _noteController.text,
      exportId: exportId,
    );
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

  Future<void> _exportReport() async {
    if (_busy || _clearing) return;
    setState(() => _busy = true);
    try {
      final exportId = _generateExportId();
      final text = await _buildReport(exportId: exportId);
      final rootDir = await _resolveExportDirectory();
      final logDir = Directory(p.join(rootDir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final reportPath = p.join(logDir.path, 'MemoFlow_log_$now.txt');
      await File(reportPath).writeAsString(text, flush: true);
      final networkEnabled = ref
          .read(devicePreferencesProvider)
          .networkLoggingEnabled;
      final bundleFile = await ref
          .read(logBundleExporterProvider)
          .exportBundle(
            exportId: exportId,
            reportText: text,
            outputDirectory: logDir,
            includeNetworkStore: networkEnabled,
          );
      if (!mounted) return;
      setState(() {
        _lastPath = bundleFile.path;
      });
      showTopToast(
        context,
        '${context.t.strings.legacy.msg_log_file_created}: ${bundleFile.path} (ExportId: $exportId)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_generate(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAllLogs() async {
    if (_busy || _clearing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t.strings.legacy.msg_clear_logs),
          content: Text(context.t.strings.legacy.msg_clear_all_logs),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t.strings.legacy.msg_cancel_2),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.t.strings.legacy.msg_clear),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    setState(() => _clearing = true);
    try {
      final logManager = ref.read(logManagerProvider);
      await Future.wait([
        ref.read(debugLogStoreProvider).clear(),
        ref.read(webDavLogStoreProvider).clear(),
        ref.read(networkLogStoreProvider).clear(),
        logManager.clearAll(),
      ]);
      ref.read(breadcrumbStoreProvider).clear();
      ref.read(networkLogBufferProvider).clear();
      ref.read(syncStatusTrackerProvider).reset();
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_logs_cleared);
    } finally {
      if (mounted) setState(() => _clearing = false);
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
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final actionsLocked = _busy || _clearing;
    final networkLoggingEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.networkLoggingEnabled),
    );
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );

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
        automaticallyImplyLeading: resolveDesktopRouteAutomaticallyImplyLeading(
          context: context,
          automaticallyImplyLeading: true,
        ),
        leading: resolveDesktopRouteDismissalLeading(
          context: context,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(context.t.strings.legacy.msg_submit_logs),
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
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                context.t.strings.legacy.msg_include,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ToggleRow(
                    icon: Icons.report_gmailerrorred_outlined,
                    label: context.t.strings.legacy.msg_include_error_details,
                    value: _includeErrors,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      haptic();
                      setState(() => _includeErrors = v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.outbox_outlined,
                    label: context.t.strings.legacy.msg_include_pending_queue,
                    value: _includeOutbox,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      haptic();
                      setState(() => _includeOutbox = v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.swap_horiz,
                    label: context
                        .t
                        .strings
                        .legacy
                        .msg_record_request_response_logs,
                    value: networkLoggingEnabled,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      haptic();
                      ref
                          .read(devicePreferencesProvider.notifier)
                          .setNetworkLoggingEnabled(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.t.strings.legacy.msg_additional_notes_optional,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: context
                        .t
                        .strings
                        .legacy
                        .msg_describe_issue_time_repro_steps_etc,
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: textMuted),
                  ),
                  style: TextStyle(color: textMain),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t.strings.legacy.msg_actions,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    icon: Icons.file_present_outlined,
                    label: _busy
                        ? context.t.strings.legacy.msg_generating
                        : context.t.strings.legacy.msg_generate_log_file,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: actionsLocked
                        ? () {}
                        : () {
                            haptic();
                            unawaited(_exportReport());
                          },
                  ),
                  _ActionRow(
                    icon: Icons.delete_outline,
                    label: context.t.strings.legacy.msg_clear_logs,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: actionsLocked
                        ? () {}
                        : () {
                            haptic();
                            unawaited(_clearAllLogs());
                          },
                  ),
                ],
              ),
              if (_lastPath != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t.strings.legacy.msg_log_file,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lastPath!,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            haptic();
                            await Clipboard.setData(
                              ClipboardData(text: _lastPath!),
                            );
                            if (!context.mounted) return;
                            showTopToast(
                              context,
                              context.t.strings.legacy.msg_path_copied,
                            );
                          },
                          child: Text(context.t.strings.legacy.msg_copy_path),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                context.t.strings.legacy.msg_logs_export_local_only,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: textMuted.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              if (!networkLoggingEnabled) ...[
                Text(
                  context
                      .t
                      .strings
                      .legacy
                      .msg_enable_network_logging_before_exporting,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: textMuted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_note_logs_sanitized_automatically_sensitive_data,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: textMuted.withValues(alpha: 0.75),
                ),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
