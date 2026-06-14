import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/top_toast.dart';
import '../../state/system/debug_log_provider.dart';
import '../../state/system/logging_provider.dart';
import '../../state/system/network_log_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/webdav/webdav_log_provider.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

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
      showTopToast(context, context.t.strings.legacy.msg_failed_generate(e: e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAllLogs() async {
    if (_busy || _clearing) return;
    final confirm = await showSettingsConfirmationDialog(
      context: context,
      title: context.t.strings.legacy.msg_clear_logs,
      message: context.t.strings.legacy.msg_clear_all_logs,
      confirmLabel: context.t.strings.legacy.msg_clear,
      cancelLabel: context.t.strings.legacy.msg_cancel_2,
      destructive: true,
    );
    if (!confirm) return;
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

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_submit_logs),
      children: [
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_include),
          children: [
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_include_error_details,
              value: _includeErrors,
              onChanged: (v) {
                haptic();
                setState(() => _includeErrors = v);
              },
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_include_pending_queue,
              value: _includeOutbox,
              onChanged: (v) {
                haptic();
                setState(() => _includeOutbox = v);
              },
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_record_request_response_logs,
              value: networkLoggingEnabled,
              onChanged: (v) {
                haptic();
                ref
                    .read(devicePreferencesProvider.notifier)
                    .setNetworkLoggingEnabled(v);
              },
            ),
          ],
        ),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_additional_notes_optional),
          children: [_NotesRow(controller: _noteController)],
        ),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_actions),
          children: [
            _ActionRow(
              icon: Icons.file_present_outlined,
              label: _busy
                  ? context.t.strings.legacy.msg_generating
                  : context.t.strings.legacy.msg_generate_log_file,
              enabled: !actionsLocked,
              onTap: () {
                haptic();
                unawaited(_exportReport());
              },
            ),
            _ActionRow(
              icon: Icons.delete_outline,
              label: context.t.strings.legacy.msg_clear_logs,
              enabled: !actionsLocked,
              onTap: () {
                haptic();
                unawaited(_clearAllLogs());
              },
            ),
          ],
        ),
        if (_lastPath != null)
          SettingsSection(
            header: Text(context.t.strings.legacy.msg_log_file),
            children: [
              SettingsCustomRow(
                title: SettingsRowDescription(_lastPath!),
                trailing: IconButton(
                  tooltip: context.t.strings.legacy.msg_copy_path,
                  onPressed: () async {
                    haptic();
                    await Clipboard.setData(ClipboardData(text: _lastPath!));
                    if (!context.mounted) return;
                    showTopToast(
                      context,
                      context.t.strings.legacy.msg_path_copied,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ),
            ],
          ),
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: context.t.strings.legacy.msg_logs_export_local_only,
            ),
            if (!networkLoggingEnabled)
              SettingsInfoRow(
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_enable_network_logging_before_exporting,
              ),
            SettingsInfoRow(
              description: context
                  .t
                  .strings
                  .legacy
                  .msg_note_logs_sanitized_automatically_sensitive_data,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return SettingsCustomRow(
      leading: Icon(icon, size: 20, color: tokens.textMuted),
      title: SettingsRowTitle(label),
      trailing: Icon(Icons.chevron_right, size: 20, color: tokens.textMuted),
      onTap: onTap,
      enabled: enabled,
    );
  }
}

class _NotesRow extends StatelessWidget {
  const _NotesRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsMultilineFieldRow(
      label: context.t.strings.collections.description,
      controller: controller,
      minLines: 3,
      maxLines: 5,
      hint: context.t.strings.legacy.msg_describe_issue_time_repro_steps_etc,
    );
  }
}
