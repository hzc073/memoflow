import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';

class UserGuideScreen extends ConsumerWidget {
  const UserGuideScreen({super.key});

  Future<void> _openBackendDocs(BuildContext context) async {
    final uri = Uri.parse('https://usememos.com/docs');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(zh: '无法打开浏览器，请稍后重试', en: 'Unable to open browser. Please try again.')),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(zh: '打开失败，请稍后重试', en: 'Failed to open. Please try again.')),
        ),
      );
    }
  }

  Future<void> _showInfo(BuildContext context, {required String title, required String body}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
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
        title: Text(context.tr(zh: '使用指南', en: 'User Guide')),
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
                  _GuideRow(
                    icon: Icons.menu_book_outlined,
                    title: context.tr(zh: 'memos后端使用文档', en: 'Memos Backend Docs'),
                    subtitle: 'usememos.com/docs',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _openBackendDocs(context);
                    },
                  ),
                  _GuideRow(
                    icon: Icons.refresh,
                    title: context.tr(zh: '下拉刷新', en: 'Pull to Refresh'),
                    subtitle: context.tr(zh: '同步最近内容', en: 'Sync recent content'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: context.tr(zh: '下拉刷新', en: 'Pull to Refresh'),
                        body: context.tr(
                          zh: '在笔记列表下拉即可刷新并同步。同步会优先拉取最新内容；建议定期全量同步以保持统计/热力图完整。',
                          en: 'Pull down in the memo list to refresh and sync. Sync fetches the most recent items first; run a full sync periodically to keep stats/heatmap complete.',
                        ),
                      );
                    },
                  ),
                  _GuideRow(
                    icon: Icons.cloud_off_outlined,
                    title: context.tr(zh: '离线可用', en: 'Offline Ready'),
                    subtitle: context.tr(zh: '本地数据库 + 待同步队列', en: 'Local DB + pending queue'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: context.tr(zh: '离线可用', en: 'Offline Ready'),
                        body: context.tr(
                          zh: '离线创建/编辑/删除会先保存在本地并加入待同步队列，联网后按顺序发送。为避免误操作，未提交的编辑可保留为草稿。',
                          en: 'Create/edit/delete actions offline are stored locally and queued for sync. They are sent in order when online. To avoid mistakes, unsubmitted edits can be kept as drafts.',
                        ),
                      );
                    },
                  ),
                  _GuideRow(
                    icon: Icons.search,
                    title: context.tr(zh: '全文搜索', en: 'Full-Text Search'),
                    subtitle: context.tr(zh: '内容 + 标签', en: 'Content + tags'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: context.tr(zh: '全文搜索', en: 'Full-Text Search'),
                        body: context.tr(
                          zh: '在搜索框输入关键词可检索本地内容与标签。离线可用；首次使用请等待本地索引完成。',
                          en: 'Enter keywords in the search box to query local content and tags. Works offline; for first use, wait until local indexing finishes.',
                        ),
                      );
                    },
                  ),
                  _GuideRow(
                    icon: Icons.graphic_eq,
                    title: context.tr(zh: '语音备忘', en: 'Voice Memos'),
                    subtitle: context.tr(zh: '录音生成 memo', en: 'Record to create memos'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: context.tr(zh: '语音备忘', en: 'Voice Memos'),
                        body: context.tr(
                          zh: '录音完成后会将音频作为附件加入当前草稿，便于继续编辑后再发送。最长 60 分钟；可后续通过第三方服务转写。',
                          en: 'After recording, the audio is added to the current draft as an attachment so you can edit before sending. Max length is 60 minutes; transcription can be added via third-party services later.',
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  zh: '提示：大部分功能（离线/统计/AI 总结/导出）无需后端改动，但 Token 只返回一次，请妥善保存。',
                  en: 'Note: Most features (offline/stats/AI reports/export) work without backend changes, but tokens are returned only once?please keep them safe.',
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

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
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
