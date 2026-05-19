import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/home/home_entry_screen.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/features/home/home_root_destination_registry.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    HomeEntryScreen.debugClassicScreenBuilderOverride = (_) =>
        const Text('classic-home');
    HomeEntryScreen.debugBottomNavShellBuilderOverride = (_) =>
        const Text('bottom-nav-shell');
    debugHomeRootScreenBuilderOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
    debugHomeRootScreenBuilderOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('classic mode returns classic home screen', (tester) async {
    final container = _buildContainer(
      prefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults,
      ),
      loaded: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('classic-home'), findsOneWidget);
    expect(find.text('bottom-nav-shell'), findsNothing);
  });

  testWidgets('bottom navigation mode returns shell on mobile', (tester) async {
    final container = _buildContainer(
      prefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      loaded: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('bottom-nav-shell'), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
  });

  testWidgets('iPad target uses apple tablet shell with sidebar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    debugHomeRootScreenBuilderOverride =
        ({
          required BuildContext context,
          required HomeRootDestination destination,
          required HomeScreenPresentation presentation,
          required HomeEmbeddedNavigationHost? navigationHost,
          String? memosTag,
        }) => Text('page-${destination.name}-${presentation.name}');
    final container = _buildContainer(
      prefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      loaded: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(1024, 768)),
          child: HomeEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MemoFlow'), findsOneWidget);
    expect(find.text('bottom-nav-shell'), findsNothing);
    expect(find.text('classic-home'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop still returns classic home in bottom navigation mode', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final container = _buildContainer(
      prefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      loaded: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('classic-home'), findsOneWidget);
    expect(find.text('bottom-nav-shell'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('switching mode at runtime updates the rendered home entry', (
    tester,
  ) async {
    final container = _buildContainer(
      prefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults,
      ),
      loaded: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('classic-home'), findsOneWidget);
    expect(find.text('bottom-nav-shell'), findsNothing);

    container
        .read(currentWorkspacePreferencesProvider.notifier)
        .setHomeNavigationMode(HomeNavigationMode.bottomBar);
    await tester.pump();

    expect(find.text('bottom-nav-shell'), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
  });
}

Widget _buildApp(ProviderContainer container, {Widget? home}) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home ?? const HomeEntryScreen(),
      ),
    ),
  );
}

ProviderContainer _buildContainer({
  required WorkspacePreferences prefs,
  required bool loaded,
}) {
  return ProviderContainer(
    overrides: [
      currentWorkspacePreferencesProvider.overrideWith(
        (ref) => _TestWorkspacePreferencesController(ref, initial: prefs),
      ),
      workspacePreferencesLoadedProvider.overrideWith((ref) => loaded),
    ],
  );
}

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository(this._stored)
    : super(
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
  _TestWorkspacePreferencesController(
    Ref ref, {
    required WorkspacePreferences initial,
  }) : super(ref, _TestWorkspacePreferencesRepository(initial)) {
    state = initial;
  }
}
