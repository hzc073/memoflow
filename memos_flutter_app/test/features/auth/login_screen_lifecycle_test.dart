import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/features/auth/login_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/login_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  int replaceCount = 0;

  void reset() {
    pushCount = 0;
    replaceCount = 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount += 1;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class _LoginTestHost extends StatefulWidget {
  const _LoginTestHost({super.key, required this.observer});

  final NavigatorObserver observer;

  @override
  State<_LoginTestHost> createState() => _LoginTestHostState();
}

class _LoginTestHostState extends State<_LoginTestHost> {
  bool _showLogin = true;

  void hideLogin() {
    setState(() => _showLogin = false);
  }

  @override
  Widget build(BuildContext context) {
    LocaleSettings.setLocale(AppLocale.en);
    return TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [widget.observer],
        home: _showLogin ? const LoginScreen() : const SizedBox.shrink(),
      ),
    );
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController({
    this.passwordCompleter,
    this.passwordError,
    List<Object>? passwordErrors,
    List<Object>? passwordStateErrors,
  }) : _passwordErrors = List<Object>.from(passwordErrors ?? const []),
       _passwordStateErrors = List<Object>.from(passwordStateErrors ?? const []),
       super(
        const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
      );

  final Completer<void>? passwordCompleter;
  final Object? passwordError;
  final List<Object> _passwordErrors;
  final List<Object> _passwordStateErrors;
  int addPasswordCalls = 0;
  int addPatCalls = 0;
  Uri? lastPasswordBaseUrl;
  Uri? lastPatBaseUrl;

  Account _buildAccount({
    required Uri baseUrl,
    required String username,
    required String token,
    String? serverVersionOverride,
  }) {
    return Account(
      key: 'users/1',
      baseUrl: baseUrl,
      personalAccessToken: token,
      user: User(
        name: 'users/1',
        username: username,
        displayName: username,
        avatarUrl: '',
        description: '',
      ),
      instanceProfile: const InstanceProfile.empty(),
      serverVersionOverride: serverVersionOverride,
    );
  }

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {
    addPatCalls += 1;
    lastPatBaseUrl = baseUrl;
    final account = _buildAccount(
      baseUrl: baseUrl,
      username: 'token-user',
      token: personalAccessToken,
      serverVersionOverride: serverVersionOverride,
    );
    state = AsyncValue.data(
      AppSessionState(accounts: [account], currentKey: account.key),
    );
  }

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {
    addPasswordCalls += 1;
    lastPasswordBaseUrl = baseUrl;
    final completer = passwordCompleter;
    if (completer != null) {
      await completer.future;
    }
    if (_passwordErrors.isNotEmpty) {
      throw _passwordErrors.removeAt(0);
    }
    if (_passwordStateErrors.isNotEmpty) {
      state = AsyncValue.error(_passwordStateErrors.removeAt(0), StackTrace.empty);
      return;
    }
    if (passwordError != null) {
      throw passwordError!;
    }
    final account = _buildAccount(
      baseUrl: baseUrl,
      username: username,
      token: 'token',
      serverVersionOverride: serverVersionOverride,
    );
    state = AsyncValue.data(
      AppSessionState(accounts: [account], currentKey: account.key),
    );
  }

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

class _FakeLoginController extends LoginController {
  _FakeLoginController(super.ref, {this.probeCompleter});

  final Completer<LoginProbeReport>? probeCompleter;
  int probeCalls = 0;
  int cleanupCalls = 0;

  @override
  Future<LoginProbeReport> probeSingleVersion({
    required Uri baseUrl,
    required String personalAccessToken,
    required LoginApiVersion version,
    required String probeMemoNotice,
  }) async {
    probeCalls += 1;
    final completer = probeCompleter;
    if (completer != null) {
      return completer.future;
    }
    return const LoginProbeReport(
      passed: true,
      diagnostics: '',
      cleanup: LoginProbeCleanup(hasPending: false),
    );
  }

  @override
  Future<void> cleanupProbeArtifactsAfterSync({
    required LoginApiVersion version,
    required LoginProbeCleanup cleanup,
    required Uri baseUrl,
    required String personalAccessToken,
  }) async {
    cleanupCalls += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder connectButtonFinder(BuildContext context) {
    return find.text(context.t.strings.login.connect.action);
  }

  void prepareViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'password login success callback is ignored after screen disposal',
    (tester) async {
      prepareViewport(tester);
      final observer = _RecordingNavigatorObserver();
      final hostKey = GlobalKey<_LoginTestHostState>();
      final passwordCompleter = Completer<void>();
      final sessionController = _TestSessionController(
        passwordCompleter: passwordCompleter,
      );
      late _FakeLoginController loginController;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            loginControllerProvider.overrideWith(
              (ref) => loginController = _FakeLoginController(ref),
            ),
          ],
          child: _LoginTestHost(key: hostKey, observer: observer),
        ),
      );
      await tester.pumpAndSettle();
      observer.reset();

      final loginContext = tester.element(find.byType(LoginScreen));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'example.com');
      await tester.enterText(fields.at(1), 'user');
      await tester.enterText(fields.at(2), 'secret');

      await tester.tap(connectButtonFinder(loginContext));
      await tester.pump();

      hostKey.currentState!.hideLogin();
      await tester.pump();

      passwordCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sessionController.addPasswordCalls, 1);
      expect(loginController.probeCalls, 0);
      expect(loginController.cleanupCalls, 0);
      expect(observer.pushCount, 0);
      expect(observer.replaceCount, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password login failure callback is ignored after screen disposal',
    (tester) async {
      prepareViewport(tester);
      final observer = _RecordingNavigatorObserver();
      final hostKey = GlobalKey<_LoginTestHostState>();
      final passwordCompleter = Completer<void>();
      final sessionController = _TestSessionController(
        passwordCompleter: passwordCompleter,
        passwordError: StateError('late password failure'),
      );
      late _FakeLoginController loginController;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            loginControllerProvider.overrideWith(
              (ref) => loginController = _FakeLoginController(ref),
            ),
          ],
          child: _LoginTestHost(key: hostKey, observer: observer),
        ),
      );
      await tester.pumpAndSettle();
      observer.reset();

      final loginContext = tester.element(find.byType(LoginScreen));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'example.com');
      await tester.enterText(fields.at(1), 'user');
      await tester.enterText(fields.at(2), 'secret');

      await tester.tap(connectButtonFinder(loginContext));
      await tester.pump();

      hostKey.currentState!.hideLogin();
      await tester.pump();

      passwordCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sessionController.addPasswordCalls, 1);
      expect(loginController.probeCalls, 0);
      expect(loginController.cleanupCalls, 0);
      expect(observer.pushCount, 0);
      expect(observer.replaceCount, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('token probe ignores late callback after screen disposal', (
    tester,
  ) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final hostKey = GlobalKey<_LoginTestHostState>();
    final probeCompleter = Completer<LoginProbeReport>();
    final sessionController = _TestSessionController();
    late _FakeLoginController loginController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => loginController = _FakeLoginController(
              ref,
              probeCompleter: probeCompleter,
            ),
          ),
        ],
        child: _LoginTestHost(key: hostKey, observer: observer),
      ),
    );
    await tester.pumpAndSettle();
    observer.reset();

    final loginContext = tester.element(find.byType(LoginScreen));
    await tester.tap(find.text(loginContext.t.strings.login.mode.token));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'example.com');
    await tester.enterText(fields.at(1), 'token');

    await tester.tap(connectButtonFinder(loginContext));
    await tester.pump();

    hostKey.currentState!.hideLogin();
    await tester.pump();

    probeCompleter.complete(
      const LoginProbeReport(
        passed: true,
        diagnostics: '',
        cleanup: LoginProbeCleanup(hasPending: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(loginController.probeCalls, 1);
    expect(loginController.cleanupCalls, 0);
    expect(sessionController.addPatCalls, 0);
    expect(observer.pushCount, 0);
    expect(observer.replaceCount, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling insecure protocol dialog keeps https', (tester) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final sessionController = _TestSessionController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => _FakeLoginController(ref),
          ),
        ],
        child: _LoginTestHost(observer: observer),
      ),
    );
    await tester.pumpAndSettle();

    final loginContext = tester.element(find.byType(LoginScreen));
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    expect(
      find.text(loginContext.t.strings.login.dialogs.insecureHttpTitle),
      findsOneWidget,
    );

    await tester.tap(find.text(loginContext.t.strings.common.cancel));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'example.com');
    await tester.enterText(fields.at(1), 'user');
    await tester.enterText(fields.at(2), 'secret');

    await tester.tap(connectButtonFinder(loginContext));
    await tester.pumpAndSettle();

    expect(sessionController.addPasswordCalls, 1);
    expect(sessionController.lastPasswordBaseUrl?.scheme, 'https');
    expect(sessionController.lastPasswordBaseUrl?.host, 'example.com');
  });

  testWidgets('confirming insecure protocol dialog switches to http', (
    tester,
  ) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final sessionController = _TestSessionController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => _FakeLoginController(ref),
          ),
        ],
        child: _LoginTestHost(observer: observer),
      ),
    );
    await tester.pumpAndSettle();

    final loginContext = tester.element(find.byType(LoginScreen));
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text(loginContext.t.strings.common.confirm));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'example.com');
    await tester.enterText(fields.at(1), 'user');
    await tester.enterText(fields.at(2), 'secret');

    await tester.tap(connectButtonFinder(loginContext));
    await tester.pumpAndSettle();

    expect(sessionController.addPasswordCalls, 1);
    expect(sessionController.lastPasswordBaseUrl?.scheme, 'http');
    expect(sessionController.lastPasswordBaseUrl?.host, 'example.com');
  });

  testWidgets('http switch hint stays visible and updates with protocol', (
    tester,
  ) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final sessionController = _TestSessionController();
    const protocolHint =
        'Use the shield icon on the right to switch connection protocols.';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => _FakeLoginController(ref),
          ),
        ],
        child: _LoginTestHost(observer: observer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(protocolHint), findsOneWidget);

    final loginContext = tester.element(find.byType(LoginScreen));
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loginContext.t.strings.common.confirm));
    await tester.pumpAndSettle();

    expect(find.text(protocolHint), findsOneWidget);
  });

  testWidgets('server url prefix reflects protocol toggle', (tester) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final sessionController = _TestSessionController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => _FakeLoginController(ref),
          ),
        ],
        child: _LoginTestHost(observer: observer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://'), findsOneWidget);
    expect(find.text('http://'), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.tap(fields.at(1));
    await tester.pumpAndSettle();

    expect(find.text('https://'), findsOneWidget);
    expect(find.text('http://'), findsNothing);

    final loginContext = tester.element(find.byType(LoginScreen));
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loginContext.t.strings.common.confirm));
    await tester.pumpAndSettle();

    expect(find.text('https://'), findsNothing);
    expect(find.text('http://'), findsOneWidget);

    await tester.tap(fields.at(1));
    await tester.pumpAndSettle();

    expect(find.text('https://'), findsNothing);
    expect(find.text('http://'), findsOneWidget);
  });

  testWidgets('https handshake failure dialog can switch protocol to http', (
    tester,
  ) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final sessionController = _TestSessionController(
      passwordErrors: [
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/signin'),
          type: DioExceptionType.connectionError,
          message: 'HandshakeException: Connection terminated during handshake',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => _FakeLoginController(ref),
          ),
        ],
        child: _LoginTestHost(observer: observer),
      ),
    );
    await tester.pumpAndSettle();

    final loginContext = tester.element(find.byType(LoginScreen));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'example.com');
    await tester.enterText(fields.at(1), 'user');
    await tester.enterText(fields.at(2), 'secret');

    await tester.tap(connectButtonFinder(loginContext));
    await tester.pumpAndSettle();

    expect(
      find.text(loginContext.t.strings.login.dialogs.httpsHandshakeFailedTitle),
      findsOneWidget,
    );
    expect(
      find.text(loginContext.t.strings.login.dialogs.switchToHttp),
      findsOneWidget,
    );

    await tester.tap(
      find.text(loginContext.t.strings.login.dialogs.switchToHttp),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://'), findsNothing);
    expect(find.text('http://'), findsOneWidget);

    expect(sessionController.addPasswordCalls, 2);
    expect(sessionController.lastPasswordBaseUrl?.scheme, 'http');
    expect(sessionController.lastPasswordBaseUrl?.host, 'example.com');
  });

  testWidgets('session state handshake failure dialog can switch protocol', (
    tester,
  ) async {
    prepareViewport(tester);
    final observer = _RecordingNavigatorObserver();
    final sessionController = _TestSessionController(
      passwordStateErrors: [
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/signin'),
          type: DioExceptionType.unknown,
          error: 'HandshakeException: Connection terminated during handshake',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          loginControllerProvider.overrideWith(
            (ref) => _FakeLoginController(ref),
          ),
        ],
        child: _LoginTestHost(observer: observer),
      ),
    );
    await tester.pumpAndSettle();

    final loginContext = tester.element(find.byType(LoginScreen));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'example.com');
    await tester.enterText(fields.at(1), 'user');
    await tester.enterText(fields.at(2), 'secret');

    await tester.tap(connectButtonFinder(loginContext));
    await tester.pumpAndSettle();

    expect(
      find.text(loginContext.t.strings.login.dialogs.httpsHandshakeFailedTitle),
      findsOneWidget,
    );

    await tester.tap(
      find.text(loginContext.t.strings.login.dialogs.switchToHttp),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://'), findsNothing);
    expect(find.text('http://'), findsOneWidget);
    expect(sessionController.addPasswordCalls, 2);
    expect(sessionController.lastPasswordBaseUrl?.scheme, 'http');
    expect(sessionController.lastPasswordBaseUrl?.host, 'example.com');
  });
}
