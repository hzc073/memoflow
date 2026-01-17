import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';

class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    Widget content() {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _Section(
            title: '随机漫步',
            textMuted: textMuted,
            child: _WidgetCard(
              card: card,
              border: border,
              preview: _WidgetPreview(
                height: 140,
                isDark: isDark,
                textMuted: textMuted,
                child: const _QuotePreview(),
              ),
              onAdd: () => _showNotImplemented(context),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: '快速输入',
            textMuted: textMuted,
            child: _WidgetCard(
              card: card,
              border: border,
              preview: _WidgetPreview(
                height: 92,
                isDark: isDark,
                textMuted: textMuted,
                child: const _QuickInputPreview(),
              ),
              onAdd: () => _showNotImplemented(context),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: '记录统计',
            textMuted: textMuted,
            child: _WidgetCard(
              card: card,
              border: border,
              preview: _WidgetPreview(
                height: 120,
                isDark: isDark,
                textMuted: textMuted,
                child: const _HeatmapPreview(),
              ),
              onAdd: () => _showNotImplemented(context),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'MEMOFLOW · v0.8',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: textMuted.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
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
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('小组件'),
        centerTitle: false,
      ),
      body: isDark
          ? Stack(
              children: [
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
                content(),
              ],
            )
          : content(),
    );
  }

  static void _showNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加到桌面：待实现')));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.textMuted, required this.child});

  final String title;
  final Color textMuted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _WidgetCard extends StatefulWidget {
  const _WidgetCard({
    required this.card,
    required this.border,
    required this.preview,
    required this.onAdd,
  });

  final Color card;
  final Color border;
  final Widget preview;
  final VoidCallback onAdd;

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.border),
        boxShadow: isDark
            ? [
                BoxShadow(
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ]
            : [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          widget.preview,
          const SizedBox(height: 14),
          GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onAdd();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 140),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: MemoFlowPalette.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Center(
                  child: Text(
                    '添加到桌面',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({
    required this.height,
    required this.isDark,
    required this.textMuted,
    required this.child,
  });

  final double height;
  final bool isDark;
  final Color textMuted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _QuotePreview extends StatelessWidget {
  const _QuotePreview();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.65);
    return Center(
      child: Text(
        '“记住时刻，感受生活的温度。”\n每天来点小回顾吧。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.3, color: text, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QuickInputPreview extends StatelessWidget {
  const _QuickInputPreview();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final field = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final text = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.5);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: field,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('有什么新鲜事？', style: TextStyle(color: text, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: MemoFlowPalette.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.south_east_rounded, size: 18, color: Colors.white),
        ),
      ],
    );
  }
}

class _HeatmapPreview extends StatelessWidget {
  const _HeatmapPreview();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.65);
    final dotBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final dotHot = MemoFlowPalette.primary.withValues(alpha: isDark ? 0.8 : 0.9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACTIVITY HEATMAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: text)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('128', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: dotHot)),
            const SizedBox(width: 6),
            Text('Total notes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            Text('Last 14 days', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(28, (i) {
            final hot = (i % 7 == 2) || (i % 11 == 0);
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: hot ? dotHot : dotBg,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}


