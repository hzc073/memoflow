import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../data/models/attachment.dart';
import '../../data/models/collection_reader.dart';
import '../../data/models/local_memo.dart';
import '../memos/memo_image_src_normalizer.dart';
import 'collection_reader_page_models.dart';
import 'collection_reader_utils.dart';

class CollectionReaderPageEngine {
  static const double _pageRenderSafetyPadding = 8;

  final Map<String, ReaderChapterLayout> _chapterCache =
      <String, ReaderChapterLayout>{};
  final Map<String, int> _chapterPageCountCache = <String, int>{};

  @visibleForTesting
  Set<String> get debugCachedMemoUids =>
      _chapterCache.values.map((layout) => layout.memo.uid).toSet();

  @visibleForTesting
  Set<String> get debugCountCachedMemoUids => _chapterPageCountCache.keys
      .map((key) => key.split('|').first)
      .where((memoUid) => memoUid.isNotEmpty)
      .toSet();

  void clear() {
    _chapterCache.clear();
    _chapterPageCountCache.clear();
  }

  void clearForMemo(String memoUid) {
    _chapterCache.removeWhere((key, _) => key.startsWith('$memoUid|'));
    _chapterPageCountCache.removeWhere((key, _) => key.startsWith('$memoUid|'));
  }

  void retainChapterLayoutsForMemoUids(Set<String> memoUids) {
    _chapterCache.removeWhere(
      (_, layout) => !memoUids.contains(layout.memo.uid),
    );
  }

  CollectionReaderPagedBook buildBook({
    required List<LocalMemo> items,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    String collectionTitle = '',
    Set<int>? retainMemoIndexes,
  }) {
    final chapters = <ReaderChapterLayout>[];
    final pages = <ReaderResolvedPage>[];
    final retainedMemoUids = <String>{};
    final expandedRetainMemoIndexes = retainMemoIndexes == null
        ? null
        : _expandRetainedMemoIndexes(
            retainMemoIndexes,
            itemCount: items.length,
          );
    var globalPageIndex = 0;
    for (var index = 0; index < items.length; index += 1) {
      final shouldCache =
          expandedRetainMemoIndexes == null ||
          expandedRetainMemoIndexes.contains(index);
      if (shouldCache) {
        retainedMemoUids.add(items[index].uid);
      }
      final chapter = _layoutChapter(
        memo: items[index],
        memoIndex: index,
        viewportSize: viewportSize,
        preferences: preferences,
        collectionTitle: collectionTitle,
        cacheResult: shouldCache,
      );
      chapters.add(chapter);
      for (final page in chapter.pages) {
        pages.add(
          ReaderResolvedPage(globalPageIndex: globalPageIndex, page: page),
        );
        globalPageIndex += 1;
      }
    }
    if (retainMemoIndexes != null) {
      _chapterCache.removeWhere(
        (_, layout) => !retainedMemoUids.contains(layout.memo.uid),
      );
    }
    return CollectionReaderPagedBook(chapters: chapters, pages: pages);
  }

  CollectionReaderPageMap buildPageMap({
    required List<LocalMemo> items,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    String collectionTitle = '',
    Set<int>? retainMemoIndexes,
  }) {
    final chapters = <ReaderChapterPageMetrics>[];
    final retainedMemoUids = <String>{};
    final expandedRetainMemoIndexes = retainMemoIndexes == null
        ? null
        : _expandRetainedMemoIndexes(
            retainMemoIndexes,
            itemCount: items.length,
          );
    var globalPageStartIndex = 0;
    for (var index = 0; index < items.length; index += 1) {
      final shouldCache =
          expandedRetainMemoIndexes == null ||
          expandedRetainMemoIndexes.contains(index);
      if (shouldCache) {
        retainedMemoUids.add(items[index].uid);
      }
      final pageCount = _resolveChapterPageCount(
        memo: items[index],
        memoIndex: index,
        viewportSize: viewportSize,
        preferences: preferences,
        collectionTitle: collectionTitle,
        cacheResult: shouldCache,
      );
      chapters.add(
        ReaderChapterPageMetrics(
          memoUid: items[index].uid,
          memoIndex: index,
          pageCount: pageCount,
          globalPageStartIndex: globalPageStartIndex,
        ),
      );
      globalPageStartIndex += pageCount;
    }
    if (retainMemoIndexes != null) {
      _chapterCache.removeWhere(
        (_, layout) => !retainedMemoUids.contains(layout.memo.uid),
      );
    }
    return CollectionReaderPageMap(
      chapters: chapters,
      totalPages: globalPageStartIndex,
    );
  }

  ReaderChapterLayout layoutChapter({
    required LocalMemo memo,
    required int memoIndex,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    String collectionTitle = '',
  }) {
    return _layoutChapter(
      memo: memo,
      memoIndex: memoIndex,
      viewportSize: viewportSize,
      preferences: preferences,
      collectionTitle: collectionTitle,
      cacheResult: true,
    );
  }

  ReaderChapterLayout _layoutChapter({
    required LocalMemo memo,
    required int memoIndex,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    required String collectionTitle,
    required bool cacheResult,
  }) {
    final cacheKey = _buildCacheKey(
      memo: memo,
      viewportSize: viewportSize,
      preferences: preferences,
      collectionTitle: collectionTitle,
    );
    final cached = _chapterCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final document = _buildChapterDocument(
      memo,
      memoIndex,
      collectionTitle: collectionTitle,
    );
    final pages = _paginateDocument(
      document: document,
      viewportSize: viewportSize,
      preferences: preferences,
      collectionTitle: collectionTitle,
    );
    final layout = ReaderChapterLayout(
      memo: memo,
      memoIndex: memoIndex,
      cacheKey: cacheKey,
      document: document,
      pages: pages,
    );
    _chapterPageCountCache[cacheKey] = layout.pages.length;
    if (cacheResult) {
      _chapterCache[cacheKey] = layout;
    }
    return layout;
  }

  int resolveChapterPageIndexForOffset(
    ReaderChapterLayout chapter,
    int charOffset,
  ) {
    if (chapter.pages.isEmpty) {
      return 0;
    }
    final safeOffset = math.max(0, charOffset);
    for (final page in chapter.pages) {
      final pageStart = page.contentCharStart;
      final pageEnd = math.max(page.contentCharEnd, pageStart + 1);
      if (safeOffset >= pageStart && safeOffset < pageEnd) {
        return page.chapterPageIndex;
      }
    }
    if (safeOffset <= chapter.pages.first.contentCharStart) {
      return 0;
    }
    return chapter.pages.last.chapterPageIndex;
  }

  int resolveRestoredChapterPageIndex({
    required ReaderChapterLayout chapter,
    required int storedChapterPageIndex,
    int? matchCharOffset,
  }) {
    if (chapter.pages.isEmpty) {
      return 0;
    }
    if (matchCharOffset != null) {
      return resolveChapterPageIndexForOffset(chapter, matchCharOffset);
    }
    return storedChapterPageIndex
        .clamp(0, math.max(0, chapter.pages.length - 1))
        .toInt();
  }

  int resolveGlobalPageIndex({
    required CollectionReaderPagedBook book,
    required int memoIndex,
    required int chapterPageIndex,
  }) {
    for (final page in book.pages) {
      if (page.page.memoIndex == memoIndex &&
          page.page.chapterPageIndex == chapterPageIndex) {
        return page.globalPageIndex;
      }
    }
    return 0;
  }

  int resolveGlobalPageIndexForMap({
    required CollectionReaderPageMap pageMap,
    required int memoIndex,
    required int chapterPageIndex,
  }) {
    if (pageMap.chapters.isEmpty) {
      return 0;
    }
    final safeMemoIndex = memoIndex
        .clamp(0, math.max(0, pageMap.chapters.length - 1))
        .toInt();
    final chapter = pageMap.chapters[safeMemoIndex];
    final safeChapterPageIndex = chapterPageIndex
        .clamp(0, math.max(0, chapter.pageCount - 1))
        .toInt();
    return chapter.globalPageStartIndex + safeChapterPageIndex;
  }

  ReaderPageTarget? resolvePageTargetForGlobalIndex({
    required CollectionReaderPageMap pageMap,
    required int globalPageIndex,
  }) {
    if (pageMap.totalPages <= 0 || pageMap.chapters.isEmpty) {
      return null;
    }
    final safeGlobalIndex = globalPageIndex.clamp(0, pageMap.totalPages - 1);
    for (final chapter in pageMap.chapters) {
      if (safeGlobalIndex >= chapter.globalPageStartIndex &&
          safeGlobalIndex < chapter.globalPageEndExclusive) {
        return ReaderPageTarget(
          memoIndex: chapter.memoIndex,
          chapterPageIndex: safeGlobalIndex - chapter.globalPageStartIndex,
        );
      }
    }
    final lastChapter = pageMap.chapters.last;
    return ReaderPageTarget(
      memoIndex: lastChapter.memoIndex,
      chapterPageIndex: math.max(0, lastChapter.pageCount - 1),
    );
  }

  ReaderChapterDocument _buildChapterDocument(
    LocalMemo memo,
    int memoIndex, {
    required String collectionTitle,
  }) {
    final blocks = <ReaderBlock>[];
    blocks.add(
      ReaderBlock(
        kind: ReaderBlockKind.metaHeader,
        id: '${memo.uid}:meta',
        text: buildCollectionReaderTocSubtitle(memo),
      ),
    );
    if (memo.location != null) {
      final placeholder = memo.location!.placeholder.trim();
      blocks.add(
        ReaderBlock(
          kind: ReaderBlockKind.location,
          id: '${memo.uid}:location',
          locationLabel: placeholder.isEmpty
              ? '${memo.location!.latitude}, ${memo.location!.longitude}'
              : placeholder,
        ),
      );
    }
    final parsedContent = parseCollectionReaderContent(memo.content);
    final contentText = parsedContent.text;
    final imageAttachments = memo.attachments
        .where((item) => item.isImage)
        .toList(growable: false);
    final videoAttachments = memo.attachments
        .where((item) => item.isVideo)
        .toList(growable: false);
    final consumedImageAttachmentIndexes = <int>{};
    final consumedVideoAttachmentIndexes = <int>{};
    if (parsedContent.blocks.isNotEmpty) {
      for (var index = 0; index < parsedContent.blocks.length; index += 1) {
        final contentBlock = parsedContent.blocks[index];
        switch (contentBlock.kind) {
          case CollectionReaderContentBlockKind.text:
            blocks.add(
              ReaderBlock(
                kind: ReaderBlockKind.markdownText,
                id: '${memo.uid}:content:$index',
                text: contentBlock.text,
                textRole: contentBlock.textRole,
                charStart: contentBlock.charStart,
                charEnd: contentBlock.charEnd,
              ),
            );
          case CollectionReaderContentBlockKind.spacer:
            blocks.add(
              ReaderBlock(
                kind: ReaderBlockKind.spacer,
                id: '${memo.uid}:content-spacer:$index',
                heightHint: contentBlock.heightHint,
              ),
            );
          case CollectionReaderContentBlockKind.image:
            final matchedImageIndex = _findMatchingAttachmentIndex(
              sourceUrl: contentBlock.sourceUrl ?? '',
              attachments: imageAttachments,
              consumedIndexes: consumedImageAttachmentIndexes,
            );
            final matchedAttachment = matchedImageIndex == null
                ? null
                : imageAttachments[matchedImageIndex];
            if (matchedImageIndex != null) {
              consumedImageAttachmentIndexes.add(matchedImageIndex);
            }
            blocks.add(
              ReaderBlock(
                kind: ReaderBlockKind.image,
                id: '${memo.uid}:content-image:$index',
                text: _buildInlineMediaLabel(
                  sourceUrl: contentBlock.sourceUrl ?? '',
                  preferredLabel: contentBlock.text,
                  fallbackLabel: 'Image',
                ),
                attachments: matchedAttachment == null
                    ? const <Attachment>[]
                    : <Attachment>[matchedAttachment],
              ),
            );
          case CollectionReaderContentBlockKind.video:
            final matchedVideoIndex = _findMatchingAttachmentIndex(
              sourceUrl: contentBlock.sourceUrl ?? '',
              attachments: videoAttachments,
              consumedIndexes: consumedVideoAttachmentIndexes,
            );
            final matchedAttachment = matchedVideoIndex == null
                ? null
                : videoAttachments[matchedVideoIndex];
            if (matchedVideoIndex != null) {
              consumedVideoAttachmentIndexes.add(matchedVideoIndex);
            }
            blocks.add(
              ReaderBlock(
                kind: ReaderBlockKind.video,
                id: '${memo.uid}:content-video:$index',
                text: _buildInlineMediaLabel(
                  sourceUrl: contentBlock.sourceUrl ?? '',
                  preferredLabel: contentBlock.text,
                  fallbackLabel: 'Video',
                ),
                attachments: matchedAttachment == null
                    ? const <Attachment>[]
                    : <Attachment>[matchedAttachment],
              ),
            );
        }
      }
    } else {
      blocks.add(
        ReaderBlock(
          kind: ReaderBlockKind.markdownText,
          id: '${memo.uid}:content',
          text: ' ',
          textRole: ReaderTextRole.body,
          charStart: 0,
          charEnd: 0,
        ),
      );
    }

    final otherAttachments = memo.attachments
        .where((item) => !item.isImage && !item.isVideo)
        .toList();

    for (var index = 0; index < imageAttachments.length; index += 1) {
      if (consumedImageAttachmentIndexes.contains(index)) {
        continue;
      }
      blocks.add(
        ReaderBlock(
          kind: ReaderBlockKind.image,
          id: '${memo.uid}:image:$index',
          attachments: <Attachment>[imageAttachments[index]],
        ),
      );
    }
    for (var index = 0; index < videoAttachments.length; index += 1) {
      if (consumedVideoAttachmentIndexes.contains(index)) {
        continue;
      }
      blocks.add(
        ReaderBlock(
          kind: ReaderBlockKind.video,
          id: '${memo.uid}:video:$index',
          attachments: <Attachment>[videoAttachments[index]],
        ),
      );
    }
    if (otherAttachments.isNotEmpty) {
      blocks.add(
        ReaderBlock(
          kind: ReaderBlockKind.attachmentList,
          id: '${memo.uid}:attachments',
          attachments: otherAttachments,
        ),
      );
    }

    return ReaderChapterDocument(
      memo: memo,
      memoIndex: memoIndex,
      blocks: blocks,
      contentText: contentText,
    );
  }

  List<ReaderPage> _paginateDocument({
    required ReaderChapterDocument document,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    required String collectionTitle,
  }) {
    final chapterTitle = buildCollectionReaderTocTitle(
      document.memo,
      document.memoIndex,
    );
    final normalizedCollectionTitle = collectionTitle.trim();
    final effectiveCollectionTitle = normalizedCollectionTitle.isNotEmpty
        ? normalizedCollectionTitle
        : chapterTitle;
    final titleSubtitle = normalizedCollectionTitle.isNotEmpty
        ? chapterTitle
        : buildCollectionReaderTocSubtitle(document.memo);
    final titleRenderData =
        preferences.titleMode == CollectionReaderTitleMode.hidden
        ? null
        : ReaderTitleRenderData(
            title: effectiveCollectionTitle,
            subtitle: titleSubtitle,
            mode: preferences.titleMode,
          );
    final headerTip = preferences.tipLayout.headerMode ==
            CollectionReaderTipDisplayMode.hidden
        ? null
        : ReaderTipRenderData(
            mode: preferences.tipLayout.headerMode,
            leftSlot: preferences.tipLayout.headerLeft,
            centerSlot: preferences.tipLayout.headerCenter,
            rightSlot: preferences.tipLayout.headerRight,
          );
    final footerTip = preferences.tipLayout.footerMode ==
            CollectionReaderTipDisplayMode.hidden
        ? null
        : ReaderTipRenderData(
            mode: preferences.tipLayout.footerMode,
            leftSlot: preferences.tipLayout.footerLeft,
            centerSlot: preferences.tipLayout.footerCenter,
            rightSlot: preferences.tipLayout.footerRight,
          );
    final reservedInsets = ReaderPageReservedInsets(
      top: preferences.tipLayout.headerMode ==
              CollectionReaderTipDisplayMode.reserved
          ? _estimateTipReservedHeight(
              padding: preferences.headerPadding,
              textScale: preferences.textScale,
              showDivider: preferences.showHeaderLine,
            )
          : 0,
      bottom: preferences.tipLayout.footerMode ==
              CollectionReaderTipDisplayMode.reserved
          ? _estimateTipReservedHeight(
              padding: preferences.footerPadding,
              textScale: preferences.textScale,
              showDivider: preferences.showFooterLine,
            )
          : 0,
    );
    final inlineHeaderHeight = preferences.tipLayout.headerMode ==
            CollectionReaderTipDisplayMode.inline
        ? _estimateTipReservedHeight(
            padding: preferences.headerPadding,
            textScale: preferences.textScale,
            showDivider: preferences.showHeaderLine,
          )
        : 0;
    final inlineFooterHeight = preferences.tipLayout.footerMode ==
            CollectionReaderTipDisplayMode.inline
        ? _estimateTipReservedHeight(
            padding: preferences.footerPadding,
            textScale: preferences.textScale,
            showDivider: preferences.showFooterLine,
          )
        : 0;
    final bodyWidth = math
        .max(120, viewportSize.width - preferences.pagePadding.horizontal)
        .toDouble();
    final firstPageTitleHeight = titleRenderData == null
        ? 0
        : _estimateTitleHeight(
            title: titleRenderData.title,
            subtitle: titleRenderData.subtitle,
            preferences: preferences,
            maxWidth: bodyWidth,
          );
    final regularBodyHeight = math
        .max(
          180,
          viewportSize.height -
              preferences.pagePadding.vertical -
              reservedInsets.top -
              reservedInsets.bottom -
              inlineHeaderHeight -
              inlineFooterHeight -
              _pageRenderSafetyPadding,
        )
        .toDouble();
    final baseFontFamily = preferences.readerFontFamily;
    final bodyFontWeight = _resolveReaderFontWeight(preferences.fontWeightMode);
    final headerStyle = TextStyle(
      fontSize: 13 * preferences.textScale,
      height: 1.4,
      fontWeight: FontWeight.w600,
      fontFamily: baseFontFamily,
      letterSpacing: preferences.letterSpacing,
    );
    final bodyStyle = TextStyle(
      fontSize: 18 * preferences.textScale,
      height: preferences.lineSpacing,
      fontFamily: baseFontFamily,
      fontWeight: bodyFontWeight,
      letterSpacing: preferences.letterSpacing,
    );
    final headingStyle = TextStyle(
      fontSize: 22 * preferences.textScale,
      height: 1.35,
      fontWeight: _resolveHeadingFontWeight(preferences.fontWeightMode),
      fontFamily: baseFontFamily,
      letterSpacing: preferences.letterSpacing,
    );
    final quoteStyle = TextStyle(
      fontSize: 17 * preferences.textScale,
      height: preferences.lineSpacing * 1.02,
      fontStyle: FontStyle.italic,
      fontFamily: baseFontFamily,
      fontWeight: bodyFontWeight,
      letterSpacing: preferences.letterSpacing,
    );
    final codeStyle = TextStyle(
      fontSize: 15 * preferences.textScale,
      height: 1.5,
      fontFamily: 'monospace',
    );
    final listStyle = TextStyle(
      fontSize: 18 * preferences.textScale,
      height: preferences.lineSpacing,
      fontFamily: baseFontFamily,
      fontWeight: bodyFontWeight,
      letterSpacing: preferences.letterSpacing,
    );
    final tableStyle = TextStyle(
      fontSize: 14 * preferences.textScale,
      height: 1.5,
      fontFamily: 'monospace',
    );
    final captionStyle = TextStyle(
      fontSize: 14 * preferences.textScale,
      height: 1.45,
      fontWeight: FontWeight.w500,
      fontFamily: baseFontFamily,
      letterSpacing: preferences.letterSpacing,
    );
    final attachmentStyle = TextStyle(
      fontSize: 14 * preferences.textScale,
      height: 1.45,
      fontFamily: baseFontFamily,
      letterSpacing: preferences.letterSpacing,
    );

    double bodyHeightForPage(int pageIndex) {
      final bodyHeight = pageIndex == 0
          ? regularBodyHeight - firstPageTitleHeight
          : regularBodyHeight;
      return math.max(120, bodyHeight).toDouble();
    }

    final pages = <ReaderPage>[];
    final currentBlocks = <ReaderPageBlock>[];
    var remainingHeight = bodyHeightForPage(0);
    int? currentPageCharStart;
    var currentPageCharEnd = 0;

    double addBlock(ReaderPageBlock block) {
      final height = block.height ?? 0;
      currentBlocks.add(block);
      remainingHeight = math.max(0, remainingHeight - height);
      if (block.charStart != null) {
        if (currentPageCharStart == null) {
          currentPageCharStart = block.charStart!;
          currentPageCharEnd = block.charEnd ?? block.charStart!;
        } else {
          currentPageCharStart = math.min(
            currentPageCharStart!,
            block.charStart!,
          );
          currentPageCharEnd = math.max(
            currentPageCharEnd,
            block.charEnd ?? block.charStart!,
          );
        }
      }
      return height;
    }

    void pushPage({bool force = false}) {
      if (currentBlocks.isEmpty && !force) {
        return;
      }
      final pageIndex = pages.length;
      pages.add(
        ReaderPage(
          memoUid: document.memo.uid,
          memoIndex: document.memoIndex,
          chapterPageIndex: pageIndex,
          contentCharStart: currentPageCharStart ?? currentPageCharEnd,
          contentCharEnd: currentPageCharEnd,
          blocks: List<ReaderPageBlock>.unmodifiable(currentBlocks),
          isFirstPage: pageIndex == 0,
          isLastPage: false,
          reservedInsets: reservedInsets,
          headerTip: headerTip,
          footerTip: footerTip,
          title: titleRenderData,
        ),
      );
      currentBlocks.clear();
      remainingHeight = bodyHeightForPage(pageIndex + 1);
      currentPageCharStart = null;
    }

    for (final block in document.blocks) {
      switch (block.kind) {
        case ReaderBlockKind.markdownText:
          final source = (block.text ?? '').replaceAll('\r\n', '\n');
          final baseCharStart = block.charStart ?? 0;
          final textStyle = switch (block.textRole) {
            ReaderTextRole.heading => headingStyle,
            ReaderTextRole.quote => quoteStyle,
            ReaderTextRole.code => codeStyle,
            ReaderTextRole.listItem => listStyle,
            ReaderTextRole.tableRow => tableStyle,
            ReaderTextRole.body => bodyStyle,
          };
          var cursor = 0;
          final hasOnlyWhitespace = source.trim().isEmpty;
          if (hasOnlyWhitespace) {
            final minimumHeight =
                _measureTextHeight(' ', style: textStyle, maxWidth: bodyWidth) +
                _markdownBlockSpacing(preferences, block.textRole);
            if (remainingHeight < minimumHeight && currentBlocks.isNotEmpty) {
              pushPage();
            }
            addBlock(
              ReaderPageBlock(
                kind: block.kind,
                id: '${block.id}:empty',
                text: ' ',
                textRole: block.textRole,
                charStart: baseCharStart,
                charEnd: block.charEnd ?? baseCharStart,
                height: minimumHeight,
              ),
            );
            continue;
          }
          while (cursor < source.length) {
            if (remainingHeight < 36 && currentBlocks.isNotEmpty) {
              pushPage();
            }
            var fitCount = _measureFittingTextCount(
              source.substring(cursor),
              style: textStyle,
              maxWidth: bodyWidth,
              maxHeight: remainingHeight,
            );
            if (fitCount <= 0) {
              if (currentBlocks.isNotEmpty) {
                pushPage();
                continue;
              }
              fitCount = _measureFittingTextCount(
                source.substring(cursor),
                style: textStyle,
                maxWidth: bodyWidth,
                maxHeight: bodyHeightForPage(pages.length),
              );
              if (fitCount <= 0) {
                fitCount = math.min(1, source.length - cursor).toInt();
              }
            }
            final safeFitCount = math
                .max(1, math.min(fitCount, source.length - cursor))
                .toInt();
            final rawEnd = cursor + safeFitCount;
            final end = _findSoftBreak(source, cursor, rawEnd);
            final sliceEnd = math.max(cursor + 1, end).toInt();
            final slice = source.substring(cursor, sliceEnd).trimRight();
            final displaySlice = _applyParagraphIndent(
              slice.isEmpty ? ' ' : slice,
              role: block.textRole,
              preferences: preferences,
            );
            final measuredHeight =
                _measureTextHeight(
                  displaySlice,
                  style: textStyle,
                  maxWidth: bodyWidth,
                ) +
                _markdownBlockChromePadding(block.textRole) +
                _markdownBlockSpacing(preferences, block.textRole);
            if (measuredHeight > remainingHeight &&
                currentBlocks.isNotEmpty &&
                remainingHeight < bodyHeightForPage(pages.length)) {
              pushPage();
              continue;
            }
            addBlock(
              ReaderPageBlock(
                kind: block.kind,
                id: '${block.id}:$cursor',
                text: displaySlice,
                textRole: block.textRole,
                charStart: baseCharStart + cursor,
                charEnd: baseCharStart + sliceEnd,
                height: measuredHeight,
              ),
            );
            cursor = _skipLeadingWhitespace(source, sliceEnd);
            if (cursor < source.length) {
              pushPage();
            }
          }
        case ReaderBlockKind.metaHeader:
        case ReaderBlockKind.location:
          final text = block.kind == ReaderBlockKind.location
              ? (block.locationLabel ?? '')
              : (block.text ?? '');
          final style = block.kind == ReaderBlockKind.metaHeader
              ? headerStyle
              : captionStyle;
          final textHeight = _measureTextHeight(
            text,
            style: style,
            maxWidth: bodyWidth,
          );
          final height =
              (block.kind == ReaderBlockKind.location
                  ? math.max(textHeight, 14 * preferences.textScale)
                  : textHeight) +
              10;
          if (height > remainingHeight && currentBlocks.isNotEmpty) {
            pushPage();
          }
          addBlock(
            ReaderPageBlock(
              kind: block.kind,
              id: block.id,
              text: text,
              locationLabel: block.locationLabel,
              height: math.min(height, regularBodyHeight).toDouble(),
            ),
          );
        case ReaderBlockKind.attachmentList:
          final attachmentText = block.attachments
              .map((item) => item.displayName.trim())
              .where((item) => item.isNotEmpty)
              .join('\n');
          final height =
              _measureTextHeight(
                attachmentText,
                style: attachmentStyle,
                maxWidth: bodyWidth,
              ) +
              36.0;
          if (height > remainingHeight && currentBlocks.isNotEmpty) {
            pushPage();
          }
          addBlock(
            ReaderPageBlock(
              kind: block.kind,
              id: block.id,
              text: attachmentText,
              attachments: block.attachments,
              height: math.min(height, regularBodyHeight).toDouble(),
            ),
          );
        case ReaderBlockKind.image:
        case ReaderBlockKind.video:
          final mediaHeight = _estimateMediaHeight(
            block.attachments.isEmpty ? null : block.attachments.first,
            viewportHeight: regularBodyHeight,
            isVideo: block.kind == ReaderBlockKind.video,
          );
          if (mediaHeight > remainingHeight && currentBlocks.isNotEmpty) {
            pushPage();
          }
          addBlock(
            ReaderPageBlock(
              kind: block.kind,
              id: block.id,
              text: block.text,
              attachments: block.attachments,
              height: mediaHeight,
            ),
          );
        case ReaderBlockKind.spacer:
          final height = math.min(block.heightHint ?? 12, regularBodyHeight)
              .toDouble();
          if (height > remainingHeight && currentBlocks.isNotEmpty) {
            pushPage();
          }
          addBlock(
            ReaderPageBlock(kind: block.kind, id: block.id, height: height),
          );
      }
    }

    pushPage(force: pages.isEmpty || currentBlocks.isNotEmpty);
    if (pages.isEmpty) {
      return <ReaderPage>[
        ReaderPage(
          memoUid: document.memo.uid,
          memoIndex: document.memoIndex,
          chapterPageIndex: 0,
          contentCharStart: 0,
          contentCharEnd: 0,
          blocks: const <ReaderPageBlock>[],
          isFirstPage: true,
          isLastPage: true,
          reservedInsets: reservedInsets,
          headerTip: headerTip,
          footerTip: footerTip,
          title: titleRenderData,
        ),
      ];
    }
    return List<ReaderPage>.generate(pages.length, (index) {
      final page = pages[index];
      return ReaderPage(
        memoUid: page.memoUid,
        memoIndex: page.memoIndex,
        chapterPageIndex: page.chapterPageIndex,
        contentCharStart: page.contentCharStart,
        contentCharEnd: page.contentCharEnd,
        blocks: page.blocks,
        isFirstPage: index == 0,
        isLastPage: index == pages.length - 1,
        reservedInsets: page.reservedInsets,
        headerTip: page.headerTip,
        footerTip: page.footerTip,
        title: page.title,
      );
    }, growable: false);
  }

  String _buildCacheKey({
    required LocalMemo memo,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    required String collectionTitle,
  }) {
    final padding = preferences.pagePadding;
    return [
      memo.uid,
      memo.contentFingerprint,
      memo.updateTime.millisecondsSinceEpoch,
      memo.attachments.length,
      viewportSize.width.round(),
      viewportSize.height.round(),
      preferences.mode.name,
      preferences.pageAnimation.name,
      preferences.textScale.toStringAsFixed(3),
      preferences.lineSpacing.toStringAsFixed(3),
      preferences.readerFontFamily ?? '',
      preferences.readerFontFile ?? '',
      preferences.fontWeightMode.name,
      preferences.letterSpacing.toStringAsFixed(3),
      preferences.paragraphSpacing.toStringAsFixed(3),
      preferences.paragraphIndentChars,
      preferences.titleMode.name,
      preferences.titleScale.toStringAsFixed(3),
      preferences.titleTopSpacing.toStringAsFixed(1),
      preferences.titleBottomSpacing.toStringAsFixed(1),
      padding.left.round(),
      padding.top.round(),
      padding.right.round(),
      padding.bottom.round(),
      preferences.headerPadding.left.round(),
      preferences.headerPadding.top.round(),
      preferences.headerPadding.right.round(),
      preferences.headerPadding.bottom.round(),
      preferences.footerPadding.left.round(),
      preferences.footerPadding.top.round(),
      preferences.footerPadding.right.round(),
      preferences.footerPadding.bottom.round(),
      preferences.tipLayout.headerMode.name,
      preferences.tipLayout.footerMode.name,
      preferences.tipLayout.headerLeft.name,
      preferences.tipLayout.headerCenter.name,
      preferences.tipLayout.headerRight.name,
      preferences.tipLayout.footerLeft.name,
      preferences.tipLayout.footerCenter.name,
      preferences.tipLayout.footerRight.name,
      preferences.showHeaderLine,
      preferences.showFooterLine,
      collectionTitle.trim(),
    ].join('|');
  }

  Set<int> _expandRetainedMemoIndexes(
    Set<int> anchorIndexes, {
    required int itemCount,
  }) {
    final expanded = <int>{};
    for (final index in anchorIndexes) {
      if (index < 0 || index >= itemCount) {
        continue;
      }
      expanded.add(index);
      if (index > 0) {
        expanded.add(index - 1);
      }
      if (index + 1 < itemCount) {
        expanded.add(index + 1);
      }
    }
    return expanded;
  }

  int _resolveChapterPageCount({
    required LocalMemo memo,
    required int memoIndex,
    required Size viewportSize,
    required CollectionReaderPreferences preferences,
    required String collectionTitle,
    required bool cacheResult,
  }) {
    final cacheKey = _buildCacheKey(
      memo: memo,
      viewportSize: viewportSize,
      preferences: preferences,
      collectionTitle: collectionTitle,
    );
    final cachedCount = _chapterPageCountCache[cacheKey];
    if (cachedCount != null) {
      return cachedCount;
    }
    final layout = _layoutChapter(
      memo: memo,
      memoIndex: memoIndex,
      viewportSize: viewportSize,
      preferences: preferences,
      collectionTitle: collectionTitle,
      cacheResult: cacheResult,
    );
    return layout.pages.length;
  }

  int _measureFittingTextCount(
    String text, {
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (text.isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return 0;
    }
    final fullHeight = _measureTextHeight(
      text,
      style: style,
      maxWidth: maxWidth,
    );
    if (fullHeight <= maxHeight) {
      return text.length;
    }
    var low = 1;
    var high = text.length;
    var best = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final candidate = text.substring(0, mid);
      final height = _measureTextHeight(
        candidate,
        style: style,
        maxWidth: maxWidth,
      );
      if (height <= maxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  double _measureTextHeight(
    String text, {
    required TextStyle style,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height + 8;
  }

  double _markdownBlockSpacing(
    CollectionReaderPreferences preferences,
    ReaderTextRole role,
  ) {
    return switch (role) {
      ReaderTextRole.body => preferences.paragraphSpacing,
      ReaderTextRole.listItem => math.max(4, preferences.paragraphSpacing * 0.75),
      ReaderTextRole.heading => 10 + preferences.paragraphSpacing * 0.4,
      ReaderTextRole.quote => 10 + preferences.paragraphSpacing * 0.35,
      ReaderTextRole.code => 10,
      ReaderTextRole.tableRow => 4,
    };
  }

  double _markdownBlockChromePadding(ReaderTextRole role) {
    return switch (role) {
      ReaderTextRole.quote => 20,
      ReaderTextRole.code => 20,
      ReaderTextRole.tableRow => 16,
      ReaderTextRole.body ||
      ReaderTextRole.heading ||
      ReaderTextRole.listItem => 0,
    };
  }

  String _applyParagraphIndent(
    String text, {
    required ReaderTextRole role,
    required CollectionReaderPreferences preferences,
  }) {
    if (role != ReaderTextRole.body || preferences.paragraphIndentChars <= 0) {
      return text;
    }
    if (text.trim().isEmpty) {
      return text;
    }
    return '${'　' * preferences.paragraphIndentChars}$text';
  }

  FontWeight _resolveReaderFontWeight(
    CollectionReaderFontWeightMode mode,
  ) {
    return switch (mode) {
      CollectionReaderFontWeightMode.normal => FontWeight.w400,
      CollectionReaderFontWeightMode.medium => FontWeight.w500,
      CollectionReaderFontWeightMode.bold => FontWeight.w700,
    };
  }

  FontWeight _resolveHeadingFontWeight(
    CollectionReaderFontWeightMode mode,
  ) {
    return switch (mode) {
      CollectionReaderFontWeightMode.normal => FontWeight.w700,
      CollectionReaderFontWeightMode.medium => FontWeight.w700,
      CollectionReaderFontWeightMode.bold => FontWeight.w800,
    };
  }

  double _estimateTipReservedHeight({
    required EdgeInsets padding,
    required double textScale,
    required bool showDivider,
  }) {
    final textHeight = (12 * textScale * 1.35).clamp(16, 26).toDouble();
    return textHeight + padding.vertical + (showDivider ? 1 : 0) + 6;
  }

  double _estimateTitleHeight({
    required String title,
    required String subtitle,
    required CollectionReaderPreferences preferences,
    required double maxWidth,
  }) {
    final titleStyle = TextStyle(
      fontFamily: preferences.readerFontFamily,
      fontSize: 20 * preferences.textScale * preferences.titleScale,
      height: 1.28,
      fontWeight: _resolveHeadingFontWeight(preferences.fontWeightMode),
      letterSpacing: preferences.letterSpacing,
    );
    final subtitleStyle = TextStyle(
      fontFamily: preferences.readerFontFamily,
      fontSize: 13 * preferences.textScale,
      height: 1.35,
      fontWeight: _resolveReaderFontWeight(preferences.fontWeightMode),
      letterSpacing: preferences.letterSpacing,
    );
    final titleHeight = _measureTextHeight(
      title,
      style: titleStyle,
      maxWidth: maxWidth,
    );
    final subtitleHeight = subtitle.trim().isEmpty
        ? 0
        : _measureTextHeight(
            subtitle,
            style: subtitleStyle,
            maxWidth: maxWidth,
          );
    return titleHeight +
        subtitleHeight +
        preferences.titleTopSpacing +
        preferences.titleBottomSpacing +
        (subtitle.trim().isEmpty ? 0 : 4) +
        8;
  }

  int _findSoftBreak(String source, int start, int preferredEnd) {
    if (preferredEnd >= source.length) {
      return source.length;
    }
    for (var index = preferredEnd; index > start; index -= 1) {
      final char = source[index - 1];
      if (_isSoftBreakCharacter(char)) {
        return index;
      }
    }
    return preferredEnd;
  }

  int _skipLeadingWhitespace(String source, int index) {
    var cursor = index;
    while (cursor < source.length) {
      final char = source[cursor];
      if (char.trim().isNotEmpty) {
        break;
      }
      cursor += 1;
    }
    return cursor;
  }

  bool _isSoftBreakCharacter(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == ',' ||
        char == '.' ||
        char == ';' ||
        char == '\u3001' ||
        char == '\u3002' ||
        char == '\uFF0C' ||
        char == '\uFF01' ||
        char == '\uFF1B' ||
        char == '\uFF1F';
  }

  double _estimateMediaHeight(
    Attachment? attachment, {
    required double viewportHeight,
    required bool isVideo,
  }) {
    final fraction = isVideo ? 0.45 : 0.6;
    final maxHeight = viewportHeight * fraction;
    if (attachment == null) {
      return maxHeight.clamp(120, viewportHeight).toDouble();
    }
    final width = attachment.width?.toDouble();
    final height = attachment.height?.toDouble();
    if (width != null && height != null && width > 0 && height > 0) {
      final ratio = height / width;
      final estimated = 240 * ratio;
      return estimated.clamp(120, maxHeight).toDouble();
    }
    return maxHeight.clamp(120, viewportHeight).toDouble();
  }

  int? _findMatchingAttachmentIndex({
    required String sourceUrl,
    required List<Attachment> attachments,
    required Set<int> consumedIndexes,
  }) {
    final normalizedSource = normalizeMarkdownImageSrc(sourceUrl).trim();
    if (normalizedSource.isEmpty) {
      return null;
    }
    final lowerSource = normalizedSource.toLowerCase();
    for (var index = 0; index < attachments.length; index += 1) {
      if (consumedIndexes.contains(index)) {
        continue;
      }
      final attachment = attachments[index];
      final external = normalizeMarkdownImageSrc(
        attachment.externalLink,
      ).trim();
      if (external.isNotEmpty && external == normalizedSource) {
        return index;
      }
      final filename = attachment.filename.trim().toLowerCase();
      if (filename.isNotEmpty && lowerSource.contains(filename)) {
        return index;
      }
      final uid = attachment.uid.trim().toLowerCase();
      if (uid.isNotEmpty && lowerSource.contains(uid)) {
        return index;
      }
    }
    return null;
  }

  String _buildInlineMediaLabel({
    required String sourceUrl,
    required String? preferredLabel,
    required String fallbackLabel,
  }) {
    final trimmedLabel = preferredLabel?.trim() ?? '';
    if (trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }
    final uri = Uri.tryParse(sourceUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last.trim()
        : '';
    if (lastSegment.isNotEmpty) {
      return lastSegment;
    }
    final normalized = normalizeMarkdownImageSrc(sourceUrl).trim();
    if (normalized.isEmpty) {
      return fallbackLabel;
    }
    return normalized;
  }
}
