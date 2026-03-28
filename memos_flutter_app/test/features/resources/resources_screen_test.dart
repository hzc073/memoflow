import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/memo_relation.dart';
import 'package:memos_flutter_app/features/resources/resources_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

import '../../test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestSupport support;
  late AppDatabase database;
  late String dbName;

  setUpAll(() async {
    support = await initializeTestSupport();
    LocaleSettings.setLocale(AppLocale.en);
  });

  tearDownAll(() async {
    await support.dispose();
  });

  setUp(() async {
    dbName = uniqueDbName('resources_screen_test');
    database = AppDatabase(dbName: dbName);
    await database.db;
    ResourcesScreen.debugRouteRequestOverride = null;
  });

  tearDown(() async {
    ResourcesScreen.debugRouteRequestOverride = null;
    await database.close();
    await deleteTestDatabase(dbName);
  });

  testWidgets(
    'groups attachments by advanced search types and supports collapsing sections',
    (tester) async {
      final entries = <ResourceEntry>[
        _entry(
          memoUid: 'memo-image-new',
          updateTime: DateTime(2024, 1, 10, 9),
          attachment: _attachment('image-new', 'image-new.png', 'image/png'),
        ),
        _entry(
          memoUid: 'memo-image-old',
          updateTime: DateTime(2024, 1, 1, 9),
          attachment: _attachment('image-old', 'image-old.png', 'image/png'),
        ),
        _entry(
          memoUid: 'memo-video',
          updateTime: DateTime(2024, 1, 9, 9),
          attachment: _attachment('video-1', 'video-1.mp4', 'video/mp4'),
        ),
        _entry(
          memoUid: 'memo-audio',
          updateTime: DateTime(2024, 1, 8, 9),
          attachment: _attachment('audio-1', 'audio-1.mp3', 'audio/mpeg'),
        ),
        _entry(
          memoUid: 'memo-file',
          updateTime: DateTime(2024, 1, 7, 9),
          attachment: _attachment('file-1', 'file-1.pdf', 'application/pdf'),
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(database: database, resourceEntries: entries),
      );
      await _settle(tester);

      final imageHeader = find.byKey(
        const ValueKey('resources-section-title-image'),
      );
      final audioHeader = find.byKey(
        const ValueKey('resources-section-title-audio'),
      );
      final documentHeader = find.byKey(
        const ValueKey('resources-section-title-document'),
      );
      final otherHeader = find.byKey(
        const ValueKey('resources-section-title-other'),
      );

      expect(imageHeader, findsOneWidget);
      expect(audioHeader, findsOneWidget);
      expect(
        find.byKey(const ValueKey('resources-section-title-video')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('resources-sort-button')), findsNothing);

      expect(
        tester.getTopLeft(imageHeader).dy,
        lessThan(tester.getTopLeft(audioHeader).dy),
      );

      _expectVisualBefore(
        tester,
        find.text('image-new.png'),
        find.text('image-old.png'),
      );

      await tester.tap(imageHeader);
      await _settle(tester);

      expect(find.text('image-new.png'), findsNothing);
      expect(find.text('image-old.png'), findsNothing);

      await tester.tap(imageHeader);
      await _settle(tester);

      expect(find.text('image-new.png'), findsOneWidget);
      expect(find.text('image-old.png'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await _settle(tester);

      expect(documentHeader, findsOneWidget);
      expect(otherHeader, findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'video card under other opens preview while document card opens memo',
    (tester) async {
      final requestedRoutes = <String>[];
      ResourcesScreen.debugRouteRequestOverride = requestedRoutes.add;

      await tester.pumpWidget(
        _buildTestApp(
          database: database,
          resourceEntries: [
            _entry(
              memoUid: 'memo-video',
              updateTime: DateTime(2024, 1, 10, 9),
              attachment: _attachment(
                'preview-video',
                'preview-video.mp4',
                'video/mp4',
              ),
            ),
            _entry(
              memoUid: 'memo-document',
              updateTime: DateTime(2024, 1, 9, 9),
              attachment: _attachment(
                'preview-document',
                'preview-document.pdf',
                'application/pdf',
              ),
            ),
          ],
        ),
      );
      await _settle(tester);

      await _invokeCardTap(
        tester,
        find.byKey(
          const ValueKey('resources-card-tap-memo-video-preview-video'),
        ),
      );
      await _settle(tester);

      expect(requestedRoutes, ['resources/video-preview']);

      await _invokeCardTap(
        tester,
        find.byKey(
          const ValueKey('resources-card-tap-memo-document-preview-document'),
        ),
      );
      await _settle(tester);

      expect(requestedRoutes, [
        'resources/video-preview',
        'resources/open-memo',
      ]);

      await _disposeTree(tester);
    },
  );

  testWidgets('open memo action opens source memo for any attachment', (
    tester,
  ) async {
    final requestedRoutes = <String>[];
    ResourcesScreen.debugRouteRequestOverride = requestedRoutes.add;

    await tester.pumpWidget(
      _buildTestApp(
        database: database,
        resourceEntries: [
          _entry(
            memoUid: 'memo-image',
            updateTime: DateTime(2024, 1, 10, 9),
            attachment: _attachment(
              'action-image',
              'action-image.png',
              'image/png',
            ),
          ),
        ],
      ),
    );
    await _settle(tester);

    await tester.tap(
      find.byKey(const ValueKey('resources-open-memo-memo-image-action-image')),
    );
    await _settle(tester);

    expect(requestedRoutes, ['resources/open-memo']);

    await _disposeTree(tester);
  });

  testWidgets('shows empty state when there are no attachments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        database: database,
        resourceEntries: const <ResourceEntry>[],
      ),
    );
    await _settle(tester);

    expect(find.text('No attachments'), findsOneWidget);

    await _disposeTree(tester);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _invokeCardTap(WidgetTester tester, Finder tapTarget) async {
  final inkWell = tester.widget<InkWell>(tapTarget);
  inkWell.onTap!.call();
  await tester.pump();
}

void _expectVisualBefore(WidgetTester tester, Finder first, Finder second) {
  final firstTopLeft = tester.getTopLeft(first);
  final secondTopLeft = tester.getTopLeft(second);

  final isBefore =
      firstTopLeft.dy < secondTopLeft.dy ||
      (firstTopLeft.dy == secondTopLeft.dy &&
          firstTopLeft.dx < secondTopLeft.dx);

  expect(isBefore, isTrue);
}

Widget _buildTestApp({
  required AppDatabase database,
  List<ResourceEntry>? resourceEntries,
}) {
  return ProviderScope(
    overrides: [
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref),
      ),
      databaseProvider.overrideWithValue(database),
      if (resourceEntries != null)
        resourcesProvider.overrideWith((ref) => Stream.value(resourceEntries)),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
      memoRelationsProvider.overrideWith(
        (ref, memoUid) =>
            Stream<List<MemoRelation>>.value(const <MemoRelation>[]),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(900, 3000)),
          child: ResourcesScreen(),
        ),
      ),
    ),
  );
}

Attachment _attachment(
  String uid,
  String filename,
  String type, {
  String externalLink = '',
}) {
  return Attachment(
    name: 'attachments/$uid',
    filename: filename,
    type: type,
    size: 128,
    externalLink: externalLink,
  );
}

ResourceEntry _entry({
  required String memoUid,
  required DateTime updateTime,
  required Attachment attachment,
}) {
  return ResourceEntry(
    memoUid: memoUid,
    memoUpdateTime: updateTime,
    attachment: attachment,
  );
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(
          AppSessionState(accounts: [], currentKey: 'test-account'),
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
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}
}

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository()
    : super(const FlutterSecureStorage(), accountKey: null);

  @override
  Future<void> clear() async {}

  @override
  Future<AppPreferences> read() async {
    return AppPreferences.defaultsForLanguage(AppLanguage.en);
  }

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
  }

  @override
  Future<void> write(AppPreferences prefs) async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref)
    : super(
        ref,
        _TestAppPreferencesRepository(),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      );
}
