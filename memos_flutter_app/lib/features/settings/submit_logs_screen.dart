import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../state/logging_provider.dart';
import '../../state/preferences_provider.dart';

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
    return generator.buildReport();
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

      final external = await getExternalStorageDirectories(type: StorageDirectory.downloads);
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
      if (!mounted) return;
      setState(() => _lastPath = outPath);
      showTopToast(
        context,
        context.tr(zh: '日志文件已生成', en: 'Log file created'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '生成失败：$e', en: 'Failed to generate: $e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final networkLoggingEnabled = ref.watch(appPreferencesProvider.select((p) => p.networkLoggingEnabled));
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
        title: Text(context.tr(zh: '提交日志', en: 'Submit Logs')),
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
                context.tr(zh: '包含', en: 'Include'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ToggleRow(
                    icon: Icons.report_gmailerrorred_outlined,
                    label: context.tr(zh: '包含错误详情', en: 'Include error details'),
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
                    label: context.tr(zh: '包含待处理队列', en: 'Include pending queue'),
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
                    label: context.tr(zh: '记录请求/响应日志', en: 'Record request/response logs'),
                    value: networkLoggingEnabled,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      haptic();
                      ref.read(appPreferencesProvider.notifier).setNetworkLoggingEnabled(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '补充说明（可选）', en: 'Additional notes (optional)'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: context.tr(zh: '描述问题、时间、复现步骤等', en: 'Describe the issue, time, repro steps, etc.'),
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: textMuted),
                  ),
                  style: TextStyle(color: textMain),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '操作', en: 'Actions'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textMuted),
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    icon: Icons.content_copy,
                    label: context.tr(zh: '复制日志文本', en: 'Copy log text'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      try {
                        await _copyReport();
                        if (!context.mounted) return;
                        showTopToast(
                          context,
                          context.tr(zh: '日志已复制', en: 'Log copied'),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr(zh: '复制失败：$e', en: 'Copy failed: $e'))),
                        );
                      }
                    },
                  ),
                  _ActionRow(
                    icon: Icons.file_present_outlined,
                    label: _busy
                        ? context.tr(zh: '生成中…', en: 'Generating?')
                        : context.tr(zh: '生成日志文件', en: 'Generate log file'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(zh: '日志文件', en: 'Log file'),
                        style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                      ),
                      const SizedBox(height: 6),
                      Text(_lastPath!, style: TextStyle(fontSize: 12, color: textMuted)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            haptic();
                            await Clipboard.setData(ClipboardData(text: _lastPath!));
                            if (!context.mounted) return;
                            showTopToast(
                              context,
                              context.tr(zh: '路径已复制', en: 'Path copied'),
                            );
                          },
                          child: Text(context.tr(zh: '复制路径', en: 'Copy path')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                context.tr(
                  zh: '提示：日志已自动去除敏感信息，如仍包含敏感数据，请提交前自行处理。',
                  en: 'Note: logs are sanitized automatically. If sensitive data remains, redact before submitting.',
                ),
                style: TextStyle(fontSize: 12, height: 1.4, color: textMuted.withValues(alpha: 0.75)),
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
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain))),
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
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

