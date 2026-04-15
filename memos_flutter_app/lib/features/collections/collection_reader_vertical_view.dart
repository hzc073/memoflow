import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/models/local_memo.dart';
import 'collection_reader_animation_delegate.dart';
import 'collection_reader_no_anim_delegate.dart';
import '../memos/widgets/memo_reader_content.dart';

class CollectionReaderVerticalView extends StatelessWidget {
  const CollectionReaderVerticalView({
    super.key,
    required this.viewportKey,
    required this.scrollController,
    required this.items,
    required this.itemKeys,
    required this.highlightQuery,
    required this.highlightMemoUid,
    required this.pagePadding,
    required this.contentTextStyle,
    required this.metaTextStyle,
    required this.allowTextSelection,
    required this.previewImageOnTap,
    required this.onCenterTap,
    required this.onChapterMeasured,
    required this.onUserScrollStart,
  });

  final GlobalKey viewportKey;
  final ScrollController scrollController;
  final List<LocalMemo> items;
  final Map<int, GlobalKey> itemKeys;
  final String? highlightQuery;
  final String? highlightMemoUid;
  final EdgeInsets pagePadding;
  final TextStyle contentTextStyle;
  final TextStyle metaTextStyle;
  final bool allowTextSelection;
  final bool previewImageOnTap;
  final VoidCallback onCenterTap;
  final void Function(int index, double height) onChapterMeasured;
  final VoidCallback onUserScrollStart;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          onUserScrollStart();
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final renderObject = context.findRenderObject() as RenderBox?;
          final size = renderObject?.size;
          if (size == null) {
            onCenterTap();
            return;
          }
          final region = const NoAnimDelegate().resolveTapRegion(
            details: details,
            size: size,
          );
          if (region == CollectionReaderTapRegion.center) {
            onCenterTap();
          }
        },
        child: CustomScrollView(
          key: viewportKey,
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: pagePadding.top,
                bottom: pagePadding.bottom + 72,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final memo = items[index];
                  final key = itemKeys.putIfAbsent(
                    index,
                    () => GlobalKey(debugLabel: 'readerChapter$index'),
                  );
                  return _MeasuredChapter(
                    key: key,
                    onMeasured: (height) => onChapterMeasured(index, height),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: pagePadding.left,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index > 0)
                            Divider(
                              height: 32,
                              thickness: 1,
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.18),
                            ),
                          MemoReaderContent(
                            memo: memo,
                            highlightQuery: highlightMemoUid == memo.uid
                                ? highlightQuery
                                : null,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            contentTextStyle: contentTextStyle,
                            metaTextStyle: metaTextStyle,
                            selectable: allowTextSelection,
                            previewImageOnTap: previewImageOnTap,
                            mediaMaxHeightFactor: 0.32,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                }, childCount: items.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasuredChapter extends StatefulWidget {
  const _MeasuredChapter({
    super.key,
    required this.child,
    required this.onMeasured,
  });

  final Widget child;
  final ValueChanged<double> onMeasured;

  @override
  State<_MeasuredChapter> createState() => _MeasuredChapterState();
}

class _MeasuredChapterState extends State<_MeasuredChapter> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderObject = context.findRenderObject() as RenderBox?;
      if (renderObject == null || !renderObject.hasSize) {
        return;
      }
      final size = renderObject.size;
      if (_lastSize == size) {
        return;
      }
      _lastSize = size;
      unawaited(Future<void>(() => widget.onMeasured(size.height)));
    });
    return widget.child;
  }
}
