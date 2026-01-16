import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('关于我们'),
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
                      '一个面向 Memos 后端的离线优先客户端。',
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
                    title: '离线同步',
                    subtitle: '本地库 + Outbox 队列',
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _FeatureRow(
                    icon: Icons.auto_awesome,
                    title: 'AI 报告',
                    subtitle: '选择范围生成总结',
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _FeatureRow(
                    icon: Icons.graphic_eq,
                    title: '语音 Memo',
                    subtitle: '录音后生成 memo（可待同步）',
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _FeatureRow(
                    icon: Icons.search,
                    title: '全文搜索',
                    subtitle: '内容 + 标签',
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Column(
                children: [
                  Text('版本 v0.8', style: TextStyle(fontSize: 11, color: textMuted)),
                  const SizedBox(height: 4),
                  Text('Made with ♥ for note-taking', style: TextStyle(fontSize: 11, color: textMuted)),
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

