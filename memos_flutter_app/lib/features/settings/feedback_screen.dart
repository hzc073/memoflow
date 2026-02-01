import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/db/app_database.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'submit_logs_screen.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

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

    Future<void> forceResetHeatmap() async {
      final session = ref.read(appSessionProvider).valueOrNull;
      final accountKey = session?.currentKey;
      if (accountKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '请先登录', en: 'Please sign in first'))),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.tr(zh: '重置热力图？', en: 'Reset heatmap?')),
              content: Text(
                context.tr(
                  zh: '这会清空本地缓存（离线笔记/待同步队列）并重新全量同步。未同步内容会丢失，可能需要一些时间。是否继续？',
                  en: 'This clears local cache (offline memos/pending queue) and triggers a full resync. Unsynced content will be lost and it may take a while. Continue?',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.tr(zh: '取消', en: 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.tr(zh: '继续', en: 'Continue')),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '正在重置本地数据...', en: 'Resetting local data...'))),
      );

      try {
        final db = ref.read(databaseProvider);
        await db.close();
      } catch (_) {}

      try {
        await AppDatabase.deleteDatabaseFile(dbName: databaseNameForAccountKey(accountKey));
        ref.invalidate(databaseProvider);
        ref.invalidate(syncControllerProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '重置失败：$e', en: 'Reset failed: $e'))),
        );
        return;
      }

      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '已重置，开始重新同步', en: 'Reset done. Syncing...'))),
      );
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
                    icon: Icons.restart_alt,
                    label: context.tr(zh: '自助修复：重置热力图', en: 'Self repair: reset heatmap'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await forceResetHeatmap();
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

