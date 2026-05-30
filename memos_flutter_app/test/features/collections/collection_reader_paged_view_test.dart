import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_animation_delegate.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_page_models.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_paged_view.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const page = ReaderPage(
    memoUid: 'memo-1',
    memoIndex: 0,
    chapterPageIndex: 0,
    contentCharStart: 0,
    contentCharEnd: 11,
    blocks: <ReaderPageBlock>[
      ReaderPageBlock(
        kind: ReaderBlockKind.markdownText,
        id: 'block-1',
        text: 'Hello reader',
        charStart: 0,
        charEnd: 11,
      ),
    ],
    isFirstPage: true,
    isLastPage: true,
    reservedInsets: ReaderPageReservedInsets.zero,
    headerTip: null,
    footerTip: null,
    title: null,
  );

  testWidgets('paged view builds without ticker provider errors', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: CollectionReaderPagedView(
              currentPage: page,
              previousPage: null,
              nextPage: null,
              canGoPrevious: false,
              canGoNext: false,
              preferences: CollectionReaderPreferences.defaults,
              turnDirection: ReaderPageTurnDirection.none,
              highlightQuery: null,
              highlightMemoUid: null,
              collectionTitle: 'Collection A',
              currentGlobalPageIndex: 0,
              totalPages: 1,
              viewportSize: Size(800, 600),
              previewImageOnTap: true,
              onShowSearch: _noop,
              onShowToc: _noop,
              onPrevChapter: _noop,
              onNextChapter: _noop,
              onCenterTap: _noop,
              onPrevPage: _noop,
              onNextPage: _noop,
              onUserInteraction: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Hello reader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paged view interactions stay inside visible page bounds', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    var centerTapCount = 0;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                height: 600,
                child: CollectionReaderPagedView(
                  currentPage: page,
                  previousPage: null,
                  nextPage: null,
                  canGoPrevious: false,
                  canGoNext: false,
                  preferences: CollectionReaderPreferences.defaults,
                  turnDirection: ReaderPageTurnDirection.none,
                  highlightQuery: null,
                  highlightMemoUid: null,
                  collectionTitle: 'Collection A',
                  currentGlobalPageIndex: 0,
                  totalPages: 1,
                  viewportSize: const Size(420, 600),
                  previewImageOnTap: true,
                  onShowSearch: _noop,
                  onShowToc: _noop,
                  onPrevChapter: _noop,
                  onNextChapter: _noop,
                  onCenterTap: () => centerTapCount += 1,
                  onPrevPage: _noop,
                  onNextPage: _noop,
                  onUserInteraction: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(CollectionReaderPagedView)),
      const Size(420, 600),
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.tapAt(const Offset(60, 300));
    await tester.pump();

    expect(centerTapCount, 1);
  });

  testWidgets('tip bars stay inside centered visible page width', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const tipPage = ReaderPage(
      memoUid: 'memo-tip',
      memoIndex: 0,
      chapterPageIndex: 0,
      contentCharStart: 0,
      contentCharEnd: 11,
      blocks: <ReaderPageBlock>[
        ReaderPageBlock(
          kind: ReaderBlockKind.markdownText,
          id: 'block-tip',
          text: 'Hello reader',
          charStart: 0,
          charEnd: 11,
        ),
      ],
      isFirstPage: true,
      isLastPage: true,
      reservedInsets: ReaderPageReservedInsets.zero,
      headerTip: ReaderTipRenderData(
        mode: CollectionReaderTipDisplayMode.reserved,
        leftSlot: CollectionReaderTipSlot.collectionTitle,
        centerSlot: CollectionReaderTipSlot.none,
        rightSlot: CollectionReaderTipSlot.pageAndTotal,
      ),
      footerTip: ReaderTipRenderData(
        mode: CollectionReaderTipDisplayMode.reserved,
        leftSlot: CollectionReaderTipSlot.chapterTitle,
        centerSlot: CollectionReaderTipSlot.none,
        rightSlot: CollectionReaderTipSlot.pageAndTotal,
      ),
      title: ReaderTitleRenderData(
        title: 'Chapter One',
        subtitle: '',
        mode: CollectionReaderTitleMode.hidden,
      ),
    );
    final preferences = CollectionReaderPreferences.defaults.copyWith(
      mode: CollectionReaderMode.paged,
      pagePadding: EdgeInsets.zero,
      headerPadding: EdgeInsets.zero,
      footerPadding: EdgeInsets.zero,
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 820,
                height: 600,
                child: CollectionReaderPagedView(
                  currentPage: tipPage,
                  previousPage: null,
                  nextPage: null,
                  canGoPrevious: false,
                  canGoNext: false,
                  preferences: preferences,
                  turnDirection: ReaderPageTurnDirection.none,
                  highlightQuery: null,
                  highlightMemoUid: null,
                  collectionTitle: 'Collection A',
                  currentGlobalPageIndex: 0,
                  totalPages: 1,
                  viewportSize: const Size(820, 600),
                  previewImageOnTap: true,
                  onShowSearch: _noop,
                  onShowToc: _noop,
                  onPrevChapter: _noop,
                  onNextChapter: _noop,
                  onCenterTap: _noop,
                  onPrevPage: _noop,
                  onNextPage: _noop,
                  onUserInteraction: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pageRect = tester.getRect(find.byType(CollectionReaderPagedView));
    expect(pageRect.left, closeTo((1200 - 820) / 2, 1));
    expect(tester.getTopLeft(find.text('Collection A')).dx, pageRect.left);
    expect(
      tester.getTopRight(find.text('1/1').first).dx,
      lessThanOrEqualTo(pageRect.right),
    );
    expect(tester.getTopLeft(find.text('Chapter One')).dx, pageRect.left);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
