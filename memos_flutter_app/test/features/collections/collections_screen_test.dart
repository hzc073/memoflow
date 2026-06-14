import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/memo_collection.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/collections/collections_screen.dart';
import 'package:memos_flutter_app/features/home/app_drawer.dart';
import 'package:memos_flutter_app/features/home/home_entry_screen.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/collections/collection_resolver.dart';
import 'package:memos_flutter_app/state/collections/collections_provider.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/stats_providers.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/notifications_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'dev.memoflow.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    HomeEntryScreen.debugClassicScreenBuilderOverride = (_) =>
        const Text('classic-home');
    HomeEntryScreen.debugBottomNavShellBuilderOverride = (_) =>
        const Text('bottom-nav-home');
  });

  tearDown(() {
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
  });

  testWidgets('shows loading state while collections dashboard resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => const AsyncValue.loading(),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Loading collections'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty shelf state when there are no collections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => const AsyncValue.data(<MemoCollectionDashboardItem>[]),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('No collections yet'), findsOneWidget);
    expect(find.text('Create collection'), findsWidgets);
  });

  testWidgets('default shelf hides archived collections', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => AsyncValue.data(<MemoCollectionDashboardItem>[
              _dashboardItem(
                id: 'smart-1',
                title: 'Reading shelf',
                type: MemoCollectionType.smart,
              ),
              _dashboardItem(
                id: 'manual-1',
                title: 'Archived shelf',
                type: MemoCollectionType.manual,
                archived: true,
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Reading shelf'), findsOneWidget);
    expect(find.text('Archived shelf'), findsNothing);
  });

  testWidgets('search filters results and clear button resets results', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => AsyncValue.data(<MemoCollectionDashboardItem>[
              _dashboardItem(
                id: 'smart-1',
                title: 'Reading shelf',
                type: MemoCollectionType.smart,
              ),
              _dashboardItem(
                id: 'smart-2',
                title: 'Travel shelf',
                type: MemoCollectionType.smart,
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Reading shelf'), findsOneWidget);
    expect(find.text('Travel shelf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search collections',
      ),
      'travel',
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Travel shelf'), findsOneWidget);
    expect(find.text('Reading shelf'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Travel shelf'), findsOneWidget);
    expect(find.text('Reading shelf'), findsOneWidget);
  });

  testWidgets('hide-when-empty collections stay visible in management list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => AsyncValue.data(<MemoCollectionDashboardItem>[
              _dashboardItem(
                id: 'smart-1',
                title: 'Hidden shelf',
                type: MemoCollectionType.smart,
                hideWhenEmpty: true,
                itemCount: 0,
              ),
              _dashboardItem(
                id: 'smart-2',
                title: 'Visible shelf',
                type: MemoCollectionType.smart,
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Hidden shelf'), findsOneWidget);
    expect(find.text('Visible shelf'), findsOneWidget);
  });

  testWidgets('reorder shelf ignores archived collections only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => AsyncValue.data(<MemoCollectionDashboardItem>[
              _dashboardItem(
                id: 'smart-1',
                title: 'Visible shelf',
                type: MemoCollectionType.smart,
              ),
              _dashboardItem(
                id: 'smart-2',
                title: 'Archived shelf',
                type: MemoCollectionType.smart,
                archived: true,
              ),
              _dashboardItem(
                id: 'smart-3',
                title: 'Hidden shelf',
                type: MemoCollectionType.smart,
                hideWhenEmpty: true,
                itemCount: 0,
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    final reorderButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.reorder_rounded),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(reorderButton.onPressed, isNotNull);
  });

  testWidgets('drawer navigation uses embedded host when provided', (
    tester,
  ) async {
    final host = _TestHomeEmbeddedNavigationHost();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => AsyncValue.data(<MemoCollectionDashboardItem>[
              _dashboardItem(
                id: 'smart-1',
                title: 'Reading shelf',
                type: MemoCollectionType.smart,
              ),
            ]),
          ),
        ],
        size: const Size(1400, 900),
        home: CollectionsScreen(embeddedNavigationHost: host),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Memos'));
    await tester.pumpAndSettle();

    expect(host.lastDestination, AppDrawerDestination.memos);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iPhone menu button opens embedded drawer through PlatformPage', (
    tester,
  ) async {
    final host = _TestHomeEmbeddedNavigationHost();
    debugPlatformTargetOverride = TargetPlatform.iOS;
    addTearDown(() => debugPlatformTargetOverride = null);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => AsyncValue.data(<MemoCollectionDashboardItem>[
              _dashboardItem(
                id: 'smart-1',
                title: 'Reading shelf',
                type: MemoCollectionType.smart,
              ),
            ]),
          ),
        ],
        size: const Size(430, 900),
        home: CollectionsScreen(embeddedNavigationHost: host),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('drawer-menu-button')), findsOneWidget);
    expect(find.text('All Memos'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('drawer-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('All Memos'), findsOneWidget);

    await tester.tap(find.text('All Memos'));
    await tester.pumpAndSettle();

    expect(host.lastDestination, AppDrawerDestination.memos);
  });

  testWidgets('standalone Collections back returns to HomeEntryScreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => const AsyncValue.data(<MemoCollectionDashboardItem>[]),
          ),
          workspacePreferencesLoadedProvider.overrideWith((ref) => true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('classic-home'), findsOneWidget);
    expect(find.byType(CollectionsScreen), findsNothing);
    expect(find.text('bottom-nav-home'), findsNothing);
  });

  testWidgets('embedded Collections back delegates to host', (tester) async {
    final host = _TestHomeEmbeddedNavigationHost();

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          collectionsDashboardProvider.overrideWith(
            (ref) => const AsyncValue.data(<MemoCollectionDashboardItem>[]),
          ),
          workspacePreferencesLoadedProvider.overrideWith((ref) => true),
        ],
        home: CollectionsScreen(embeddedNavigationHost: host),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(host.backToPrimaryCount, 1);
    expect(find.byType(CollectionsScreen), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
    expect(find.text('bottom-nav-home'), findsNothing);
  });
}

Widget _buildTestApp({
  required List<Override> overrides,
  Widget? home,
  Size size = const Size(430, 900),
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(_FakeAppDatabase()),
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      currentLocalLibraryProvider.overrideWith((ref) => null),
      localStatsProvider.overrideWith(
        (ref) => Stream.value(
          const LocalStats(
            totalMemos: 0,
            archivedMemos: 0,
            activeDays: 0,
            daysSinceFirstMemo: 0,
            totalChars: 0,
            dailyCounts: <DateTime, int>{},
          ),
        ),
      ),
      tagStatsProvider.overrideWith((ref) => Stream.value(const <TagStat>[])),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
      unreadNotificationCountProvider.overrideWith((ref) => 0),
      currentWorkspacePreferencesProvider.overrideWith(
        (ref) => _TestWorkspacePreferencesController(ref),
      ),
      ...overrides,
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: home ?? const CollectionsScreen(),
        ),
      ),
    ),
  );
}

MemoCollectionDashboardItem _dashboardItem({
  required String id,
  required String title,
  required MemoCollectionType type,
  bool archived = false,
  bool hideWhenEmpty = false,
  int itemCount = 2,
}) {
  final collection = type == MemoCollectionType.smart
      ? MemoCollection.createSmart(
          id: id,
          title: title,
          description: '',
          rules: const CollectionRuleSet(
            tagPaths: <String>['reading'],
            tagMatchMode: CollectionTagMatchMode.any,
            includeDescendants: true,
            visibility: CollectionVisibilityScope.all,
            dateRule: CollectionDateRule.defaults,
            attachmentRule: CollectionAttachmentRule.any,
            pinnedOnly: false,
          ),
          archived: archived,
          hideWhenEmpty: hideWhenEmpty,
        )
      : MemoCollection.createManual(
          id: id,
          title: title,
          description: '',
          archived: archived,
          hideWhenEmpty: hideWhenEmpty,
        );

  return MemoCollectionDashboardItem(
    collection: collection,
    preview: MemoCollectionPreview(
      itemCount: itemCount,
      imageItemCount: 0,
      latestUpdateTime: DateTime(2024, 2, 1),
      sampleItems: const [],
      coverAttachment: null,
      effectiveAccentColorHex: null,
      ruleSummary: type == MemoCollectionType.smart
          ? '#reading · Any tag'
          : 'Manual collection',
    ),
    items: const [],
  );
}

class _FakeAppDatabase extends AppDatabase {
  _FakeAppDatabase() : super(dbName: 'fake.db');

  @override
  Future<int> countOutboxPending() async => 0;
}

class _TestHomeEmbeddedNavigationHost implements HomeEmbeddedNavigationHost {
  AppDrawerDestination? lastDestination;
  int backToPrimaryCount = 0;

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {}

  @override
  void handleBackToPrimaryDestination(BuildContext context) {
    backToPrimaryCount += 1;
  }

  @override
  void handleDrawerDestination(
    BuildContext context,
    AppDrawerDestination destination,
  ) {
    lastDestination = destination;
  }

  @override
  void handleDrawerTag(BuildContext context, String tag) {}

  @override
  void handleOpenNotifications(BuildContext context) {}

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {}
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

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository()
    : _stored = WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults,
      ),
      super(
        PreferencesMigrationService(const FlutterSecureStorage()),
        workspaceKey: 'test-workspace',
      );

  WorkspacePreferences _stored;

  @override
  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<WorkspacePreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(WorkspacePreferences prefs) async {
    _stored = prefs;
  }
}

class _TestWorkspacePreferencesController
    extends WorkspacePreferencesController {
  _TestWorkspacePreferencesController(Ref ref)
    : super(ref, _TestWorkspacePreferencesRepository()) {
    state = WorkspacePreferences.defaults;
  }
}
