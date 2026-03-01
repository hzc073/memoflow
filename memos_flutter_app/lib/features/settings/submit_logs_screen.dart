import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/api/memo_api_version.dart';
import '../../application/sync/sync_coordinator.dart';
import '../../application/sync/sync_request.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../state/database_provider.dart';
import '../../state/logging_provider.dart';
import '../../state/local_library_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../../i18n/strings.g.dart';

class SubmitLogsScreen extends ConsumerStatefulWidget {
  const SubmitLogsScreen({super.key});

  @override
  ConsumerState<SubmitLogsScreen> createState() => _SubmitLogsScreenState();
}

class _SubmitLogsScreenState extends ConsumerState<SubmitLogsScreen> {
  final _noteController = TextEditingController();

  var _includeErrors = true;
  var _includeOutbox = true;
  var _busy = false;
  String? _lastPath;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<String> _buildReport() async {
    final generator = ref.read(logReportGeneratorProvider);
    return generator.buildReport(
      includeErrors: _includeErrors,
      includeOutbox: _includeOutbox,
      userNote: _noteController.text,
    );
  }

  Future<void> _copyReport() async {
    final text = await _buildReport();
    await Clipboard.setData(ClipboardData(text: text));
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final text = await _buildReport();
      final rootDir = await _resolveExportDirectory();
      final logDir = Directory(p.join(rootDir.path, 'logs'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outPath = p.join(logDir.path, 'MemoFlow_log_$now.txt');
      await File(outPath).writeAsString(text, flush: true);
      await _queueServerLogSubmission(reportText: text, reportPath: outPath);
      if (!mounted) return;
      setState(() => _lastPath = outPath);
      showTopToast(context, context.t.strings.legacy.msg_log_file_created);
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

  Future<void> _queueServerLogSubmission({
    required String reportText,
    required String reportPath,
  }) async {
    final report = reportText.trim();
    if (report.isEmpty) return;
    if (ref.read(currentLocalLibraryProvider) != null) return;

    final session = ref.read(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    if (account == null) return;

    final sessionController = ref.read(appSessionProvider.notifier);
    final versionRaw = sessionController
        .resolveEffectiveServerVersionForAccount(account: account);
    final version = parseMemoApiVersion(versionRaw);
    if (version == null) return;

    final now = DateTime.now().toUtc();
    final submissionId = now.microsecondsSinceEpoch.toString();
    final payload = <String, dynamic>{
      'title': 'MemoFlow Log Report (${version.versionString})',
      'submission_id': submissionId,
      'report': report,
      'report_path': reportPath,
      'api_version': version.versionString,
      'created_time': now.toIso8601String(),
      'include_errors': _includeErrors,
      'include_outbox': _includeOutbox,
    };

    await ref
        .read(databaseProvider)
        .enqueueOutbox(type: 'submit_log_report', payload: payload);

    ref
        .read(logManagerProvider)
        .info(
          'Queued log report submission',
          context: <String, Object?>{
            'apiVersion': version.versionString,
            'reportLength': report.length,
          },
        );

    unawaited(
      ref.read(syncCoordinatorProvider.notifier).requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          ),
    );
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
    final networkLoggingEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.networkLoggingEnabled),
    );
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
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
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
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
                          .read(appPreferencesProvider.notifier)
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
                    icon: Icons.content_copy,
                    label: context.t.strings.legacy.msg_copy_log_text,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      try {
                        await _copyReport();
                        if (!context.mounted) return;
                        showTopToast(
                          context,
                          context.t.strings.legacy.msg_log_copied,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.t.strings.legacy.msg_copy_failed(e: e),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _ActionRow(
                    icon: Icons.file_present_outlined,
                    label: _busy
                        ? context.t.strings.legacy.msg_generating
                        : context.t.strings.legacy.msg_generate_log_file,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: _busy
                        ? () {}
                        : () {
                            haptic();
                            unawaited(_exportReport());
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
              Icon(Icons.chevron_right, size: 20, color: textMuted),
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
