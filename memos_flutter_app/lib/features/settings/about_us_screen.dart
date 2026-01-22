import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

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
        title: Text(context.tr(zh: '关于', en: 'About')),
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
              Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MemoFlow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textMain)),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        zh: '一个基于 Memos 后端的离线优先客户端。',
                        en: 'An offline-first client for the Memos backend.',
                      ),
                      style: TextStyle(fontSize: 13, height: 1.4, color: textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _FeatureRow(
                    icon: Icons.cloud_sync_outlined,
                    title: context.tr(zh: '离线同步', en: 'Offline Sync'),
                    subtitle: context.tr(zh: '本地数据库 + 待同步队列', en: 'Local DB + outbox queue'),
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _FeatureRow(
                    icon: Icons.auto_awesome,
                    title: context.tr(zh: 'AI 总结', en: 'AI Reports'),
                    subtitle: context.tr(zh: '支持按时间范围总结', en: 'Summaries over selected range'),
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _FeatureRow(
                    icon: Icons.graphic_eq,
                    title: context.tr(zh: '语音备忘', en: 'Voice Memos'),
                    subtitle: context.tr(zh: '录音生成 memo（可稍后同步）', en: 'Record and create memos (sync later)'),
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _FeatureRow(
                    icon: Icons.search,
                    title: context.tr(zh: '全文搜索', en: 'Full-Text Search'),
                    subtitle: context.tr(zh: '内容 + 标签', en: 'Content + tags'),
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Column(
                children: [
                  FutureBuilder<PackageInfo>(
                    future: _packageInfoFuture,
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version.trim() ?? '';
                      final label = version.isEmpty
                          ? context.tr(zh: '版本', en: 'Version')
                          : context.tr(zh: '版本 v$version', en: 'Version v$version');
                      return Text(label, style: TextStyle(fontSize: 11, color: textMuted));
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(zh: '为记录而生', en: 'Made with love for note-taking'),
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textMuted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        ],
      ),
    );
  }
}
