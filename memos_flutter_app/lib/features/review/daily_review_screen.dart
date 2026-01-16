import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/local_memo.dart';
import '../../state/memos_providers.dart';
import '../memos/memos_list_screen.dart';

class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    final memosAsync = ref.watch(
      memosStreamProvider(
        (
          searchQuery: '',
          state: 'NORMAL',
          tag: null,
        ),
      ),
    );

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
          onPressed: _back,
        ),
        title: const Text('每日回顾'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享：待实现'))),
            child: Text(
              '分享',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.85 : 1.0),
              ),
            ),
          ),
        ],
      ),
      body: memosAsync.when(
        data: (memos) {
          if (memos.isEmpty) {
            return Center(child: Text('暂无内容', style: TextStyle(color: textMuted)));
          }

          final pageCount = math.min(memos.length, 10);
          final clampedIndex = pageCount <= 0 ? 0 : _index.clamp(0, pageCount - 1);

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark ? Colors.black : Colors.black).withValues(alpha: isDark ? 0.55 : 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: PageView.builder(
                        controller: _controller,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemCount: pageCount,
                        itemBuilder: (context, i) {
                          final memo = memos[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _ReviewCard(
                              memo: memo,
                              card: card,
                              textMain: textMain,
                              textMuted: textMuted,
                              isDark: isDark,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Dots(
                    count: pageCount,
                    index: clampedIndex,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '‹‹   SWIPE TO EXPLORE   ››',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: textMuted.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'REFLECT & RECALL',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                      color: textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.memo,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final LocalMemo memo;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dt = memo.createTime;
    final dateText = '${dt.year}年${dt.month.toString().padLeft(2, '0')}月${dt.day.toString().padLeft(2, '0')}日';
    final relative = _relative(dt);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateText  ·  $relative',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  memo.content.trim().isEmpty ? '（空内容）' : memo.content.trim(),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 1) return '今天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}周前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
    return '${(diff.inDays / 365).floor()}年前';
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.isDark});

  final int count;
  final int index;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox(height: 8);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (i) {
        final selected = i == index;
        final color = selected
            ? (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.8))
            : (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.18));
        return Container(
          width: selected ? 8 : 6,
          height: selected ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
