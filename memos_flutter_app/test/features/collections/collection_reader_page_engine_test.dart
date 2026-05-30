import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_layout_policy.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_page_engine.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_page_models.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_utils.dart';

void main() {
  LocalMemo buildMemo({
    required String uid,
    required String content,
    List<Attachment> attachments = const <Attachment>[],
  }) {
    final created = DateTime(2026, 4, 12, 9, 30);
    return LocalMemo(
      uid: uid,
      content: content,
      contentFingerprint: 'fingerprint-$uid-${content.length}',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: created,
      displayTime: created,
      updateTime: created.add(const Duration(hours: 1)),
      tags: const <String>[],
      attachments: attachments,
      relationCount: 0,
      location: null,
      syncState: SyncState.synced,
      lastError: null,
    );
  }

  test('short memo occupies a single page', () {
    final engine = CollectionReaderPageEngine();
    final memo = buildMemo(uid: 'memo-short', content: 'Short content only.');

    final layout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(390, 844),
      preferences: CollectionReaderPreferences.defaults,
    );

    expect(layout.pages, hasLength(1));
    expect(layout.pages.single.memoUid, memo.uid);
  });

  test('long memo splits into multiple pages in one chapter', () {
    final engine = CollectionReaderPageEngine();
    final content = List<String>.filled(
      180,
      'This is a long paragraph for reader pagination testing.',
    ).join(' ');
    final memo = buildMemo(uid: 'memo-long', content: content);

    final layout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(320, 420),
      preferences: CollectionReaderPreferences.defaults,
    );

    expect(layout.pages.length, greaterThan(1));
    expect(layout.pages.every((page) => page.memoUid == memo.uid), isTrue);
  });

  test('desktop readable viewport width drives page count', () {
    final engine = CollectionReaderPageEngine();
    final content = List<String>.filled(
      260,
      'Readable width controls paged measurement.',
    ).join(' ');
    final memo = buildMemo(uid: 'memo-readable-width', content: content);
    final standardLayout = resolveCollectionReaderLayout(
      platform: TargetPlatform.windows,
      viewportSize: const Size(1200, 700),
      contentWidthMode: CollectionReaderContentWidthMode.standard,
    );
    final fullLayout = resolveCollectionReaderLayout(
      platform: TargetPlatform.windows,
      viewportSize: const Size(1200, 700),
      contentWidthMode: CollectionReaderContentWidthMode.full,
    );
    final preferences = CollectionReaderPreferences.defaults.copyWith(
      pagePadding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    );

    final standardPages = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: standardLayout.readableViewportSize,
      preferences: preferences.copyWith(
        displayConfig: preferences.displayConfig.copyWith(
          contentWidthMode: CollectionReaderContentWidthMode.standard,
        ),
      ),
    );
    final fullPages = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: fullLayout.readableViewportSize,
      preferences: preferences.copyWith(
        displayConfig: preferences.displayConfig.copyWith(
          contentWidthMode: CollectionReaderContentWidthMode.full,
        ),
      ),
    );

    expect(standardLayout.readableViewportSize.width, 820);
    expect(fullLayout.readableViewportSize.width, 1200);
    expect(standardPages.pages.length, greaterThan(fullPages.pages.length));
  });

  test('content width mode participates in page cache key', () {
    final engine = CollectionReaderPageEngine();
    final memo = buildMemo(
      uid: 'memo-width-cache',
      content: List<String>.filled(80, 'cache segment').join(' '),
    );
    final standardPreferences = CollectionReaderPreferences.defaults.copyWith(
      displayConfig: CollectionReaderDisplayConfig.defaults.copyWith(
        contentWidthMode: CollectionReaderContentWidthMode.standard,
      ),
    );
    final widePreferences = CollectionReaderPreferences.defaults.copyWith(
      displayConfig: CollectionReaderDisplayConfig.defaults.copyWith(
        contentWidthMode: CollectionReaderContentWidthMode.wide,
      ),
    );

    final standardLayout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(820, 700),
      preferences: standardPreferences,
    );
    final wideLayout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(820, 700),
      preferences: widePreferences,
    );

    expect(standardLayout.cacheKey, isNot(wideLayout.cacheKey));
  });

  test('offset resolves to later page for long chapter', () {
    final engine = CollectionReaderPageEngine();
    final content = List<String>.generate(
      220,
      (index) => 'chapter-segment-$index alpha beta gamma',
    ).join(' ');
    final memo = buildMemo(uid: 'memo-offset', content: content);

    final layout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(320, 420),
      preferences: CollectionReaderPreferences.defaults,
    );

    final pageIndex = engine.resolveChapterPageIndexForOffset(layout, 1200);

    expect(layout.pages.length, greaterThan(1));
    expect(pageIndex, inInclusiveRange(1, layout.pages.length - 1));
  });

  test(
    'chapter document keeps multiple markdown blocks with monotonic offsets',
    () {
      final engine = CollectionReaderPageEngine();
      final memo = buildMemo(
        uid: 'memo-blocks',
        content: 'First paragraph.\n\nSecond paragraph.\n\nThird paragraph.',
      );

      final layout = engine.layoutChapter(
        memo: memo,
        memoIndex: 0,
        viewportSize: const Size(360, 640),
        preferences: CollectionReaderPreferences.defaults,
      );

      final textBlocks = layout.document.blocks
          .where((block) => block.kind == ReaderBlockKind.markdownText)
          .toList(growable: false);

      expect(textBlocks.length, 3);
      expect(textBlocks[0].charStart, lessThan(textBlocks[1].charStart!));
      expect(textBlocks[1].charStart, lessThan(textBlocks[2].charStart!));
      expect(
        textBlocks[0].charEnd,
        lessThanOrEqualTo(textBlocks[1].charStart!),
      );
      expect(layout.document.contentText, contains('First paragraph.'));
      expect(layout.document.contentText, contains('Second paragraph.'));
      expect(layout.document.contentText, contains('Third paragraph.'));
    },
  );

  test(
    'inline markdown image uses matching attachment without duplicate tail block',
    () {
      final engine = CollectionReaderPageEngine();
      final attachment = Attachment(
        name: 'attachments/demo',
        filename: 'demo.png',
        type: 'image/png',
        size: 1024,
        externalLink: 'https://example.com/demo.png',
        width: 640,
        height: 360,
      );
      final memo = buildMemo(
        uid: 'memo-inline-image',
        content:
            'Intro text.\n\n![diagram](https://example.com/demo.png)\n\nMore text.',
        attachments: <Attachment>[attachment],
      );

      final layout = engine.layoutChapter(
        memo: memo,
        memoIndex: 0,
        viewportSize: const Size(360, 640),
        preferences: CollectionReaderPreferences.defaults,
      );

      final imageBlocks = layout.document.blocks
          .where((block) => block.kind == ReaderBlockKind.image)
          .toList(growable: false);

      expect(imageBlocks, hasLength(1));
      expect(imageBlocks.single.attachments, hasLength(1));
      expect(
        imageBlocks.single.attachments.single.externalLink,
        attachment.externalLink,
      );
    },
  );

  test(
    'inline html video uses matching attachment without duplicate tail block',
    () {
      final engine = CollectionReaderPageEngine();
      final attachment = Attachment(
        name: 'attachments/video-demo',
        filename: 'demo.mp4',
        type: 'video/mp4',
        size: 4096,
        externalLink: 'https://example.com/demo.mp4',
        width: 1280,
        height: 720,
      );
      final memo = buildMemo(
        uid: 'memo-inline-video',
        content:
            'Intro text.\n\n<video controls title="demo clip"><source src="https://example.com/demo.mp4" type="video/mp4"></video>\n\nMore text.',
        attachments: <Attachment>[attachment],
      );

      final layout = engine.layoutChapter(
        memo: memo,
        memoIndex: 0,
        viewportSize: const Size(360, 640),
        preferences: CollectionReaderPreferences.defaults,
      );

      final videoBlocks = layout.document.blocks
          .where((block) => block.kind == ReaderBlockKind.video)
          .toList(growable: false);

      expect(videoBlocks, hasLength(1));
      expect(videoBlocks.single.text, 'demo clip');
      expect(videoBlocks.single.attachments, hasLength(1));
      expect(
        videoBlocks.single.attachments.single.externalLink,
        attachment.externalLink,
      );
    },
  );

  test(
    'buildPageMap retains layout cache only for current and adjacent chapters',
    () {
      final engine = CollectionReaderPageEngine();
      final memos = List<LocalMemo>.generate(
        5,
        (index) =>
            buildMemo(uid: 'memo-$index', content: 'Chapter $index ' * 24),
        growable: false,
      );

      final pageMap = engine.buildPageMap(
        items: memos,
        viewportSize: const Size(360, 640),
        preferences: CollectionReaderPreferences.defaults,
        retainMemoIndexes: <int>{2},
      );

      expect(pageMap.totalPages, greaterThanOrEqualTo(5));
      expect(engine.debugCachedMemoUids, <String>{
        'memo-1',
        'memo-2',
        'memo-3',
      });
      expect(engine.debugCountCachedMemoUids, <String>{
        'memo-0',
        'memo-1',
        'memo-2',
        'memo-3',
        'memo-4',
      });
    },
  );

  test('page map resolves global index to chapter page target', () {
    final engine = CollectionReaderPageEngine();
    final memos = <LocalMemo>[
      buildMemo(uid: 'memo-a', content: 'Short first chapter.'),
      buildMemo(
        uid: 'memo-b',
        content: List<String>.filled(180, 'long chapter segment').join(' '),
      ),
    ];

    final pageMap = engine.buildPageMap(
      items: memos,
      viewportSize: const Size(320, 420),
      preferences: CollectionReaderPreferences.defaults,
      retainMemoIndexes: <int>{1},
    );

    final secondChapterStart = pageMap.chapters[1].globalPageStartIndex;
    final target = engine.resolvePageTargetForGlobalIndex(
      pageMap: pageMap,
      globalPageIndex: secondChapterStart,
    );

    expect(target, isNotNull);
    expect(target!.memoIndex, 1);
    expect(target.chapterPageIndex, 0);
  });

  test('global page boundaries never mix adjacent chapters', () {
    final engine = CollectionReaderPageEngine();
    final memos = <LocalMemo>[
      buildMemo(
        uid: 'memo-a',
        content:
            '${List<String>.filled(80, 'alpha section').join(' ')}\n\n![diagram](https://example.com/demo.png)\n\n${List<String>.filled(80, 'omega section').join(' ')}',
        attachments: const <Attachment>[
          Attachment(
            name: 'attachments/demo',
            filename: 'demo.png',
            type: 'image/png',
            size: 1024,
            externalLink: 'https://example.com/demo.png',
            width: 960,
            height: 640,
          ),
        ],
      ),
      buildMemo(uid: 'memo-b', content: 'Short second chapter.'),
    ];

    final pageMap = engine.buildPageMap(
      items: memos,
      viewportSize: const Size(320, 420),
      preferences: CollectionReaderPreferences.defaults,
      retainMemoIndexes: <int>{0, 1},
    );

    final secondChapterStart = pageMap.chapters[1].globalPageStartIndex;
    expect(secondChapterStart, greaterThan(0));

    for (
      var globalIndex = 0;
      globalIndex < secondChapterStart;
      globalIndex += 1
    ) {
      final target = engine.resolvePageTargetForGlobalIndex(
        pageMap: pageMap,
        globalPageIndex: globalIndex,
      );
      expect(target, isNotNull);
      expect(target!.memoIndex, 0);
    }

    final secondTarget = engine.resolvePageTargetForGlobalIndex(
      pageMap: pageMap,
      globalPageIndex: secondChapterStart,
    );
    expect(secondTarget, isNotNull);
    expect(secondTarget!.memoIndex, 1);
    expect(secondTarget.chapterPageIndex, 0);
  });

  test('search match offset resolves to the containing paged chapter page', () {
    final engine = CollectionReaderPageEngine();
    final memo = buildMemo(
      uid: 'memo-search-page',
      content:
          'Intro paragraph.\n\n${List<String>.filled(120, 'filler text').join(' ')}\n\nneedle phrase is here near the end.',
    );

    final results = buildCollectionReaderSearchResults(
      items: <LocalMemo>[memo],
      query: 'needle phrase',
    );
    final layout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(320, 420),
      preferences: CollectionReaderPreferences.defaults,
    );

    expect(results, hasLength(1));
    expect(layout.pages.length, greaterThan(1));

    final targetPageIndex = engine.resolveChapterPageIndexForOffset(
      layout,
      results.single.firstMatchOffset,
    );
    final targetPage = layout.pages[targetPageIndex];
    final targetPageText = targetPage.blocks
        .map((block) => block.text ?? '')
        .join('\n');

    expect(targetPageIndex, inInclusiveRange(1, layout.pages.length - 1));
    expect(targetPageText, contains('needle phrase'));
  });

  test(
    'restored page index prefers saved match offset over stale stored page index',
    () {
      final engine = CollectionReaderPageEngine();
      final memo = buildMemo(
        uid: 'memo-restore-match',
        content:
            '${List<String>.filled(48, 'preface text').join(' ')}\n\nneedle phrase appears here in the middle.\n\n${List<String>.filled(96, 'trailing text').join(' ')}',
      );

      final results = buildCollectionReaderSearchResults(
        items: <LocalMemo>[memo],
        query: 'needle phrase',
      );
      final layout = engine.layoutChapter(
        memo: memo,
        memoIndex: 0,
        viewportSize: const Size(280, 320),
        preferences: CollectionReaderPreferences.defaults.copyWith(
          textScale: 1.8,
          lineSpacing: 2.2,
          paragraphSpacing: 20,
          pagePadding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
        ),
      );

      expect(results, hasLength(1));

      final restoredPageIndex = engine.resolveRestoredChapterPageIndex(
        chapter: layout,
        storedChapterPageIndex: 0,
        matchCharOffset: results.single.firstMatchOffset,
      );
      final restoredPageText = layout.pages[restoredPageIndex].blocks
          .map((block) => block.text ?? '')
          .join('\n');

      expect(restoredPageIndex, greaterThan(0));
      expect(restoredPageText, contains('needle phrase'));
    },
  );

  test('restored page index clamps stale page when no match offset exists', () {
    final engine = CollectionReaderPageEngine();
    final memo = buildMemo(
      uid: 'memo-restore-clamp',
      content: List<String>.filled(64, 'pagination segment').join(' '),
    );

    final layout = engine.layoutChapter(
      memo: memo,
      memoIndex: 0,
      viewportSize: const Size(320, 420),
      preferences: CollectionReaderPreferences.defaults,
    );

    final restoredPageIndex = engine.resolveRestoredChapterPageIndex(
      chapter: layout,
      storedChapterPageIndex: 999,
    );

    expect(restoredPageIndex, layout.pages.length - 1);
  });

  test(
    'chapter title data uses collection title while body keeps memo text',
    () {
      final engine = CollectionReaderPageEngine();
      final memo = buildMemo(uid: 'memo-meta', content: '#sss 111');

      final layout = engine.layoutChapter(
        memo: memo,
        memoIndex: 0,
        viewportSize: const Size(320, 420),
        preferences: CollectionReaderPreferences.defaults,
        collectionTitle: 'My Shelf',
      );

      expect(layout.document.blocks.first.kind, ReaderBlockKind.metaHeader);
      expect(layout.document.blocks.first.text, contains('2026-04-12'));
      expect(layout.pages.first.title, isNotNull);
      expect(layout.pages.first.title!.title, 'My Shelf');
      expect(layout.pages.first.title!.subtitle, '#sss 111');

      final bodyBlocks = layout.document.blocks
          .where((block) => block.kind == ReaderBlockKind.markdownText)
          .toList(growable: false);
      expect(bodyBlocks, isNotEmpty);
      expect(bodyBlocks.first.text, '#sss 111');
    },
  );
}
