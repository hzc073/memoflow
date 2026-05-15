import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/models/collection_readable_item.dart';
import '../../data/models/rss_article.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_animation_delegate.dart';
import 'collection_reader_no_anim_delegate.dart';
import 'collection_reader_utils.dart';
import 'collection_rss_html_content.dart';
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
    required this.onSaveRssItemAsMemo,
    required this.onFetchRssItemFullContent,
    required this.onCenterTap,
    required this.onChapterMeasured,
    required this.onUserScrollStart,
  });

  final GlobalKey viewportKey;
  final ScrollController scrollController;
  final List<CollectionReadableItem> items;
  final Map<int, GlobalKey> itemKeys;
  final String? highlightQuery;
  final String? highlightMemoUid;
  final EdgeInsets pagePadding;
  final TextStyle contentTextStyle;
  final TextStyle metaTextStyle;
  final bool allowTextSelection;
  final bool previewImageOnTap;
  final ValueChanged<CollectionReadableItem> onSaveRssItemAsMemo;
  final Future<void> Function(CollectionReadableItem) onFetchRssItemFullContent;
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
                          _ReadableItemContent(
                            item: memo,
                            highlightQuery: highlightMemoUid == memo.uid
                                ? highlightQuery
                                : null,
                            contentTextStyle: contentTextStyle,
                            metaTextStyle: metaTextStyle,
                            allowTextSelection: allowTextSelection,
                            previewImageOnTap: previewImageOnTap,
                            onSaveRssItemAsMemo: onSaveRssItemAsMemo,
                            onFetchRssItemFullContent:
                                onFetchRssItemFullContent,
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

class _ReadableItemContent extends StatelessWidget {
  const _ReadableItemContent({
    required this.item,
    required this.highlightQuery,
    required this.contentTextStyle,
    required this.metaTextStyle,
    required this.allowTextSelection,
    required this.previewImageOnTap,
    required this.onSaveRssItemAsMemo,
    required this.onFetchRssItemFullContent,
  });

  final CollectionReadableItem item;
  final String? highlightQuery;
  final TextStyle contentTextStyle;
  final TextStyle metaTextStyle;
  final bool allowTextSelection;
  final bool previewImageOnTap;
  final ValueChanged<CollectionReadableItem> onSaveRssItemAsMemo;
  final Future<void> Function(CollectionReadableItem) onFetchRssItemFullContent;

  @override
  Widget build(BuildContext context) {
    final memo = item.localMemo;
    if (memo != null) {
      return MemoReaderContent(
        memo: memo,
        highlightQuery: highlightQuery,
        padding: const EdgeInsets.symmetric(vertical: 8),
        contentTextStyle: contentTextStyle,
        metaTextStyle: metaTextStyle,
        selectable: allowTextSelection,
        previewImageOnTap: previewImageOnTap,
        mediaMaxHeightFactor: 0.32,
      );
    }

    final body = CollectionRssHtmlContent(
      html: item.content,
      textStyle: contentTextStyle,
    );
    final saved = item.savedMemoUid?.trim().isNotEmpty == true;
    final article = item.rssArticle;
    final fullContentStatus = article?.fullContentStatus;
    final fetchingFullContent =
        fullContentStatus == RssArticleFullContentStatus.fetching;
    final fullContentFailed =
        fullContentStatus == RssArticleFullContentStatus.failed;
    final fullContentSkipped =
        fullContentStatus == RssArticleFullContentStatus.skipped;
    final canFetchFullContent =
        !fetchingFullContent && item.originalUrl?.trim().isNotEmpty == true;
    final fullContentLabel = fullContentFailed || fullContentSkipped
        ? context.t.strings.collections.rss.retryFullContent
        : context.t.strings.collections.rss.fetchFullContent;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(buildCollectionReaderTocSubtitle(item), style: metaTextStyle),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: saved ? null : () => onSaveRssItemAsMemo(item),
              icon: Icon(
                saved
                    ? Icons.bookmark_added_rounded
                    : Icons.bookmark_add_outlined,
              ),
              label: Text(
                saved
                    ? context.t.strings.collections.rss.savedAsMemo
                    : context.t.strings.collections.rss.saveAsMemo,
              ),
            ),
          ),
          if (article != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: canFetchFullContent
                    ? () => onFetchRssItemFullContent(item)
                    : null,
                icon: fetchingFullContent
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  fetchingFullContent
                      ? context.t.strings.collections.rss.fetchingFullContent
                      : fullContentLabel,
                ),
              ),
            ),
            if (fullContentFailed || fullContentSkipped) ...[
              const SizedBox(height: 6),
              Text(
                fullContentFailed
                    ? context.t.strings.collections.rss.fullContentFailed
                    : context.t.strings.collections.rss.fullContentSkipped,
                style: metaTextStyle,
              ),
            ],
          ],
          const SizedBox(height: 10),
          body,
          if (item.savedMemoUid?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              context.t.strings.collections.rss.savedAsMemo,
              style: metaTextStyle,
            ),
          ],
        ],
      ),
    );
    if (!allowTextSelection) {
      return content;
    }
    return SelectionArea(child: content);
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
      widget.onMeasured(size.height);
    });
    return widget.child;
  }
}
