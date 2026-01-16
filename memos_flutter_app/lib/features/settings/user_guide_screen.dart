import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';

class UserGuideScreen extends ConsumerWidget {
  const UserGuideScreen({super.key});

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
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('使用指南'),
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
                    icon: Icons.refresh,
                    title: '下拉刷新',
                    subtitle: '同步最近内容',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: '下拉刷新',
                        body: '在 Memo 列表页向下拖动即可刷新并触发同步。同步会优先拉取最近的一批内容；定期可执行一次全量同步，以保证统计/热力图数据完整。',
                      );
                    },
                  ),
                  _GuideRow(
                    icon: Icons.cloud_off_outlined,
                    title: '离线可用',
                    subtitle: '本地库 + 待同步队列',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: '离线可用',
                        body: '离线时创建/编辑/删除会先写入本地数据库，并进入待同步队列；联网后会按顺序补发。为了避免误操作，未提交的编辑内容也可以进入草稿箱。',
                      );
                    },
                  ),
                  _GuideRow(
                    icon: Icons.search,
                    title: '全文搜索',
                    subtitle: '支持内容/标签',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: '全文搜索',
                        body: '在搜索框输入关键字即可搜索本地内容与标签。离线场景下也能使用；首次使用建议等待本地索引构建完成。',
                      );
                    },
                  ),
                  _GuideRow(
                    icon: Icons.graphic_eq,
                    title: '语音 Memo',
                    subtitle: '录音后生成 memo',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _showInfo(
                        context,
                        title: '语音 Memo',
                        body: '录音完成后会先生成一条本地 memo，并将音频加入待同步队列。最长支持 60 分钟；录音转写可在后续接入第三方服务实现。',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '提示：后端无需改动即可实现大部分能力（离线/统计/AI 报告/导出等），但 token 本身只会在创建时返回一次，请注意保存。',
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

