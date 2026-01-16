import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log_sanitizer.dart';
import '../../core/memoflow_palette.dart';
import '../../state/database_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

  Future<String> _buildDiagnostics(WidgetRef ref) async {
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
        ? '未登录'
        : LogSanitizer.maskUserLabel(
            account.user.displayName.isNotEmpty ? account.user.displayName : account.user.name,
          );
    final hostRaw = account?.baseUrl.toString() ?? '';
    final host = hostRaw.isEmpty ? '' : LogSanitizer.maskUrl(hostRaw);

    return [
      'MemoFlow 诊断信息',
      '时间：${DateTime.now().toIso8601String()}',
      '',
      '账号：$accountLabel',
      '后端：$host',
      '',
      '本地数据：',
      '- memos：$memosCount',
      '- 待同步 memos：$pendingCount',
      '- outbox：$outboxCount',
      '- 待处理 outbox：$outboxPending',
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制诊断信息')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e')));
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
        title: const Text('反馈建议'),
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
                    label: '复制诊断信息',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      unawaited(copyDiagnostics());
                    },
                  ),
                  _ActionRow(
                    icon: Icons.help_outline,
                    label: '如何反馈？',
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
                            children: const [
                              Text('如何反馈？', style: TextStyle(fontWeight: FontWeight.w800)),
                              SizedBox(height: 12),
                              Text(
                                '建议附带：\n'
                                '1) 复现步骤\n'
                                '2) 截图/录屏\n'
                                '3) 复制的诊断信息\n'
                                '\n'
                                '如果涉及隐私信息，请先脱敏再提交。',
                                style: TextStyle(height: 1.5),
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
                '提示：部分 Token 仅在创建时返回一次，后续无法从服务器再次获取，请妥善保存。',
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
