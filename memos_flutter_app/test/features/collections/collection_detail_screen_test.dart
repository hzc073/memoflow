import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/collection_article_flow.dart';
import 'package:memos_flutter_app/data/models/collection_readable_item.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/memo_collection.dart';
import 'package:memos_flutter_app/data/models/rss_article.dart';
import 'package:memos_flutter_app/data/models/rss_feed.dart';
import 'package:memos_flutter_app/data/repositories/rss_repository.dart';
import 'package:memos_flutter_app/features/collections/collection_detail_screen.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_layout_policy.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_overlay.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_page_engine.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_paged_view.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_shell.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_utils.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/collections/collection_reader_progress_provider.dart';
import 'package:memos_flutter_app/state/collections/collection_article_flow_progress_provider.dart';
import 'package:memos_flutter_app/state/collections/collection_rss_providers.dart';
import 'package:memos_flutter_app/state/collections/collections_provider.dart';
import 'package:memos_flutter_app/state/memos/memo_mutation_service.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('detail screen opens reader directly and supports search', (
    tester,
  ) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-1',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
      _memo(
        uid: 'memo-2',
        content: 'Beta reading highlight',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 12, 9),
        attachments: const <Attachment>[
          Attachment(
            name: 'attachments/photo-1',
            filename: 'photo.jpg',
            type: 'image/jpeg',
            size: 12,
            externalLink: '',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: memos),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(find.text('Reading shelf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pumpAndSettle();

    expect(find.textContaining('Beta reading highlight'), findsWidgets);

    await tester.tap(
      find.textContaining('Beta reading highlight').hitTestable().first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'reader restore repositions to saved search match under changed paged layout',
    (tester) async {
      final collection = MemoCollection.createSmart(
        id: 'collection-restore',
        title: 'Reading shelf',
        description: 'Collected reading notes',
        rules: const CollectionRuleSet(
          tagPaths: <String>['reading'],
          tagMatchMode: CollectionTagMatchMode.any,
          includeDescendants: true,
          visibility: CollectionVisibilityScope.all,
          dateRule: CollectionDateRule.defaults,
          attachmentRule: CollectionAttachmentRule.any,
          pinnedOnly: false,
        ),
      );
      final memo = _memo(
        uid: 'memo-restore',
        content:
            '${List<String>.filled(240, 'preface reading text').join(' ')}\n\nneedle phrase appears here in the middle of the chapter.\n\n${List<String>.filled(320, 'trailing reading text').join(' ')}',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 14, 8),
      );
      final query = 'needle phrase';
      final results = buildCollectionReaderSearchResults(
        items: <LocalMemo>[memo],
        query: query,
      );
      expect(results, hasLength(1));

      final progressRepository = _MemoryCollectionReaderProgressRepository()
        ..seed(
          CollectionReaderProgress(
            collectionId: collection.id,
            readerMode: CollectionReaderMode.paged,
            pageAnimation: CollectionReaderPageAnimation.simulation,
            currentMemoUid: memo.uid,
            currentMemoIndex: 0,
            currentChapterPageIndex: 0,
            listScrollOffset: 0,
            currentMatchCharOffset: results.single.firstMatchOffset,
            updatedAt: DateTime(2024, 2, 14, 8, 30),
          ),
        );
      final readerPreferences = CollectionReaderPreferences.defaults.copyWith(
        mode: CollectionReaderMode.paged,
        textScale: 1.45,
        lineSpacing: 1.9,
        paragraphSpacing: 12,
        pagePadding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 1600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const viewportSize = Size(1000, 1600);
      final pageEngine = CollectionReaderPageEngine();
      final expectedLayout = pageEngine.layoutChapter(
        memo: memo,
        memoIndex: 0,
        viewportSize: viewportSize,
        preferences: readerPreferences,
        collectionTitle: collection.title,
      );
      final expectedPageIndex = pageEngine.resolveChapterPageIndexForOffset(
        expectedLayout,
        results.single.firstMatchOffset,
      );
      expect(expectedPageIndex, greaterThan(0));

      await tester.pumpWidget(
        _buildTestApp(
          collection: collection,
          memos: <LocalMemo>[memo],
          progressRepository: progressRepository,
          devicePreferences: DevicePreferences.defaults.copyWith(
            collectionReaderPreferences: readerPreferences,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _findRichTextContaining('needle phrase appears here'),
        findsOneWidget,
      );
    },
  );

  testWidgets('detail menu exposes placeholder reader actions', (tester) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-2',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: memos),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Edit collection'), findsOneWidget);
    expect(find.text('Manage collection items'), findsNothing);
    expect(find.text('Current item actions'), findsOneWidget);
  });

  testWidgets('reader saves progress when closed before debounce fires', (
    tester,
  ) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-progress',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
      _memo(
        uid: 'memo-2',
        content: 'Beta reading highlight',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 12, 9),
      ),
    ];
    final progressRepository = _MemoryCollectionReaderProgressRepository();

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: memos,
        progressRepository: progressRepository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(progressRepository.saveCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(progressRepository.savedProgress, isNotNull);
    expect(progressRepository.saveCalls, 1);
    expect(
      <String>{
        'memo-1',
        'memo-2',
      }.contains(progressRepository.savedProgress!.currentMemoUid),
      isTrue,
    );
    expect(
      progressRepository.savedProgress!.currentMemoIndex,
      inInclusiveRange(0, 1),
    );
  });

  testWidgets('reader reapplies immersive environment after resume', (
    tester,
  ) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-resume',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];
    final keepAwakeCalls = <bool>[];
    CollectionReaderShell.debugSetKeepAwakeOverride = (enabled) async {
      keepAwakeCalls.add(enabled);
    };
    CollectionReaderShell.debugSetSystemUiModeOverride = (_) async {};
    CollectionReaderShell.debugSetSystemUiOverlayStyleOverride = (_) {};
    addTearDown(() {
      CollectionReaderShell.debugSetKeepAwakeOverride = null;
      CollectionReaderShell.debugSetSystemUiModeOverride = null;
      CollectionReaderShell.debugSetSystemUiOverlayStyleOverride = null;
    });

    final readerPreferences = DevicePreferences.defaults.copyWith(
      collectionReaderPreferences: DevicePreferences
          .defaults
          .collectionReaderPreferences
          .copyWith(
            displayConfig: DevicePreferences
                .defaults
                .collectionReaderPreferences
                .displayConfig
                .copyWith(
                  keepScreenAwakeInReader: true,
                  hideStatusBar: true,
                  hideNavigationBar: true,
                ),
          ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: memos,
        devicePreferences: readerPreferences,
      ),
    );
    await tester.pumpAndSettle();

    final initialEnableCount = keepAwakeCalls.where((value) => value).length;
    expect(initialEnableCount, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(
      keepAwakeCalls.where((value) => value).length,
      greaterThan(initialEnableCount),
    );
  });

  testWidgets('macOS reader content avoids native traffic lights', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final collection = MemoCollection.createSmart(
      id: 'collection-macos-reader-chrome',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-macos-reader-chrome',
        content: 'Top line should stay readable under macOS controls.',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];
    final readerPreferences = DevicePreferences.defaults.copyWith(
      collectionReaderPreferences: DevicePreferences
          .defaults
          .collectionReaderPreferences
          .copyWith(pagePadding: EdgeInsets.zero),
    );

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: memos,
        devicePreferences: readerPreferences,
      ),
    );
    await tester.pumpAndSettle();

    final contentFinder = _findRichTextExactly(
      'Top line should stay readable under macOS controls.',
    );
    expect(contentFinder, findsOneWidget);
    expect(
      tester.getTopLeft(contentFinder).dy,
      greaterThanOrEqualTo(kMacosTitleBarHeight),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS paged reader tip bar avoids native traffic lights', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final collection = MemoCollection.createSmart(
      id: 'collection-macos-reader-tip',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-macos-reader-tip',
        content: 'Paged tip content avoids macOS controls.',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];
    final readerPreferences = DevicePreferences.defaults.copyWith(
      collectionReaderPreferences: DevicePreferences
          .defaults
          .collectionReaderPreferences
          .copyWith(
            mode: CollectionReaderMode.paged,
            pageAnimation: CollectionReaderPageAnimation.none,
            pagePadding: EdgeInsets.zero,
            titleMode: CollectionReaderTitleMode.hidden,
            headerPadding: EdgeInsets.zero,
            tipLayout: const CollectionReaderTipLayout(
              headerMode: CollectionReaderTipDisplayMode.reserved,
              footerMode: CollectionReaderTipDisplayMode.hidden,
              headerLeft: CollectionReaderTipSlot.collectionTitle,
              headerCenter: CollectionReaderTipSlot.none,
              headerRight: CollectionReaderTipSlot.pageAndTotal,
              footerLeft: CollectionReaderTipSlot.none,
              footerCenter: CollectionReaderTipSlot.none,
              footerRight: CollectionReaderTipSlot.none,
            ),
          ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: memos,
        devicePreferences: readerPreferences,
      ),
    );
    await tester.pumpAndSettle();

    final tipFinder = find.descendant(
      of: find.byType(CollectionReaderPagedView),
      matching: find.text('Reading shelf'),
    );
    expect(tipFinder, findsOneWidget);
    expect(
      tester.getTopLeft(tipFinder).dy,
      greaterThanOrEqualTo(kMacosTitleBarHeight),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop wide reader centers vertical content width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      final collection = MemoCollection.createSmart(
        id: 'collection-desktop-reader-width',
        title: 'Reading shelf',
        description: 'Collected reading notes',
        rules: const CollectionRuleSet(
          tagPaths: <String>['reading'],
          tagMatchMode: CollectionTagMatchMode.any,
          includeDescendants: true,
          visibility: CollectionVisibilityScope.all,
          dateRule: CollectionDateRule.defaults,
          attachmentRule: CollectionAttachmentRule.any,
          pinnedOnly: false,
        ),
      );
      final memos = <LocalMemo>[
        _memo(
          uid: 'memo-desktop-reader-width',
          content: 'Desktop centered readable width.',
          tags: const <String>['reading'],
          createTime: DateTime(2024, 2, 10, 8),
        ),
      ];
      final readerPreferences = DevicePreferences.defaults.copyWith(
        collectionReaderPreferences: DevicePreferences
            .defaults
            .collectionReaderPreferences
            .copyWith(pagePadding: EdgeInsets.zero),
      );

      await tester.pumpWidget(
        _buildTestApp(
          collection: collection,
          memos: memos,
          devicePreferences: readerPreferences,
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = _findBodyRichTextExactly(
        'Desktop centered readable width.',
      );
      expect(contentFinder, findsOneWidget);
      expect(
        tester.getTopLeft(contentFinder).dx,
        closeTo((1200 - kCollectionReaderStandardContentWidth) / 2, 1),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile reader keeps full available width behavior', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      final collection = MemoCollection.createSmart(
        id: 'collection-mobile-reader-width',
        title: 'Reading shelf',
        description: 'Collected reading notes',
        rules: const CollectionRuleSet(
          tagPaths: <String>['reading'],
          tagMatchMode: CollectionTagMatchMode.any,
          includeDescendants: true,
          visibility: CollectionVisibilityScope.all,
          dateRule: CollectionDateRule.defaults,
          attachmentRule: CollectionAttachmentRule.any,
          pinnedOnly: false,
        ),
      );
      final memos = <LocalMemo>[
        _memo(
          uid: 'memo-mobile-reader-width',
          content: 'Mobile keeps available width.',
          tags: const <String>['reading'],
          createTime: DateTime(2024, 2, 10, 8),
        ),
      ];
      final readerPreferences = DevicePreferences.defaults.copyWith(
        collectionReaderPreferences: DevicePreferences
            .defaults
            .collectionReaderPreferences
            .copyWith(
              pagePadding: EdgeInsets.zero,
              displayConfig: CollectionReaderDisplayConfig.defaults.copyWith(
                contentWidthMode: CollectionReaderContentWidthMode.narrow,
              ),
            ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          collection: collection,
          memos: memos,
          devicePreferences: readerPreferences,
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = _findBodyRichTextExactly(
        'Mobile keeps available width.',
      );
      expect(contentFinder, findsOneWidget);
      expect(tester.getTopLeft(contentFinder).dx, closeTo(0, 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('content width setting immediately relayouts reader modes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      late DevicePreferencesController preferencesController;
      final collection = MemoCollection.createSmart(
        id: 'collection-reader-width-live',
        title: 'Reading shelf',
        description: 'Collected reading notes',
        rules: const CollectionRuleSet(
          tagPaths: <String>['reading'],
          tagMatchMode: CollectionTagMatchMode.any,
          includeDescendants: true,
          visibility: CollectionVisibilityScope.all,
          dateRule: CollectionDateRule.defaults,
          attachmentRule: CollectionAttachmentRule.any,
          pinnedOnly: false,
        ),
      );
      final memos = <LocalMemo>[
        _memo(
          uid: 'memo-reader-width-live',
          content: 'Width mode relayout sentence.',
          tags: const <String>['reading'],
          createTime: DateTime(2024, 2, 10, 8),
        ),
      ];
      final readerPreferences = DevicePreferences.defaults.copyWith(
        collectionReaderPreferences: DevicePreferences
            .defaults
            .collectionReaderPreferences
            .copyWith(pagePadding: EdgeInsets.zero),
      );

      await tester.pumpWidget(
        _buildTestApp(
          collection: collection,
          memos: memos,
          devicePreferences: readerPreferences,
          onPreferencesControllerCreated: (controller) {
            preferencesController = controller;
          },
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = _findBodyRichTextExactly(
        'Width mode relayout sentence.',
      );
      expect(contentFinder, findsOneWidget);
      expect(
        tester.getTopLeft(contentFinder).dx,
        closeTo((1200 - kCollectionReaderStandardContentWidth) / 2, 1),
      );

      preferencesController.setCollectionReaderContentWidthMode(
        CollectionReaderContentWidthMode.full,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(contentFinder).dx, closeTo(0, 1));

      preferencesController.setCollectionReaderMode(CollectionReaderMode.paged);
      preferencesController.setCollectionReaderContentWidthMode(
        CollectionReaderContentWidthMode.standard,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(contentFinder).dx,
        closeTo((1200 - kCollectionReaderStandardContentWidth) / 2, 1),
      );

      preferencesController.setCollectionReaderContentWidthMode(
        CollectionReaderContentWidthMode.full,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(contentFinder).dx, closeTo(0, 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('empty collection shows simplified empty state', (tester) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-3',
      title: 'Quiet shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: const <LocalMemo>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quiet shelf'), findsOneWidget);
    expect(find.text('This collection has no items yet.'), findsOneWidget);
  });

  testWidgets('empty RSS collection shows source-focused action', (
    tester,
  ) async {
    final collection = MemoCollection.createRss(
      id: 'collection-rss-empty',
      title: 'RSS shelf',
    );

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: const <LocalMemo>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('RSS shelf'), findsOneWidget);
    expect(find.text('No RSS articles yet'), findsOneWidget);
    expect(find.text('Add RSS feed'), findsOneWidget);
  });

  testWidgets('RSS article surfaces visible save-as-memo shortcuts', (
    tester,
  ) async {
    final collection = MemoCollection.createRss(
      id: 'collection-rss',
      title: 'RSS shelf',
    );
    final article = _rssArticleWithFeed(
      articleId: 'article-1',
      title: 'Visible RSS Article',
      savedMemoUid: null,
    );

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: const <LocalMemo>[],
        rssArticles: <RssArticleWithFeed>[article],
        devicePreferences: DevicePreferences.defaults.copyWith(
          collectionReaderPreferences: DevicePreferences
              .defaults
              .collectionReaderPreferences
              .copyWith(mode: CollectionReaderMode.vertical),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visible RSS Article'), findsWidgets);
    expect(find.text('All feeds'), findsOneWidget);

    await tester.tap(find.text('Visible RSS Article').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_add_outlined), findsWidgets);
  });

  testWidgets('RSS article surfaces saved-as-memo state', (tester) async {
    final collection = MemoCollection.createRss(
      id: 'collection-rss-saved',
      title: 'RSS shelf',
    );

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: const <LocalMemo>[],
        rssArticles: <RssArticleWithFeed>[
          _rssArticleWithFeed(
            articleId: 'article-saved',
            title: 'Saved RSS Article',
            savedMemoUid: 'memo-saved',
          ),
        ],
        devicePreferences: DevicePreferences.defaults.copyWith(
          collectionReaderPreferences: DevicePreferences
              .defaults
              .collectionReaderPreferences
              .copyWith(mode: CollectionReaderMode.vertical),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved RSS Article').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_added_rounded), findsWidgets);
  });

  testWidgets(
    'RSS article flow opens unread article without auto-saving memo',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final collection = MemoCollection.createRss(
        id: 'collection-rss-flow-open',
        title: 'RSS shelf',
      );
      final actionsLog = _TestRssActionLog();

      await tester.pumpWidget(
        _buildTestApp(
          collection: collection,
          memos: const <LocalMemo>[],
          rssArticles: <RssArticleWithFeed>[
            _rssArticleWithFeed(
              articleId: 'article-open',
              title: 'Open Marks Read',
              savedMemoUid: null,
            ),
          ],
          rssActionLog: actionsLog,
        ),
      );
      await tester.pumpAndSettle();

      expect(actionsLog.markReadCalls, isEmpty);
      expect(actionsLog.createdMemoCount, 0);

      await tester.tap(find.text('Open Marks Read').first);
      await tester.pumpAndSettle();

      expect(actionsLog.markReadCalls, <String>['article-open:true']);
      expect(actionsLog.createdMemoCount, 0);
    },
  );

  testWidgets('RSS save-as-memo is explicit and does not duplicate', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final collection = MemoCollection.createRss(
      id: 'collection-rss-flow-save',
      title: 'RSS shelf',
    );
    final actionsLog = _TestRssActionLog();

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: const <LocalMemo>[],
        rssArticles: <RssArticleWithFeed>[
          _rssArticleWithFeed(
            articleId: 'article-save',
            title: 'Save Explicitly',
            savedMemoUid: null,
          ),
        ],
        rssActionLog: actionsLog,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Explicitly').first);
    await tester.pumpAndSettle();
    expect(actionsLog.createdMemoCount, 0);

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined).last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bookmark_add_outlined).last);
    await tester.pumpAndSettle();

    expect(actionsLog.savedArticleIds, <String>['article-save']);
    expect(actionsLog.createdMemoCount, 1);
  });

  testWidgets('RSS collection can opt back into continuous reader', (
    tester,
  ) async {
    final collection = MemoCollection.createRss(
      id: 'collection-rss-continuous',
      title: 'RSS shelf',
      view: CollectionViewPreferences.defaults.copyWith(
        readingExperience: CollectionReadingExperience.continuousReader,
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        collection: collection,
        memos: const <LocalMemo>[],
        rssArticles: <RssArticleWithFeed>[
          _rssArticleWithFeed(
            articleId: 'article-continuous',
            title: 'Continuous RSS Article',
            savedMemoUid: null,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CollectionReaderOverlay), findsOneWidget);
    expect(find.text('All feeds'), findsNothing);
  });

  testWidgets('reader overlay stays visible without auto-hide timer', (
    tester,
  ) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-4',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: memos),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    var overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isTrue);

    await tester.pump(const Duration(seconds: 2));
    overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isTrue);

    await tester.pump(const Duration(seconds: 2));
    overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isTrue);
  });

  testWidgets('reader overlay toggles closed on center tap', (tester) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-6',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: memos),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    var overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isTrue);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isFalse);
  });

  testWidgets('vertical mode only center tap toggles overlay', (tester) async {
    final collection = MemoCollection.createSmart(
      id: 'collection-5',
      title: 'Reading shelf',
      description: 'Collected reading notes',
      rules: const CollectionRuleSet(
        tagPaths: <String>['reading'],
        tagMatchMode: CollectionTagMatchMode.any,
        includeDescendants: true,
        visibility: CollectionVisibilityScope.all,
        dateRule: CollectionDateRule.defaults,
        attachmentRule: CollectionAttachmentRule.any,
        pinnedOnly: false,
      ),
    );
    final memos = <LocalMemo>[
      _memo(
        uid: 'memo-1',
        content: 'Alpha reading note',
        tags: const <String>['reading'],
        createTime: DateTime(2024, 2, 10, 8),
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(collection: collection, memos: memos),
    );
    await tester.pumpAndSettle();

    var overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isFalse);

    await tester.tapAt(const Offset(40, 300));
    await tester.pumpAndSettle();

    overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isFalse);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    overlay = tester.widget<CollectionReaderOverlay>(
      find.byType(CollectionReaderOverlay),
    );
    expect(overlay.visible, isTrue);
  });
}

Widget _buildTestApp({
  required MemoCollection collection,
  required List<LocalMemo> memos,
  List<RssArticleWithFeed> rssArticles = const <RssArticleWithFeed>[],
  _MemoryCollectionReaderProgressRepository? progressRepository,
  _MemoryCollectionArticleFlowProgressRepository? articleFlowProgressRepository,
  _TestRssActionLog? rssActionLog,
  DevicePreferences? devicePreferences,
  Size? viewportSize,
  ValueChanged<DevicePreferencesController>? onPreferencesControllerCreated,
}) {
  final repository =
      progressRepository ?? _MemoryCollectionReaderProgressRepository();
  final articleFlowRepository =
      articleFlowProgressRepository ??
      _MemoryCollectionArticleFlowProgressRepository();
  final prefs = devicePreferences ?? DevicePreferences.defaults;
  final actionLog = rssActionLog ?? _TestRssActionLog();
  return ProviderScope(
    overrides: [
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      devicePreferencesProvider.overrideWith((ref) {
        final controller = _TestDevicePreferencesController(ref, prefs);
        onPreferencesControllerCreated?.call(controller);
        return controller;
      }),
      collectionReaderProgressRepositoryProvider.overrideWith(
        (ref) => repository,
      ),
      collectionArticleFlowProgressRepositoryProvider.overrideWith(
        (ref) => articleFlowRepository,
      ),
      collectionsProvider.overrideWith((ref) => Stream.value([collection])),
      collectionCandidateMemosProvider.overrideWith(
        (ref) => Stream.value(memos),
      ),
      collectionRssArticlesProvider.overrideWith(
        (ref, collectionId) => Stream.value(
          collectionId == collection.id
              ? rssArticles
              : const <RssArticleWithFeed>[],
        ),
      ),
      collectionRssActionsProvider.overrideWith(
        (ref) => _TestCollectionRssActions(ref, actionLog),
      ),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: viewportSize == null
            ? CollectionDetailScreen(collectionId: collection.id)
            : MediaQuery(
                data: MediaQueryData(size: viewportSize),
                child: CollectionDetailScreen(collectionId: collection.id),
              ),
      ),
    ),
  );
}

RssArticleWithFeed _rssArticleWithFeed({
  required String articleId,
  required String title,
  required String? savedMemoUid,
}) {
  final created = DateTime(2026, 5, 1, 9);
  final feed = RssFeed(
    id: 'feed-1',
    feedUrl: 'https://example.com/feed.xml',
    siteUrl: 'https://example.com/',
    title: 'Example Feed',
    description: '',
    iconUrl: '',
    etag: '',
    lastModified: '',
    lastFetchTime: created,
    lastSuccessTime: created,
    lastError: null,
    createdTime: created,
    updatedTime: created,
  );
  final article = RssArticle(
    id: articleId,
    feedId: feed.id,
    guid: articleId,
    link: 'https://example.com/$articleId',
    title: title,
    author: '',
    summaryHtml: '<p>$title summary</p>',
    contentHtml: '<p>$title body</p>',
    leadImageUrl: '',
    publishedTime: created,
    fetchedTime: created,
    readState: RssArticleReadState.unread,
    savedMemoUid: savedMemoUid,
    createdTime: created,
    updatedTime: created,
  );
  return RssArticleWithFeed(article: article, feed: feed);
}

LocalMemo _memo({
  required String uid,
  required String content,
  required List<String> tags,
  required DateTime createTime,
  List<Attachment> attachments = const <Attachment>[],
}) {
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: 'fingerprint-$uid',
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: createTime,
    displayTime: createTime,
    updateTime: createTime.add(const Duration(minutes: 5)),
    tags: tags,
    attachments: attachments,
    relationCount: 0,
    location: null,
    syncState: SyncState.synced,
    lastError: null,
  );
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(
          AppSessionState(accounts: <Account>[], currentKey: null),
        ),
      );

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }
}

class _TestRssActionLog {
  final markReadCalls = <String>[];
  final savedArticleIds = <String>[];
  final _savedMemoUidByArticleId = <String, String>{};

  int get createdMemoCount => savedArticleIds.length;
}

class _TestCollectionRssActions extends CollectionRssActions {
  _TestCollectionRssActions(Ref ref, this.log)
    : super(
        repository: _NoopRssRepository(),
        memoMutations: MemoMutationService(
          ref: ref,
          db: AppDatabase(dbName: 'collection_detail_screen_noop_memo.db'),
        ),
      );

  final _TestRssActionLog log;

  @override
  Future<void> markRead(CollectionReadableItem item, bool read) async {
    final articleId = item.rssArticle?.id;
    if (articleId == null || articleId.isEmpty) return;
    log.markReadCalls.add('$articleId:$read');
  }

  @override
  Future<String?> saveAsMemo(CollectionReadableItem item) async {
    final articleId = item.rssArticle?.id;
    final existingSaved = item.savedMemoUid?.trim();
    if (existingSaved != null && existingSaved.isNotEmpty) {
      return existingSaved;
    }
    if (articleId == null || articleId.isEmpty) {
      return null;
    }
    final remembered = log._savedMemoUidByArticleId[articleId];
    if (remembered != null) {
      return remembered;
    }
    final memoUid = 'saved-$articleId';
    log._savedMemoUidByArticleId[articleId] = memoUid;
    log.savedArticleIds.add(articleId);
    return memoUid;
  }
}

class _NoopRssRepository extends RssRepository {
  _NoopRssRepository()
    : super(db: AppDatabase(dbName: 'collection_detail_screen_noop_rss.db'));

  @override
  Future<RssArticle?> readArticleById(String articleId) async => null;

  @override
  Future<void> markArticleRead({
    required String articleId,
    required bool read,
  }) async {}

  @override
  Future<void> updateArticleSavedMemoUid({
    required String articleId,
    required String? memoUid,
  }) async {}
}

class _MemoryCollectionReaderProgressRepository
    extends CollectionReaderProgressRepository {
  _MemoryCollectionReaderProgressRepository()
    : super(database: AppDatabase(dbName: 'collection_detail_screen_test.db'));

  CollectionReaderProgress? _progress;
  int saveCalls = 0;

  CollectionReaderProgress? get savedProgress => _progress;

  void seed(CollectionReaderProgress progress) {
    _progress = progress;
  }

  @override
  Future<CollectionReaderProgress?> load(String collectionId) async =>
      _progress;

  @override
  Future<void> save(CollectionReaderProgress progress) async {
    saveCalls++;
    _progress = progress;
  }

  @override
  Future<void> clear(String collectionId) async {
    _progress = null;
  }
}

class _MemoryCollectionArticleFlowProgressRepository
    extends CollectionArticleFlowProgressRepository {
  _MemoryCollectionArticleFlowProgressRepository()
    : super(database: AppDatabase(dbName: 'collection_article_flow_test.db'));

  CollectionArticleFlowProgress? _progress;

  @override
  Future<CollectionArticleFlowProgress?> load(String collectionId) async =>
      _progress;

  @override
  Future<void> save(CollectionArticleFlowProgress progress) async {
    _progress = progress;
  }

  @override
  Future<void> clear(String collectionId) async {
    _progress = null;
  }
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository(this._stored)
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _stored;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<DevicePreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(DevicePreferences prefs) async {
    _stored = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(Ref ref, DevicePreferences initial)
    : super(
        ref,
        _TestDevicePreferencesRepository(initial),
        onLoaded: () {
          ref.read(devicePreferencesLoadedProvider.notifier).state = true;
        },
      );
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    }
    return false;
  });
}

Finder _findRichTextExactly(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText() == text;
    }
    return false;
  });
}

Finder _findBodyRichTextExactly(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText() == text && widget.maxLines == null;
    }
    return false;
  });
}
