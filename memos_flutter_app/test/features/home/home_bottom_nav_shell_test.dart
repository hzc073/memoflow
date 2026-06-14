import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/notification_item.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/about/about_screen.dart';
import 'package:memos_flutter_app/features/home/app_drawer.dart';
import 'package:memos_flutter_app/features/home/app_drawer_destination_builder.dart';
import 'package:memos_flutter_app/features/home/home_bottom_nav_shell.dart';
import 'package:memos_flutter_app/features/home/home_entry_screen.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/features/home/home_root_destination_registry.dart';
import 'package:memos_flutter_app/features/notifications/notifications_screen.dart';
import 'package:memos_flutter_app/features/tags/tags_screen.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_floating_actions.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_provider.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/notifications_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    debugHomeRootScreenBuilderOverride =
        ({
          required BuildContext context,
          required HomeRootDestination destination,
          required HomeScreenPresentation presentation,
          required HomeEmbeddedNavigationHost? navigationHost,
          String? memosTag,
        }) {
          return _TestRootPage(
            destination: destination,
            presentation: presentation,
            navigationHost: navigationHost,
            memosTag: memosTag,
          );
        };
    HomeBottomNavShell.debugShowNoteInputOverride = null;
    HomeEntryScreen.debugClassicScreenBuilderOverride = (_) =>
        const Text('classic-home');
    HomeEntryScreen.debugBottomNavShellBuilderOverride = (_) =>
        const Text('bottom-nav-shell');
  });

  tearDown(() {
    debugHomeRootScreenBuilderOverride = null;
    HomeBottomNavShell.debugShowNoteInputOverride = null;
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
  });

  testWidgets('default bottom bar order shows registry icons and center fab', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(find.byIcon(Icons.explore), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byType(MemoFlowFab), findsOneWidget);

    final memosX = tester.getCenter(find.text('Memos')).dx;
    final exploreX = tester.getCenter(find.text('Explore')).dx;
    final createX = tester.getCenter(find.byType(MemoFlowFab)).dx;
    final reviewX = tester.getCenter(find.text('Random Review')).dx;
    final settingsX = tester.getCenter(find.text('Settings')).dx;

    expect(memosX, lessThan(exploreX));
    expect(exploreX, lessThan(createX));
    expect(createX, lessThan(reviewX));
    expect(reviewX, lessThan(settingsX));

    final expectedGap = exploreX - memosX;
    expect(createX - exploreX, closeTo(expectedGap, 1));
    expect(reviewX - createX, closeTo(expectedGap, 1));
    expect(settingsX - reviewX, closeTo(expectedGap, 1));
    expect(
      createX,
      closeTo(tester.getSize(find.byType(HomeBottomNavShell)).width / 2, 1),
    );
  });

  testWidgets('bottom navigation decoration wraps bottom safe area', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(430, 900),
            padding: EdgeInsets.only(bottom: 24),
          ),
          child: HomeBottomNavShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navSafeAreaFinder = find.ancestor(
      of: find.text('Memos'),
      matching: find.byType(SafeArea),
    );
    expect(navSafeAreaFinder, findsOneWidget);

    final navSafeArea = tester.widget<SafeArea>(navSafeAreaFinder);
    expect(navSafeArea.top, isFalse);

    Element? immediateParent;
    tester.element(navSafeAreaFinder).visitAncestorElements((ancestor) {
      immediateParent = ancestor;
      return false;
    });
    expect(immediateParent?.widget, isA<DecoratedBox>());
  });

  testWidgets('iPhone dark bottom navigation remains readable', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;
    addTearDown(() => debugPlatformTargetOverride = null);

    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        theme: ThemeData.dark(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(430, 900),
            padding: EdgeInsets.only(bottom: 24),
          ),
          child: HomeBottomNavShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navSafeAreaFinder = find.ancestor(
      of: find.text('Memos'),
      matching: find.byType(SafeArea),
    );
    expect(navSafeAreaFinder, findsOneWidget);

    final navSafeArea = tester.widget<SafeArea>(navSafeAreaFinder);
    expect(navSafeArea.top, isFalse);

    final navDecorationFinder = find.ancestor(
      of: navSafeAreaFinder,
      matching: find.byType(DecoratedBox),
    );
    final navDecoration = tester.widget<DecoratedBox>(
      navDecorationFinder.first,
    );
    final boxDecoration = navDecoration.decoration as BoxDecoration;
    final navBackground = boxDecoration.color;
    expect(navBackground, isNotNull);
    expect(navBackground!.computeLuminance(), lessThan(0.1));

    final activeLabel = tester.widget<Text>(find.text('Memos'));
    final inactiveLabel = tester.widget<Text>(find.text('Settings'));
    final activeColor = activeLabel.style?.color;
    final inactiveColor = inactiveLabel.style?.color;

    expect(activeColor, isNotNull);
    expect(inactiveColor, isNotNull);
    expect(_contrastRatio(activeColor!, navBackground), greaterThan(3));
    expect(_contrastRatio(inactiveColor!, navBackground), greaterThan(3));
  });

  testWidgets('bottom navigation icon labels fit compact bar', (tester) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(430, 900),
          ).copyWith(textScaler: const TextScaler.linear(1.1)),
          child: const HomeBottomNavShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    expect(find.text('Random Review'), findsOneWidget);
    expect(find.byType(MemoFlowFab), findsOneWidget);
  });

  testWidgets('switching tabs preserves state with IndexedStack', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('increment-settings'));
    await tester.pumpAndSettle();
    expect(find.text('count-settings:1'), findsOneWidget);

    await tester.tap(find.text('Memos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('count-settings:1'), findsOneWidget);
  });

  testWidgets('back from non-memos tab first returns to memos', (tester) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('page-settings-embeddedBottomNav'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
  });

  testWidgets('removed active tab falls back to primary visible destination', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('page-settings-embeddedBottomNav'), findsOneWidget);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    notifier.setHomeNavigationSlots(
      leftPrimary: HomeRootDestination.none,
      leftSecondary: HomeRootDestination.none,
      rightPrimary: HomeRootDestination.none,
      rightSecondary: HomeRootDestination.none,
    );
    await tester.pumpAndSettle();

    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('settings removed from bottom bar can still open from drawer', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
          leftPrimary: HomeRootDestination.memos,
          leftSecondary: HomeRootDestination.none,
          rightPrimary: HomeRootDestination.none,
          rightSecondary: HomeRootDestination.none,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerDestination(
      tester.element(find.byType(HomeBottomNavShell)),
      AppDrawerDestination.settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('page-settings-standalone'), findsOneWidget);
  });

  testWidgets('overlay root page back returns to shell route', (tester) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
          leftPrimary: HomeRootDestination.memos,
          leftSecondary: HomeRootDestination.none,
          rightPrimary: HomeRootDestination.none,
          rightSecondary: HomeRootDestination.none,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerDestination(
      tester.element(find.byType(HomeBottomNavShell)),
      AppDrawerDestination.settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('page-settings-standalone'), findsOneWidget);

    await tester.tap(find.text('back-settings'));
    await tester.pumpAndSettle();

    expect(find.text('page-settings-standalone'), findsNothing);
    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
  });

  testWidgets('overlay root page can switch back to shell tab', (tester) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
          leftPrimary: HomeRootDestination.memos,
          leftSecondary: HomeRootDestination.none,
          rightPrimary: HomeRootDestination.none,
          rightSecondary: HomeRootDestination.none,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerDestination(
      tester.element(find.byType(HomeBottomNavShell)),
      AppDrawerDestination.settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('page-settings-standalone'), findsOneWidget);

    await tester.tap(find.text('goto-memos-settings'));
    await tester.pumpAndSettle();

    expect(find.text('page-settings-standalone'), findsNothing);
    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
  });

  testWidgets('opening tags from shell preserves bottom navigation on back', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerDestination(
      tester.element(find.byType(HomeBottomNavShell)),
      AppDrawerDestination.tags,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TagsScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TagsScreen), findsNothing);
    expect(find.byType(HomeBottomNavShell), findsOneWidget);
    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
  });

  testWidgets('opening about from shell preserves bottom navigation on back', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerDestination(
      tester.element(find.byType(HomeBottomNavShell)),
      AppDrawerDestination.about,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsNothing);
    expect(find.byType(HomeBottomNavShell), findsOneWidget);
    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
  });

  testWidgets('opening tag from shell keeps tagged memos inside bottom nav', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    final observer = _RecordingNavigatorObserver();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, navigatorObservers: [observer]),
    );
    await tester.pumpAndSettle();
    observer.lastPushedRoute = null;

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerTag(
      tester.element(find.byType(HomeBottomNavShell)),
      'work',
    );
    await tester.pumpAndSettle();

    expect(observer.lastPushedRoute, isNull);
    expect(find.byType(HomeBottomNavShell), findsOneWidget);
    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
    expect(find.text('tag-work'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('system back clears shell tag before leaving bottom nav', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerTag(
      tester.element(find.byType(HomeBottomNavShell)),
      'work',
    );
    await tester.pumpAndSettle();

    expect(find.text('tag-work'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomeBottomNavShell), findsOneWidget);
    expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
    expect(find.text('tag-none'), findsOneWidget);
  });

  testWidgets('embedded notifications back delegates to host navigation', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    final host = _RecordingEmbeddedNavigationHost();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(430, 900)),
          child: NotificationsScreen(
            presentation: HomeScreenPresentation.embeddedBottomNav,
            embeddedNavigationHost: host,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(host.backToPrimaryCount, 1);
    expect(find.text('bottom-nav-shell'), findsNothing);
    expect(find.text('classic-home'), findsNothing);
  });

  testWidgets(
    'standalone notifications back returns to HomeEntryScreen shell',
    (tester) async {
      final container = _buildContainer(
        workspacePrefs: WorkspacePreferences.defaults.copyWith(
          homeNavigationPreferences: HomeNavigationPreferences.defaults
              .copyWith(mode: HomeNavigationMode.bottomBar),
        ),
        hasAccount: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildApp(
          container,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(430, 900)),
            child: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('bottom-nav-shell'), findsOneWidget);
      expect(find.text('classic-home'), findsNothing);
    },
  );

  testWidgets('standalone tags back returns to HomeEntryScreen shell', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(430, 900)),
          child: TagsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('bottom-nav-shell'), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
  });

  testWidgets('standalone about back returns to HomeEntryScreen shell', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(430, 900)),
          child: AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('bottom-nav-shell'), findsOneWidget);
    expect(find.text('classic-home'), findsNothing);
  });

  testWidgets(
    'opening notifications from shell returns to shell memos page on back',
    (tester) async {
      final container = _buildContainer(
        workspacePrefs: _simpleBottomBarPrefs(),
        hasAccount: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
      state.handleOpenNotifications(
        tester.element(find.byType(HomeBottomNavShell)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
      expect(find.text('page-memos-embeddedBottomNav'), findsOneWidget);
    },
  );

  testWidgets('drawer destination builder passes shell host context', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    final host = _RecordingEmbeddedNavigationHost();
    addTearDown(container.dispose);

    late Widget tagsRoute;
    late Widget aboutRoute;
    await tester.pumpWidget(
      _buildApp(
        container,
        home: Builder(
          builder: (context) {
            tagsRoute = buildDrawerDestinationScreen(
              context: context,
              destination: AppDrawerDestination.tags,
              presentation: HomeScreenPresentation.standalone,
              navigationHost: host,
            );
            aboutRoute = buildDrawerDestinationScreen(
              context: context,
              destination: AppDrawerDestination.about,
              presentation: HomeScreenPresentation.standalone,
              navigationHost: host,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tagsRoute, isA<TagsScreen>());
    final tagsScreen = tagsRoute as TagsScreen;
    expect(tagsScreen.presentation, HomeScreenPresentation.standalone);
    expect(tagsScreen.embeddedNavigationHost, same(host));

    expect(aboutRoute, isA<AboutScreen>());
    final aboutScreen = aboutRoute as AboutScreen;
    expect(aboutScreen.presentation, HomeScreenPresentation.standalone);
    expect(aboutScreen.embeddedNavigationHost, same(host));
  });

  testWidgets(
    'opening notifications from non-primary tab returns to same shell tab',
    (tester) async {
      final container = _buildContainer(
        workspacePrefs: _simpleBottomBarPrefs(),
        hasAccount: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('page-settings-embeddedBottomNav'), findsOneWidget);

      final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
      state.handleOpenNotifications(
        tester.element(find.byType(HomeBottomNavShell)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
      expect(find.text('page-settings-embeddedBottomNav'), findsOneWidget);
      expect(find.text('page-memos-embeddedBottomNav'), findsNothing);
    },
  );

  testWidgets(
    'drawer collections destination reuses configured bottom navigation tab',
    (tester) async {
      final container = _buildContainer(
        workspacePrefs: WorkspacePreferences.defaults.copyWith(
          homeNavigationPreferences: HomeNavigationPreferences.defaults
              .copyWith(
                mode: HomeNavigationMode.bottomBar,
                leftPrimary: HomeRootDestination.memos,
                leftSecondary: HomeRootDestination.collections,
                rightPrimary: HomeRootDestination.none,
                rightSecondary: HomeRootDestination.settings,
              ),
        ),
        hasAccount: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
      state.handleDrawerDestination(
        tester.element(find.byType(HomeBottomNavShell)),
        AppDrawerDestination.collections,
      );
      await tester.pumpAndSettle();

      expect(find.text('page-collections-embeddedBottomNav'), findsOneWidget);
      expect(find.text('page-collections-standalone'), findsNothing);
    },
  );

  testWidgets('bottom navigation can display and switch to Draft Box', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
          leftPrimary: HomeRootDestination.memos,
          leftSecondary: HomeRootDestination.draftBox,
          rightPrimary: HomeRootDestination.none,
          rightSecondary: HomeRootDestination.settings,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('Draft Box'), findsOneWidget);
    expect(find.byType(MemoFlowFab), findsOneWidget);

    await tester.tap(find.text('Draft Box'));
    await tester.pumpAndSettle();

    expect(find.text('page-draftBox-embeddedBottomNav'), findsOneWidget);
    expect(find.byType(HomeBottomNavShell), findsOneWidget);
    expect(find.byType(MemoFlowFab), findsOneWidget);
  });

  testWidgets('drawer Draft Box destination reuses configured bottom tab', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
          leftPrimary: HomeRootDestination.memos,
          leftSecondary: HomeRootDestination.draftBox,
          rightPrimary: HomeRootDestination.none,
          rightSecondary: HomeRootDestination.settings,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(HomeBottomNavShell)) as dynamic;
    state.handleDrawerDestination(
      tester.element(find.byType(HomeBottomNavShell)),
      AppDrawerDestination.draftBox,
    );
    await tester.pumpAndSettle();

    expect(find.text('page-draftBox-embeddedBottomNav'), findsOneWidget);
    expect(find.text('page-draftBox-standalone'), findsNothing);
  });

  testWidgets('account changes rebuild visible tabs', (tester) async {
    final container = _buildContainer(
      workspacePrefs: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
          leftPrimary: HomeRootDestination.memos,
          leftSecondary: HomeRootDestination.explore,
          rightPrimary: HomeRootDestination.none,
          rightSecondary: HomeRootDestination.settings,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);

    final notifier =
        container.read(appSessionProvider.notifier) as _TestSessionController;
    notifier.setHasAccount(false);
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsNothing);
  });

  testWidgets('center add button opens note input from any tab', (
    tester,
  ) async {
    final container = _buildContainer(
      workspacePrefs: _simpleBottomBarPrefs(),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    var addPressedCount = 0;
    HomeBottomNavShell.debugShowNoteInputOverride = (context) async {
      addPressedCount++;
    };

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MemoFlowFab));
    await tester.pumpAndSettle();

    expect(addPressedCount, 1);
  });
}

WorkspacePreferences _simpleBottomBarPrefs() {
  return WorkspacePreferences.defaults.copyWith(
    homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
      mode: HomeNavigationMode.bottomBar,
      leftPrimary: HomeRootDestination.memos,
      leftSecondary: HomeRootDestination.none,
      rightPrimary: HomeRootDestination.none,
      rightSecondary: HomeRootDestination.settings,
    ),
  );
}

Widget _buildApp(
  ProviderContainer container, {
  Widget? home,
  ThemeData? theme,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: theme,
        navigatorObservers: navigatorObservers,
        home:
            home ??
            const MediaQuery(
              data: MediaQueryData(size: Size(430, 900)),
              child: HomeBottomNavShell(),
            ),
      ),
    ),
  );
}

double _contrastRatio(Color foreground, Color background) {
  final light = foreground.computeLuminance() + 0.05;
  final dark = background.computeLuminance() + 0.05;
  return light > dark ? light / dark : dark / light;
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}

ProviderContainer _buildContainer({
  required WorkspacePreferences workspacePrefs,
  required bool hasAccount,
}) {
  return ProviderContainer(
    overrides: [
      currentWorkspacePreferencesProvider.overrideWith(
        (ref) =>
            _TestWorkspacePreferencesController(ref, initial: workspacePrefs),
      ),
      workspacePreferencesLoadedProvider.overrideWith((ref) => true),
      devicePreferencesProvider.overrideWith(
        (ref) => _TestDevicePreferencesController(ref),
      ),
      appSessionProvider.overrideWith(
        (ref) => _TestSessionController(hasAccount: hasAccount),
      ),
      notificationsProvider.overrideWith(
        (ref) async => const <AppNotification>[],
      ),
      unreadNotificationCountProvider.overrideWith((ref) => 0),
      tagStatsProvider.overrideWith((ref) => Stream.value(const <TagStat>[])),
      syncQueuePendingCountProvider.overrideWith((ref) => Stream.value(0)),
      syncQueueAttentionCountProvider.overrideWith((ref) => Stream.value(0)),
      syncCoordinatorProvider.overrideWith((ref) => _NoopSyncFacade()),
    ],
  );
}

class _TestRootPage extends StatefulWidget {
  const _TestRootPage({
    required this.destination,
    required this.presentation,
    required this.navigationHost,
    required this.memosTag,
  });

  final HomeRootDestination destination;
  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? navigationHost;
  final String? memosTag;

  @override
  State<_TestRootPage> createState() => _TestRootPageState();
}

class _TestRootPageState extends State<_TestRootPage> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('page-${widget.destination.name}-${widget.presentation.name}'),
            if (widget.destination == HomeRootDestination.memos)
              Text('tag-${widget.memosTag ?? 'none'}'),
            Text('count-${widget.destination.name}:$count'),
            TextButton(
              onPressed: () => setState(() => count++),
              child: Text('increment-${widget.destination.name}'),
            ),
            if (widget.navigationHost != null)
              TextButton(
                onPressed: () => widget.navigationHost!
                    .handleBackToPrimaryDestination(context),
                child: Text('back-${widget.destination.name}'),
              ),
            if (widget.navigationHost != null)
              TextButton(
                onPressed: () => widget.navigationHost!.handleDrawerDestination(
                  context,
                  AppDrawerDestination.memos,
                ),
                child: Text('goto-memos-${widget.destination.name}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordingEmbeddedNavigationHost implements HomeEmbeddedNavigationHost {
  int backToPrimaryCount = 0;

  @override
  void handleBackToPrimaryDestination(BuildContext context) {
    backToPrimaryCount++;
  }

  @override
  void handleDrawerDestination(
    BuildContext context,
    AppDrawerDestination destination,
  ) {}

  @override
  void handleDrawerTag(BuildContext context, String tag) {}

  @override
  void handleOpenNotifications(BuildContext context) {}

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {}

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {}
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

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository()
    : _stored = DevicePreferences.defaultsForLanguage(AppLanguage.en),
      super(PreferencesMigrationService(const FlutterSecureStorage()));

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
  _TestDevicePreferencesController(Ref ref)
    : super(ref, _TestDevicePreferencesRepository()) {
    state = DevicePreferences.defaultsForLanguage(AppLanguage.en);
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController({required bool hasAccount})
    : super(
        AsyncValue.data(
          AppSessionState(
            accounts: hasAccount ? [_testAccount] : const <Account>[],
            currentKey: hasAccount ? _testAccountKey : null,
          ),
        ),
      );

  void setHasAccount(bool hasAccount) {
    state = AsyncValue.data(
      AppSessionState(
        accounts: hasAccount ? [_testAccount] : const <Account>[],
        currentKey: hasAccount ? _testAccountKey : null,
      ),
    );
  }

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

class _NoopSyncFacade extends DesktopSyncFacade {
  _NoopSyncFacade() : super(SyncCoordinatorState.initial);

  @override
  void applyRemoteStateSnapshot(SyncCoordinatorState next) {
    state = next;
  }

  @override
  Future<WebDavExportCleanupStatus> cleanWebDavPlainExport() async {
    return WebDavExportCleanupStatus.notFound;
  }

  @override
  Future<WebDavSyncMeta?> cleanWebDavDeprecatedPlainFiles() async {
    return null;
  }

  @override
  Future<WebDavExportStatus> fetchWebDavExportStatus() async {
    return const WebDavExportStatus(
      webDavConfigured: false,
      encSignature: null,
      plainSignature: null,
      plainDetected: false,
      plainDeprecated: false,
      plainDetectedAt: null,
      plainRemindAfter: null,
      lastExportSuccessAt: null,
      lastUploadSuccessAt: null,
    );
  }

  @override
  Future<WebDavSyncMeta?> fetchWebDavSyncMeta() async {
    return null;
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listWebDavBackupSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return const <WebDavBackupSnapshotInfo>[];
  }

  @override
  Future<String> recoverWebDavBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    return '';
  }

  @override
  Future<SyncRunResult> requestSync(SyncRequest request) async {
    return const SyncRunStarted();
  }

  @override
  Future<SyncRunResult> requestWebDavBackup({
    required SyncRequestReason reason,
    String? password,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    return const SyncRunStarted();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<void> resolveLocalScanConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> retryPending() async {}

  @override
  Future<WebDavConnectionTestResult> testWebDavConnection({
    required WebDavSettings settings,
  }) async {
    return const WebDavConnectionTestResult.success();
  }

  @override
  Future<SyncError?> verifyWebDavBackup({
    required String password,
    required bool deep,
  }) async {
    return null;
  }
}

const _testAccountKey = 'account-1';
final _testAccount = Account(
  key: _testAccountKey,
  baseUrl: Uri.parse('https://example.com'),
  personalAccessToken: 'token',
  user: User.empty(),
  instanceProfile: InstanceProfile.empty(),
);
