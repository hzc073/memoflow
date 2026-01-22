import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/log_sanitizer.dart';
import '../../core/memoflow_palette.dart';
import '../../state/database_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'submit_logs_screen.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

  Future<String> _buildDiagnostics(WidgetRef ref) async {
    final language = ref.read(appPreferencesProvider).language;
    final session = ref.read(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;

    final db = ref.read(databaseProvider);
    final sqlite = await db.db;

    Future<int> count(String sql) async {
      final rows = await sqlite.rawQuery(sql);
      final v = rows.firstOrNull?.values.first;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final memosCount = await count('SELECT COUNT(*) FROM memos;');
    final pendingCount = await count("SELECT COUNT(*) FROM memos WHERE sync_state IN (1,2);");
    final outboxCount = await count('SELECT COUNT(*) FROM outbox;');
    final outboxPending = await count("SELECT COUNT(*) FROM outbox WHERE state IN (0,2);");

    final accountLabel = account == null
        ? trByLanguage(language: language, zh: '未登录', en: 'Not signed in')
        : LogSanitizer.maskUserLabel(
            account.user.displayName.isNotEmpty ? account.user.displayName : account.user.name,
          );
    final hostRaw = account?.baseUrl.toString() ?? '';
    final host = hostRaw.isEmpty ? '' : LogSanitizer.maskUrl(hostRaw);

    return [
      trByLanguage(language: language, zh: 'MemoFlow 诊断信息', en: 'MemoFlow Diagnostics'),
      '${trByLanguage(language: language, zh: '时间', en: 'Time')}: ${DateTime.now().toIso8601String()}',
      '',
      '${trByLanguage(language: language, zh: '账号', en: 'Account')}: $accountLabel',
      '${trByLanguage(language: language, zh: '后端', en: 'Backend')}: $host',
      '',
      trByLanguage(language: language, zh: '本地数据：', en: 'Local data:'),
      '- memos: $memosCount',
      '- ${trByLanguage(language: language, zh: '待同步笔记', en: 'pending memos')}: $pendingCount',
      '- outbox: $outboxCount',
      '- ${trByLanguage(language: language, zh: '待处理队列', en: 'pending outbox')}: $outboxPending',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    Future<void> copyDiagnostics() async {
      try {
        final text = await _buildDiagnostics(ref);
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '诊断信息已复制', en: 'Diagnostics copied'))),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '生成失败：$e', en: 'Failed to generate: $e'))),
        );
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
        title: Text(context.tr(zh: '反馈', en: 'Feedback')),
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
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    icon: Icons.bug_report_outlined,
                    label: context.tr(zh: '提交日志', en: 'Submit Logs'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SubmitLogsScreen()),
                      );
                    },
                  ),
                  _ActionRow(
                    icon: Icons.help_outline,
                    label: context.tr(zh: '如何反馈？', en: 'How to report?'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (context) => SafeArea(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                            children: [
                              Text(
                                context.tr(zh: '如何反馈？', en: 'How to report?'),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.tr(
                                  zh: '如果您在使用 MemoFlow 时遇到问题（如同步失败、崩溃等），请按照以下步骤向我们反馈，这将帮助开发者快速定位并修复问题。\n\n'
                                      '获取日志：点击本页面的“提交日志”按钮，将日志文件（.zip 或 .txt）保存到您的手机存储中。(注：日志已自动去除敏感信息，请放心发送)\n\n'
                                      '前往反馈中心：点击下方链接访问我们的 GitHub Issues 页面：\n\n'
                                      '🔗 https://github.com/hzc073/MemoFlow/issues\n\n'
                                      '提交反馈：\n\n'
                                      '点击右上角的绿色 "New Issue" 按钮。\n\n'
                                      '简要描述您遇到的问题。\n\n'
                                      '重要： 将第 1 步保存的日志文件直接拖入输入框，或点击输入框下方的回形针图标上传。\n\n'
                                      '点击 "Submit new issue" 提交。\n\n'
                                      '非常感谢您帮助 MemoFlow 变得更好！❤️',
                                  en: 'If you run into issues in MemoFlow (e.g. sync failures, crashes), please follow the steps below to help us diagnose and fix the problem faster.\n\n'
                                      'Get logs: Tap the "Submit Logs" button on this page to save the log file (.zip or .txt) to your device storage. (Note: logs are already sanitized; it is safe to share.)\n\n'
                                      'Go to the feedback center: open our GitHub Issues page:\n\n'
                                      '🔗 https://github.com/hzc073/MemoFlow/issues\n\n'
                                      'Submit your report:\n\n'
                                      'Click the green "New Issue" button in the top-right corner.\n\n'
                                      'Briefly describe the problem you encountered.\n\n'
                                      'Important: Drag the log file saved in step 1 into the input area, or click the paperclip icon below the input box to upload it.\n\n'
                                      'Click "Submit new issue".\n\n'
                                      'Thank you for helping MemoFlow get better! ❤️',
                                ),
                                style: const TextStyle(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  zh: '提示：Token 可能只返回一次，之后无法再次获取，请妥善保存。',
                  en: 'Note: Some tokens are returned only once and cannot be retrieved later. Please keep them safe.',
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

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
