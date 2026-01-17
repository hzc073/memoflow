import 'dart:math' as math;

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/local_memo.dart';
import '../../state/memos_providers.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memo_markdown.dart';
import '../memos/memos_list_screen.dart';

class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  final _swiperController = AppinioSwiperController();
  final _random = math.Random();
  late final _memosProvider = memosStreamProvider((searchQuery: '', state: 'NORMAL', tag: null));

  List<LocalMemo> _deck = const [];
  List<String> _memoIds = const [];
  int _cursor = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(_memosProvider, (prev, next) {
      next.whenData((memos) {
        final changed = _syncDeck(memos);
        if (!changed || !mounted) return;
        setState(() {});
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  bool _sameIds(List<String> next) {
    if (_memoIds.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (_memoIds[i] != next[i]) return false;
    }
    return true;
  }

  bool _syncDeck(List<LocalMemo> memos) {
    final ids = memos.map((m) => m.uid).toList(growable: false);
    if (_sameIds(ids)) return false;

    _memoIds = ids;
    _deck = List<LocalMemo>.from(memos)..shuffle(_random);
    _cursor = 0;
    return true;
  }

  void _rotateLeft() {
    if (_deck.length <= 1) return;
    final first = _deck.first;
    _deck = [..._deck.sublist(1), first];
  }

  void _rotateRight() {
    if (_deck.length <= 1) return;
    final last = _deck.last;
    _deck = [last, ..._deck.sublist(0, _deck.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    final memosAsync = ref.watch(_memosProvider);

    return WillPopScope(
      onWillPop: () async {
        _back();
        return false;
      },
      child: Scaffold(
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
          title: const Text('随机漫步'),
          centerTitle: true,
        ),
        body: memosAsync.when(
        data: (memos) {
          if (memos.isEmpty) {
            return Center(child: Text('暂无内容', style: TextStyle(color: textMuted)));
          }

          final deck = _deck;
          final total = deck.length;
          final displayIndex = total == 0 ? 0 : (_cursor + 1).clamp(1, total);

          return Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '随机抽取你的卡片笔记',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                      ),
                    ),
                    Text(
                      '$displayIndex / $total',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 140),
                  child: AppinioSwiper(
                    controller: _swiperController,
                    cardCount: deck.length,
                    backgroundCardCount: 3,
                    backgroundCardScale: 0.92,
                    backgroundCardOffset: const Offset(0, 24),
                    swipeOptions: const SwipeOptions.symmetric(horizontal: true),
                    maxAngle: 14,
                    onSwipeEnd: (previousIndex, targetIndex, activity) {
                      if (!mounted) return;
                      setState(() {
                        if (activity.direction == AxisDirection.right) {
                          _rotateRight();
                          _cursor = (_cursor - 1 + deck.length) % deck.length;
                        } else {
                          _rotateLeft();
                          _cursor = (_cursor + 1) % deck.length;
                        }
                        _swiperController.setCardIndex(0);
                      });
                    },
                    cardBuilder: (context, index) {
                      final memo = deck[index];
                      return _RandomWalkCard(
                        memo: memo,
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        ),
      ),
    );
  }
}

class _RandomWalkCard extends StatelessWidget {
  const _RandomWalkCard({
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
    final dt = memo.updateTime;
    final dateText = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final relative = _relative(dt);
    final content = memo.content.trim().isEmpty ? '（空内容）' : memo.content.trim();
    final contentStyle = TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: textMain);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) => MemoDetailScreen(initialMemo: memo),
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(opacity: fade, child: child);
            },
          ),
        );
      },
      child: Hero(
        tag: memo.uid,
        createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateText,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: textMuted.withValues(alpha: 0.5), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        relative,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bodyHeight = constraints.maxHeight;
                        final fadeHeight = bodyHeight * 0.2;
                        return Stack(
                          children: [
                            SizedBox(
                              height: bodyHeight,
                              width: double.infinity,
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: MemoMarkdown(
                                  data: content,
                                  textStyle: contentStyle,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: fadeHeight,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        card.withAlpha(0),
                                        card,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
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
