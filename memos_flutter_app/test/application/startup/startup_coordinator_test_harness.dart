import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/app/app_sync_orchestrator.dart';
import 'package:memos_flutter_app/application/startup/startup_coordinator.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/resolved_app_settings.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/presentation/navigation/app_navigator.dart';
import 'package:memos_flutter_app/state/memos/app_bootstrap_adapter_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

class StartupCoordinatorTestHarness {
  StartupCoordinatorTestHarness({
    required this.coordinator,
    required this.bootstrapAdapter,
    required this.syncOrchestrator,
    required this.navigatorKey,
  });

  final StartupCoordinator coordinator;
  final FakeBootstrapAdapter bootstrapAdapter;
  final FakeAppSyncOrchestrator syncOrchestrator;
  final GlobalKey<NavigatorState> navigatorKey;
}

class TestMemosAppNavigator extends AppNavigator {
  TestMemosAppNavigator(this.navigatorKey) : super(navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  void openAllMemos() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.shrink()),
      ),
      (route) => false,
    );
  }
}

Future<StartupCoordinatorTestHarness> pumpStartupCoordinatorHarness(
  WidgetTester tester, {
  required FakeBootstrapAdapter bootstrapAdapter,
  Route<ShareComposeRequest> Function(SharePayload payload)?
  sharePreviewRouteBuilder,
  ShareQuickClipStartCallback? shareQuickClipStartOverride,
  ShareComposeRequestPresenter? shareComposeRequestPresenterOverride,
  TopToastPresenter? topToastPresenterOverride,
  AppNavigator? appNavigator,
  AppNavigator Function(GlobalKey<NavigatorState> navigatorKey)?
  appNavigatorBuilder,
}) async {
  late WidgetRef ref;
  final navigatorKey = GlobalKey<NavigatorState>();

  LocaleSettings.setLocale(AppLocale.en);
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: Consumer(
          builder: (context, widgetRef, child) {
            ref = widgetRef;
            return MaterialApp(
              navigatorKey: navigatorKey,
              locale: AppLocale.en.flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const Scaffold(body: SizedBox.shrink()),
            );
          },
        ),
      ),
    ),
  );

  final syncOrchestrator = FakeAppSyncOrchestrator(ref);
  final coordinator = StartupCoordinator(
    bootstrapAdapter: bootstrapAdapter,
    syncOrchestrator: syncOrchestrator,
    appNavigator:
        appNavigator ??
        appNavigatorBuilder?.call(navigatorKey) ??
        AppNavigator(navigatorKey),
    navigatorKey: navigatorKey,
    ref: ref,
    isMounted: () => true,
    sharePreviewRouteBuilder: sharePreviewRouteBuilder,
    shareQuickClipStartOverride: shareQuickClipStartOverride,
    shareComposeRequestPresenterOverride: shareComposeRequestPresenterOverride,
    topToastPresenterOverride: topToastPresenterOverride,
  );
  addTearDown(coordinator.dispose);
  return StartupCoordinatorTestHarness(
    coordinator: coordinator,
    bootstrapAdapter: bootstrapAdapter,
    syncOrchestrator: syncOrchestrator,
    navigatorKey: navigatorKey,
  );
}

class FakeBootstrapAdapter extends AppBootstrapAdapter {
  FakeBootstrapAdapter({
    AppPreferences? preferences,
    this.preferencesLoaded = true,
    this.session,
    this.localLibrary,
  }) : preferences = preferences ?? AppPreferences.defaults;

  AppPreferences preferences;
  bool preferencesLoaded;
  AppSessionState? session;
  LocalLibrary? localLibrary;

  DevicePreferences get devicePreferences =>
      DevicePreferences.fromLegacy(preferences);

  WorkspacePreferences get workspacePreferences =>
      WorkspacePreferences.fromLegacy(
        preferences,
        workspaceKey: session?.currentKey ?? localLibrary?.key,
      );

  ResolvedAppSettings get resolvedSettings => ResolvedAppSettings(
    device: devicePreferences,
    workspace: workspacePreferences,
    workspaceKey: session?.currentKey ?? localLibrary?.key,
    hasWorkspace: session?.currentAccount != null || localLibrary != null,
  );

  @override
  DevicePreferences readDevicePreferences(WidgetRef ref) => devicePreferences;

  @override
  bool readDevicePreferencesLoaded(WidgetRef ref) => preferencesLoaded;

  @override
  WorkspacePreferences readWorkspacePreferences(WidgetRef ref) =>
      workspacePreferences;

  @override
  ResolvedAppSettings readResolvedAppSettings(WidgetRef ref) =>
      resolvedSettings;

  @override
  AppSessionState? readSession(WidgetRef ref) => session;

  @override
  LocalLibrary? readCurrentLocalLibrary(WidgetRef ref) => localLibrary;
}

class FakeAppSyncOrchestrator extends AppSyncOrchestrator {
  FakeAppSyncOrchestrator(WidgetRef ref)
    : super(
        ref: ref,
        updateStatsWidgetIfNeeded: ({required bool force}) async {},
        showFeedbackToast: ({required bool succeeded}) {},
        showProgressToast: () {},
      );

  int maybeSyncOnLaunchCount = 0;
  WorkspacePreferences? lastLaunchPrefs;

  @override
  Future<void> maybeSyncOnLaunch(WorkspacePreferences prefs) async {
    maybeSyncOnLaunchCount += 1;
    lastLaunchPrefs = prefs;
  }
}

Account buildTestAccount() {
  return Account(
    key: 'account-key',
    baseUrl: Uri.parse('https://example.com'),
    personalAccessToken: 'token',
    user: const User.empty(),
    instanceProfile: const InstanceProfile.empty(),
  );
}

AppSessionState buildTestSessionWithAccount() {
  return AppSessionState(
    accounts: [buildTestAccount()],
    currentKey: 'account-key',
  );
}

LocalLibrary buildTestLocalLibrary() {
  return const LocalLibrary(key: 'local-key', name: 'Local Library');
}

SharePayload buildPreviewSharePayload() {
  return const SharePayload(
    type: SharePayloadType.text,
    text: 'Interesting Article https://example.com/articles/1',
    title: 'Interesting Article',
  );
}

Route<ShareComposeRequest> buildAutoPopPreviewRoute({
  ShareComposeRequest? result,
}) {
  return PageRouteBuilder<ShareComposeRequest>(
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AutoPopPreviewPage(result: result),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

class _AutoPopPreviewPage extends StatefulWidget {
  const _AutoPopPreviewPage({this.result});

  final ShareComposeRequest? result;

  @override
  State<_AutoPopPreviewPage> createState() => _AutoPopPreviewPageState();
}

class _AutoPopPreviewPageState extends State<_AutoPopPreviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(widget.result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
