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
                    icon: Icons.content_copy,
                    label: context.tr(zh: '复制诊断信息', en: 'Copy diagnostics'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      unawaited(copyDiagnostics());
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
                                  zh: '请提供以下信息：\n'
                                      '1) 复现步骤\n'
                                      '2) 截图 / 录屏\n'
                                      '3) 已复制的诊断信息\n'
                                      '\n'
                                      '若包含敏感信息，请先打码。',
                                  en: 'Please include:\n'
                                      '1) Steps to reproduce\n'
                                      '2) Screenshot / screen recording\n'
                                      '3) Copied diagnostics\n'
                                      '\n'
                                      'If it contains sensitive info, redact it before submitting.',
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
