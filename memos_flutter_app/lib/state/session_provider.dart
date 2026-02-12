import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api/memos_api.dart';
import '../data/logs/log_manager.dart';
import '../data/models/account.dart';
import '../data/models/instance_profile.dart';
import '../data/models/user.dart';
import '../data/settings/accounts_repository.dart';
import '../core/url.dart';

class AppSessionState {
  const AppSessionState({required this.accounts, required this.currentKey});

  final List<Account> accounts;
  final String? currentKey;

  Account? get currentAccount {
    final key = currentKey;
    if (key == null) return null;
    for (final a in accounts) {
      if (a.key == key) return a;
    }
    return null;
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(secureStorageProvider));
});

final appSessionProvider =
    StateNotifierProvider<AppSessionController, AsyncValue<AppSessionState>>((
      ref,
    ) {
      return AppSessionNotifier(ref.watch(accountsRepositoryProvider));
    });

abstract class AppSessionController
    extends StateNotifier<AsyncValue<AppSessionState>> {
  AppSessionController(super.state);

  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
  });

  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
  });

  Future<void> setCurrentKey(String? key);

  Future<void> switchAccount(String accountKey);

  Future<void> switchWorkspace(String workspaceKey);

  Future<void> removeAccount(String accountKey);

  Future<void> refreshCurrentUser({bool ignoreErrors = true});

  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  });

  Future<void> setCurrentAccountUseLegacyApiOverride(bool value);
}

class AppSessionNotifier extends AppSessionController {
  AppSessionNotifier(this._accountsRepository)
    : super(const AsyncValue.loading()) {
    _loadFromStorage();
  }

  static final RegExp _versionPattern = RegExp(r'(\d+)\.(\d+)\.(\d+)');
  static final RegExp _instanceVersionPattern = RegExp(r'(\d+)\.(\d+)\.(\d+)');

  @override
  Future<void> setCurrentKey(String? key) async {
    final current =
        state.valueOrNull ??
        const AppSessionState(accounts: [], currentKey: null);
    final trimmed = key?.trim();
    final nextKey = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(
        AccountsState(accounts: current.accounts, currentKey: nextKey),
      );
      return AppSessionState(accounts: current.accounts, currentKey: nextKey);
    });
  }

  final AccountsRepository _accountsRepository;

  Future<void> _loadFromStorage() async {
    final stored = await _accountsRepository.read();
    state = AsyncValue.data(
      AppSessionState(accounts: stored.accounts, currentKey: stored.currentKey),
    );
  }

  Future<AppSessionState> _upsertAccount({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
  }) async {
    InstanceProfile instanceProfile;
    try {
      instanceProfile = await MemosApi.unauthenticated(
        baseUrl,
        logManager: LogManager.instance,
      ).getInstanceProfile();
    } catch (_) {
      instanceProfile = const InstanceProfile.empty();
    }

    final user = await MemosApi.authenticated(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      logManager: LogManager.instance,
    ).getCurrentUser();

    if (instanceProfile.version.trim().isEmpty) {
      try {
        instanceProfile = await MemosApi.authenticated(
          baseUrl: baseUrl,
          personalAccessToken: personalAccessToken,
          logManager: LogManager.instance,
        ).getInstanceProfile();
      } catch (_) {}
    }

    final normalizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    final accountKey =
        '${canonicalBaseUrlString(normalizedBaseUrl)}|${user.name}';

    final current =
        state.valueOrNull ??
        const AppSessionState(accounts: [], currentKey: null);
    final accounts = [...current.accounts];
    final existingIndex = accounts.indexWhere((a) => a.key == accountKey);
    final resolvedUseLegacyApiOverride =
        useLegacyApiOverride ??
        (existingIndex >= 0
            ? accounts[existingIndex].useLegacyApiOverride
            : null);

    final account = Account(
      key: accountKey,
      baseUrl: normalizedBaseUrl,
      personalAccessToken: personalAccessToken,
      user: user,
      instanceProfile: instanceProfile,
      useLegacyApiOverride: resolvedUseLegacyApiOverride,
    );
    if (existingIndex >= 0) {
      accounts[existingIndex] = account;
    } else {
      accounts.add(account);
    }

    await _accountsRepository.write(
      AccountsState(accounts: accounts, currentKey: accountKey),
    );
    return AppSessionState(accounts: accounts, currentKey: accountKey);
  }

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
  }) async {
    // Keep the previous state while connecting so the login form doesn't reset.
    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return _upsertAccount(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        useLegacyApiOverride: useLegacyApiOverride,
      );
    });
  }

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
  }) async {
    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final loginStrategy = await _resolvePasswordLoginStrategy(
        baseUrl: baseUrl,
        useLegacyApiPreference: useLegacyApi,
      );
      final signIn = await _signInWithPassword(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useLegacyApi: loginStrategy.useLegacyApi,
        flavor: loginStrategy.flavor,
      );
      final token = await _createTokenFromPasswordSignIn(
        baseUrl: baseUrl,
        signIn: signIn,
        useLegacyApi: loginStrategy.useLegacyApi,
      );
      return _upsertAccount(
        baseUrl: baseUrl,
        personalAccessToken: token,
        useLegacyApiOverride: loginStrategy.useLegacyApi,
      );
    });
  }

  @override
  Future<void> switchAccount(String accountKey) async {
    final current =
        state.valueOrNull ??
        const AppSessionState(accounts: [], currentKey: null);
    if (!current.accounts.any((a) => a.key == accountKey)) return;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(
        AccountsState(accounts: current.accounts, currentKey: accountKey),
      );
      return AppSessionState(
        accounts: current.accounts,
        currentKey: accountKey,
      );
    });
  }

  @override
  Future<void> switchWorkspace(String workspaceKey) async {
    final current =
        state.valueOrNull ??
        const AppSessionState(accounts: [], currentKey: null);
    final key = workspaceKey.trim();
    if (key.isEmpty) return;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(
        AccountsState(accounts: current.accounts, currentKey: key),
      );
      return AppSessionState(accounts: current.accounts, currentKey: key);
    });
  }

  @override
  Future<void> removeAccount(String accountKey) async {
    final current =
        state.valueOrNull ??
        const AppSessionState(accounts: [], currentKey: null);
    final accounts = current.accounts
        .where((a) => a.key != accountKey)
        .toList(growable: false);
    final nextKey = current.currentKey == accountKey
        ? (accounts.firstOrNull?.key)
        : current.currentKey;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(
        AccountsState(accounts: accounts, currentKey: nextKey),
      );
      return AppSessionState(accounts: accounts, currentKey: nextKey);
    });
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final account = current.currentAccount;
    if (account == null) return;

    final useLegacyApi = resolveUseLegacyApiForAccount(
      account: account,
      globalDefault: true,
    );

    try {
      final api = MemosApi.authenticated(
        baseUrl: account.baseUrl,
        personalAccessToken: account.personalAccessToken,
        useLegacyApi: useLegacyApi,
        logManager: LogManager.instance,
      );
      final user = await api.getCurrentUser();
      var instanceProfile = account.instanceProfile;
      if (instanceProfile.version.trim().isEmpty) {
        try {
          instanceProfile = await api.getInstanceProfile();
        } catch (_) {}
      }

      final updatedAccount = Account(
        key: account.key,
        baseUrl: account.baseUrl,
        personalAccessToken: account.personalAccessToken,
        user: user,
        instanceProfile: instanceProfile,
        useLegacyApiOverride: account.useLegacyApiOverride,
      );
      final accounts = current.accounts
          .map((a) => a.key == account.key ? updatedAccount : a)
          .toList(growable: false);
      final next = AppSessionState(
        accounts: accounts,
        currentKey: current.currentKey,
      );
      state = AsyncValue.data(next);
      await _accountsRepository.write(
        AccountsState(accounts: accounts, currentKey: current.currentKey),
      );
    } catch (e) {
      if (!ignoreErrors) rethrow;
    }
  }

  bool _shouldUseLegacyApiForAccount(Account account) {
    final versionRaw = account.instanceProfile.version.trim();
    final match = _versionPattern.firstMatch(versionRaw);
    if (match == null) {
      return true;
    }

    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '');
    if (major == null || minor == null || patch == null) {
      return true;
    }

    if (major == 0 && minor <= 22) {
      return true;
    }
    return false;
  }

  Future<_PasswordLoginStrategy> _resolvePasswordLoginStrategy({
    required Uri baseUrl,
    required bool useLegacyApiPreference,
  }) async {
    InstanceProfile profile;
    try {
      profile = await MemosApi.unauthenticated(
        baseUrl,
        logManager: LogManager.instance,
      ).getInstanceProfile();
    } catch (_) {
      return _PasswordLoginStrategy(
        useLegacyApi: useLegacyApiPreference,
        flavor: _inferFlavorFromVersion(''),
      );
    }

    final flavor = _inferFlavorFromVersion(profile.version);
    final useLegacyApi = switch (flavor) {
      _DetectedServerFlavor.v0_21 || _DetectedServerFlavor.v0_22 => true,
      _DetectedServerFlavor.v0_24 || _DetectedServerFlavor.v0_25Plus => false,
      _DetectedServerFlavor.unknown => useLegacyApiPreference,
    };

    LogManager.instance.info(
      'Password sign-in strategy resolved',
      context: <String, Object?>{
        'baseUrl': canonicalBaseUrlString(baseUrl),
        'versionRaw': profile.version,
        'flavor': flavor.name,
        'useLegacyApi': useLegacyApi,
        'source': 'instanceProfile',
      },
    );

    return _PasswordLoginStrategy(useLegacyApi: useLegacyApi, flavor: flavor);
  }

  _DetectedServerFlavor _inferFlavorFromVersion(String versionRaw) {
    final trimmed = versionRaw.trim();
    final match = _instanceVersionPattern.firstMatch(trimmed);
    if (match == null) return _DetectedServerFlavor.unknown;

    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    if (major == null || minor == null) return _DetectedServerFlavor.unknown;
    if (major != 0) return _DetectedServerFlavor.v0_25Plus;
    if (minor >= 25) return _DetectedServerFlavor.v0_25Plus;
    if (minor >= 24) return _DetectedServerFlavor.v0_24;
    if (minor >= 22) return _DetectedServerFlavor.v0_22;
    return _DetectedServerFlavor.v0_21;
  }

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) {
    final override = account.useLegacyApiOverride;
    if (override != null) {
      return override;
    }
    final versionRaw = account.instanceProfile.version.trim();
    if (versionRaw.isEmpty) {
      return globalDefault;
    }
    return _shouldUseLegacyApiForAccount(account);
  }

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {
    final current = state.valueOrNull;
    final account = current?.currentAccount;
    if (current == null || account == null) {
      return;
    }
    if (account.useLegacyApiOverride == value) {
      return;
    }

    final updatedAccount = Account(
      key: account.key,
      baseUrl: account.baseUrl,
      personalAccessToken: account.personalAccessToken,
      user: account.user,
      instanceProfile: account.instanceProfile,
      useLegacyApiOverride: value,
    );
    final accounts = current.accounts
        .map((a) => a.key == account.key ? updatedAccount : a)
        .toList(growable: false);
    final next = AppSessionState(
      accounts: accounts,
      currentKey: current.currentKey,
    );

    state = AsyncValue.data(next);
    await _accountsRepository.write(
      AccountsState(accounts: accounts, currentKey: current.currentKey),
    );
  }

  Future<_PasswordSignInResult> _signInWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    required _DetectedServerFlavor flavor,
  }) async {
    final usernameCandidates = _buildSignInUsernameCandidates(username);
    LogManager.instance.info(
      'Password sign-in start',
      context: <String, Object?>{
        'baseUrl': canonicalBaseUrlString(baseUrl),
        'mode': useLegacyApi ? 'legacy' : 'new',
        'usernameCandidateCount': usernameCandidates.length,
      },
    );

    for (
      var candidateIndex = 0;
      candidateIndex < usernameCandidates.length;
      candidateIndex++
    ) {
      final signInUsername = usernameCandidates[candidateIndex];
      final hasNextCandidate = candidateIndex < usernameCandidates.length - 1;

      final attempts = _buildPasswordSignInAttempts(
        baseUrl: baseUrl,
        username: signInUsername,
        password: password,
        useLegacyApi: useLegacyApi,
        flavor: flavor,
      );

      DioException? lastNonFallback;
      DioException? lastFallback;
      FormatException? lastFormat;
      Object? lastOtherError;

      for (final attempt in attempts) {
        try {
          LogManager.instance.debug(
            'Password sign-in attempt',
            context: <String, Object?>{'endpoint': attempt.endpoint.label},
          );
          final result = await attempt.run();
          LogManager.instance.info(
            'Password sign-in success',
            context: <String, Object?>{
              'endpoint': attempt.endpoint.label,
              'user': result.user.name,
              'hasSessionCookie': result.sessionCookie?.isNotEmpty ?? false,
              'hasAccessToken': result.accessToken?.isNotEmpty ?? false,
            },
          );
          return result;
        } on DioException catch (e) {
          LogManager.instance.warn(
            'Password sign-in failed',
            error: e,
            context: <String, Object?>{
              'endpoint': attempt.endpoint.label,
              'status': e.response?.statusCode,
              'message': _extractDioMessage(e),
              'url': e.requestOptions.uri.toString(),
              'fallback': _shouldFallback(e),
            },
          );
          if (_shouldFallback(e)) {
            lastFallback = e;
            continue;
          }
          lastNonFallback = e;
        } on FormatException catch (e) {
          LogManager.instance.warn(
            'Password sign-in failed',
            error: e,
            context: <String, Object?>{
              'endpoint': attempt.endpoint.label,
              'format': e.message,
            },
          );
          lastFormat = e;
        } catch (e, stackTrace) {
          LogManager.instance.error(
            'Password sign-in failed',
            error: e,
            stackTrace: stackTrace,
            context: <String, Object?>{'endpoint': attempt.endpoint.label},
          );
          lastOtherError = e;
        }
      }

      final candidateError =
          lastNonFallback ?? lastOtherError ?? lastFallback ?? lastFormat;

      if (hasNextCandidate &&
          candidateError is DioException &&
          _shouldTryNextUsernameCandidate(candidateError)) {
        LogManager.instance.warn(
          'Password sign-in retry with normalized username',
          context: <String, Object?>{
            'candidateIndex': candidateIndex + 2,
            'candidateCount': usernameCandidates.length,
          },
        );
        continue;
      }

      if (candidateError != null) throw candidateError;
    }

    throw StateError('Unable to sign in');
  }

  Future<_PasswordSignInResult> _signInSessions({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      connectTimeout: _kLoginConnectTimeout,
      receiveTimeout: _kLoginReceiveTimeout,
    );
    final response = await dio.post(
      'api/v1/auth/sessions',
      data: {
        'passwordCredentials': {'username': username, 'password': password},
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final sessionValue = _extractCookieValue(
      response.headers,
      _kSessionCookieName,
    );
    if (sessionValue == null || sessionValue.isEmpty) {
      throw const FormatException('Session cookie missing in response');
    }
    final sessionCookie = '$_kSessionCookieName=$sessionValue';
    return _PasswordSignInResult(
      user: user,
      endpoint: _PasswordSignInEndpoint.sessionV1,
      sessionCookie: sessionCookie,
    );
  }

  Future<_PasswordSignInResult> _signInGrpcWeb({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final request = _encodeCreateSessionRequest(
      username: username,
      password: password,
    );
    final response = await _grpcWebPost(
      baseUrl: baseUrl,
      path: _kGrpcWebCreateSessionPath,
      data: request,
    );
    final message = _parseGrpcWebResponse(response.bytes);
    final user = _parseCreateSessionUser(message.messageBytes);

    final sessionValue = _extractCookieValue(
      response.headers,
      _kSessionCookieName,
    );
    if (sessionValue == null || sessionValue.isEmpty) {
      throw const FormatException('Session cookie missing in response');
    }
    final sessionCookie = '$_kSessionCookieName=$sessionValue';
    return _PasswordSignInResult(
      user: user,
      endpoint: _PasswordSignInEndpoint.grpcWebSessionV1,
      sessionCookie: sessionCookie,
    );
  }

  Future<_PasswordSignInResult> _signInV1({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
  }) async {
    if (useLegacyApi) {
      return _signInV1Legacy(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );
    }

    try {
      return await _signInV1Modern(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );
    } on DioException catch (e) {
      if (!_shouldFallbackV1Payload(e)) {
        rethrow;
      }
    } on FormatException {
      // Fallback to legacy payload below.
    }
    return _signInV1Legacy(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  Future<_PasswordSignInResult> _signInV1Legacy({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      connectTimeout: _kLoginConnectTimeout,
      receiveTimeout: _kLoginReceiveTimeout,
    );
    final response = await dio.post(
      'api/v1/auth/signin',
      queryParameters: <String, Object?>{
        'username': username,
        'password': password,
        'neverExpire': false,
        'never_expire': false,
      },
      data: <String, Object?>{
        'username': username,
        'password': password,
        'neverExpire': false,
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractCookieValue(response.headers, _kAccessTokenCookieName);
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return _PasswordSignInResult(
      user: user,
      endpoint: _PasswordSignInEndpoint.signinV1,
      accessToken: token,
    );
  }

  Future<_PasswordSignInResult> _signInV1Modern({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      connectTimeout: _kLoginConnectTimeout,
      receiveTimeout: _kLoginReceiveTimeout,
    );
    final response = await dio.post(
      'api/v1/auth/signin',
      data: {
        'passwordCredentials': {'username': username, 'password': password},
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractCookieValue(response.headers, _kAccessTokenCookieName);
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return _PasswordSignInResult(
      user: user,
      endpoint: _PasswordSignInEndpoint.signinV1,
      accessToken: token,
    );
  }

  Future<_PasswordSignInResult> _signInV2({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(
      baseUrl,
      connectTimeout: _kLoginConnectTimeout,
      receiveTimeout: _kLoginReceiveTimeout,
    );
    final response = await dio.post(
      'api/v2/auth/signin',
      data: {'username': username, 'password': password, 'neverExpire': false},
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractCookieValue(response.headers, _kAccessTokenCookieName);
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return _PasswordSignInResult(
      user: user,
      endpoint: _PasswordSignInEndpoint.signinV2,
      accessToken: token,
    );
  }

  List<_PasswordSignInAttempt> _buildPasswordSignInAttempts({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    required _DetectedServerFlavor flavor,
  }) {
    _PasswordSignInAttempt grpcWeb() => _PasswordSignInAttempt(
      _PasswordSignInEndpoint.grpcWebSessionV1,
      () => _signInGrpcWeb(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
    );

    _PasswordSignInAttempt sessionsV1() => _PasswordSignInAttempt(
      _PasswordSignInEndpoint.sessionV1,
      () => _signInSessions(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
    );

    _PasswordSignInAttempt signinV1() => _PasswordSignInAttempt(
      _PasswordSignInEndpoint.signinV1,
      () => _signInV1(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useLegacyApi: useLegacyApi,
      ),
    );

    _PasswordSignInAttempt signinV2() => _PasswordSignInAttempt(
      _PasswordSignInEndpoint.signinV2,
      () => _signInV2(baseUrl: baseUrl, username: username, password: password),
    );

    return switch (flavor) {
      _DetectedServerFlavor.v0_25Plus => <_PasswordSignInAttempt>[
        grpcWeb(),
        sessionsV1(),
        signinV1(),
        signinV2(),
      ],
      _DetectedServerFlavor.v0_24 => <_PasswordSignInAttempt>[
        grpcWeb(),
        signinV1(),
        signinV2(),
        sessionsV1(),
      ],
      _DetectedServerFlavor.v0_22 => <_PasswordSignInAttempt>[
        grpcWeb(),
        signinV1(),
        signinV2(),
        sessionsV1(),
      ],
      _DetectedServerFlavor.v0_21 => <_PasswordSignInAttempt>[
        grpcWeb(),
        signinV2(),
        signinV1(),
        sessionsV1(),
      ],
      _DetectedServerFlavor.unknown =>
        useLegacyApi
            ? <_PasswordSignInAttempt>[
                grpcWeb(),
                signinV2(),
                sessionsV1(),
                signinV1(),
              ]
            : <_PasswordSignInAttempt>[
                grpcWeb(),
                sessionsV1(),
                signinV1(),
                signinV2(),
              ],
    };
  }

  Future<String> _createTokenFromPasswordSignIn({
    required Uri baseUrl,
    required _PasswordSignInResult signIn,
    required bool useLegacyApi,
  }) async {
    final description = _kPasswordLoginTokenDescription;
    final userName = signIn.user.name;

    Future<String> createViaApi(MemosApi api) {
      return api.createUserAccessToken(
        userName: userName,
        description: description,
        expiresInDays: 0,
      );
    }

    if (signIn.sessionCookie != null) {
      try {
        LogManager.instance.debug(
          'Create access token (grpc-web)',
          context: <String, Object?>{
            'baseUrl': canonicalBaseUrlString(baseUrl),
            'user': userName,
          },
        );
        return await _createUserAccessTokenGrpcWeb(
          baseUrl: baseUrl,
          sessionCookie: signIn.sessionCookie!,
          userName: userName,
          description: description,
        );
      } on DioException catch (e) {
        LogManager.instance.warn(
          'Create access token failed (grpc-web)',
          error: e,
          context: <String, Object?>{
            'status': e.response?.statusCode,
            'message': _extractDioMessage(e),
            'url': e.requestOptions.uri.toString(),
          },
        );
      } on FormatException catch (e) {
        LogManager.instance.warn(
          'Create access token failed (grpc-web)',
          error: e,
          context: <String, Object?>{'format': e.message},
        );
      }

      final api = MemosApi.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: signIn.sessionCookie!,
        useLegacyApi: useLegacyApi,
        logManager: LogManager.instance,
      );
      try {
        LogManager.instance.debug(
          'Create access token (session)',
          context: <String, Object?>{
            'baseUrl': canonicalBaseUrlString(baseUrl),
            'user': userName,
          },
        );
        return await createViaApi(api);
      } on DioException catch (e) {
        LogManager.instance.warn(
          'Create access token failed (session)',
          error: e,
          context: <String, Object?>{
            'status': e.response?.statusCode,
            'message': _extractDioMessage(e),
            'url': e.requestOptions.uri.toString(),
          },
        );
        if (!_shouldFallback(e)) rethrow;
      }
    }

    final token = signIn.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token for access token creation');
    }

    try {
      final api = MemosApi.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: token,
        useLegacyApi: useLegacyApi,
        logManager: LogManager.instance,
      );
      LogManager.instance.debug(
        'Create access token (bearer)',
        context: <String, Object?>{
          'baseUrl': canonicalBaseUrlString(baseUrl),
          'user': userName,
        },
      );
      return await createViaApi(api);
    } on DioException catch (e) {
      LogManager.instance.warn(
        'Create access token failed (bearer)',
        error: e,
        context: <String, Object?>{
          'status': e.response?.statusCode,
          'message': _extractDioMessage(e),
          'url': e.requestOptions.uri.toString(),
        },
      );
      if (!_shouldFallback(e)) rethrow;
    } on UnsupportedError {
      // Ignore and try v2 fallback below.
    }

    LogManager.instance.warn(
      'Create access token fallback to v2',
      context: <String, Object?>{
        'baseUrl': canonicalBaseUrlString(baseUrl),
        'user': userName,
      },
    );
    return _createPersonalAccessTokenV2(
      baseUrl: baseUrl,
      userName: userName,
      accessToken: token,
      description: description,
      expiresInDays: 0,
    );
  }

  Future<String> _createPersonalAccessTokenV2({
    required Uri baseUrl,
    required String userName,
    required String accessToken,
    required String description,
    required int expiresInDays,
  }) async {
    final dio = _newDio(
      baseUrl,
      headers: {'Authorization': 'Bearer $accessToken'},
      connectTimeout: _kLoginConnectTimeout,
      receiveTimeout: _kLoginReceiveTimeout,
    );
    final expiresAt = expiresInDays > 0
        ? DateTime.now().toUtc().add(Duration(days: expiresInDays))
        : null;
    final path = userName.startsWith('users/')
        ? 'api/v2/$userName/access_tokens'
        : 'api/v2/users/$userName/access_tokens';
    final response = await dio.post(
      path,
      data: <String, Object?>{
        'description': description,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      },
    );
    final body = _expectJsonMap(response.data);
    final tokenJson = body['accessToken'] ?? body['access_token'];
    if (tokenJson is Map) {
      final tokenValue = _readString(
        tokenJson['accessToken'] ?? tokenJson['access_token'],
      );
      if (tokenValue.isNotEmpty) return tokenValue;
    }
    final tokenValue = _readString(body['accessToken'] ?? body['access_token']);
    if (tokenValue.isEmpty) {
      throw const FormatException('Token missing in response');
    }
    return tokenValue;
  }

  Future<String> _createUserAccessTokenGrpcWeb({
    required Uri baseUrl,
    required String sessionCookie,
    required String userName,
    required String description,
  }) async {
    final normalizedUser = userName.startsWith('users/')
        ? userName
        : 'users/$userName';
    final request = _encodeCreateUserAccessTokenRequest(
      parent: normalizedUser,
      description: description,
    );
    final response = await _grpcWebPost(
      baseUrl: baseUrl,
      path: _kGrpcWebCreateUserAccessTokenPath,
      data: request,
      headers: <String, String>{'Cookie': sessionCookie},
    );
    final message = _parseGrpcWebResponse(response.bytes);
    final token = _parseUserAccessToken(message.messageBytes);
    if (token.isEmpty) {
      throw const FormatException('Token missing in response');
    }
    return token;
  }
}

extension _FirstOrNullAccountExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum _PasswordSignInEndpoint { grpcWebSessionV1, sessionV1, signinV1, signinV2 }

class _PasswordSignInAttempt {
  const _PasswordSignInAttempt(this.endpoint, this.run);

  final _PasswordSignInEndpoint endpoint;
  final Future<_PasswordSignInResult> Function() run;
}

class _PasswordSignInResult {
  const _PasswordSignInResult({
    required this.user,
    required this.endpoint,
    this.accessToken,
    this.sessionCookie,
  });

  final User user;
  final _PasswordSignInEndpoint endpoint;
  final String? accessToken;
  final String? sessionCookie;
}

class _PasswordLoginStrategy {
  const _PasswordLoginStrategy({
    required this.useLegacyApi,
    required this.flavor,
  });

  final bool useLegacyApi;
  final _DetectedServerFlavor flavor;
}

enum _DetectedServerFlavor { unknown, v0_25Plus, v0_24, v0_22, v0_21 }

const String _kPasswordLoginTokenDescription = 'MemoFlow (password login)';
const String _kAccessTokenCookieName = 'memos.access-token';
const String _kSessionCookieName = 'user_session';
const String _kGrpcWebContentType = 'application/grpc-web+proto';
const String _kGrpcWebCreateSessionPath =
    '/memos.api.v1.AuthService/CreateSession';
const String _kGrpcWebCreateUserAccessTokenPath =
    '/memos.api.v1.UserService/CreateUserAccessToken';
const Duration _kLoginConnectTimeout = Duration(seconds: 20);
const Duration _kLoginReceiveTimeout = Duration(seconds: 30);

Dio _newDio(
  Uri baseUrl, {
  Map<String, Object?>? headers,
  Duration? connectTimeout,
  Duration? receiveTimeout,
}) {
  return Dio(
    BaseOptions(
      baseUrl: dioBaseUrlString(baseUrl),
      connectTimeout: connectTimeout ?? const Duration(seconds: 10),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 20),
      headers: headers,
    ),
  );
}

bool _shouldFallback(DioException e) {
  final status = e.response?.statusCode ?? 0;
  return status == 404 || status == 405;
}

bool _shouldFallbackV1Payload(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }
  return status == 400 || status == 404 || status == 405;
}

List<String> _buildSignInUsernameCandidates(String username) {
  final raw = username.trim();
  if (raw.isEmpty) return const <String>[];

  final candidates = <String>[raw];
  void add(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    if (!candidates.contains(normalized)) {
      candidates.add(normalized);
    }
  }

  if (raw.startsWith('users/') && raw.length > 'users/'.length) {
    add(raw.substring('users/'.length));
  }
  final slashIndex = raw.lastIndexOf('/');
  if (slashIndex > 0 && slashIndex < raw.length - 1) {
    add(raw.substring(slashIndex + 1));
  }
  final atIndex = raw.indexOf('@');
  if (atIndex > 0) {
    add(raw.substring(0, atIndex));
  }
  add(raw.toLowerCase());
  return candidates;
}

bool _shouldTryNextUsernameCandidate(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return false;
  if (status != 400 && status != 401) return false;
  final message = _extractDioMessage(e).toLowerCase();
  if (message.isEmpty) return false;
  return message.contains('user not found') ||
      message.contains('unmatched username') ||
      message.contains('unmatched email') ||
      message.contains('incorrect login credentials');
}

String _extractDioMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final message = data['message'] ?? data['error'] ?? data['detail'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  } else if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String? _extractCookieValue(Headers headers, String name) {
  final values = <String>[
    ...?headers.map['set-cookie'],
    ...?headers.map['grpc-metadata-set-cookie'],
  ];
  if (values.isEmpty) return null;
  for (final entry in values) {
    final parts = entry.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$name=')) {
        return trimmed.substring(name.length + 1).trim();
      }
    }
  }
  return null;
}

extension _PasswordSignInEndpointLabel on _PasswordSignInEndpoint {
  String get label => switch (this) {
    _PasswordSignInEndpoint.grpcWebSessionV1 => 'grpc-web/CreateSession',
    _PasswordSignInEndpoint.sessionV1 => 'v1/auth/sessions',
    _PasswordSignInEndpoint.signinV1 => 'v1/auth/signin',
    _PasswordSignInEndpoint.signinV2 => 'v2/auth/signin',
  };
}

String? _extractAccessToken(Map<String, dynamic> body) {
  final raw = body['accessToken'] ?? body['access_token'] ?? body['token'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw != null) return raw.toString().trim();
  return null;
}

Map<String, dynamic> _expectJsonMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return data.cast<String, dynamic>();
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  throw const FormatException('Expected JSON object');
}

String _readString(Object? value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

class _GrpcWebResponse {
  const _GrpcWebResponse({required this.bytes, required this.headers});

  final Uint8List bytes;
  final Headers headers;
}

class _GrpcWebMessage {
  const _GrpcWebMessage({required this.messageBytes, required this.trailers});

  final Uint8List messageBytes;
  final Map<String, String> trailers;
}

Future<_GrpcWebResponse> _grpcWebPost({
  required Uri baseUrl,
  required String path,
  required Uint8List data,
  Map<String, String>? headers,
}) async {
  final dio = _newDio(
    baseUrl,
    headers: <String, Object?>{
      'Content-Type': _kGrpcWebContentType,
      'Accept': _kGrpcWebContentType,
      'grpc-accept-encoding': 'identity',
      'accept-encoding': 'identity',
      'X-Grpc-Web': '1',
      'X-User-Agent': 'grpc-web-dart',
      if (headers != null) ...headers,
    },
    connectTimeout: _kLoginConnectTimeout,
    receiveTimeout: _kLoginReceiveTimeout,
  );
  final response = await dio.post(
    path,
    data: _wrapGrpcWebMessage(data),
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = response.data is Uint8List
      ? response.data as Uint8List
      : Uint8List.fromList((response.data as List).cast<int>());
  return _GrpcWebResponse(bytes: bytes, headers: response.headers);
}

Uint8List _wrapGrpcWebMessage(Uint8List message) {
  final buffer = BytesBuilder();
  buffer.addByte(0);
  buffer.add(_writeGrpcWebLength(message.length));
  buffer.add(message);
  return buffer.toBytes();
}

Uint8List _writeGrpcWebLength(int length) {
  return Uint8List.fromList([
    (length >> 24) & 0xFF,
    (length >> 16) & 0xFF,
    (length >> 8) & 0xFF,
    length & 0xFF,
  ]);
}

_GrpcWebMessage _parseGrpcWebResponse(Uint8List bytes) {
  final decoded = _maybeDecodeGrpcWebText(bytes);
  final data = decoded ?? bytes;
  final buffer = BytesBuilder();
  final trailers = <String, String>{};
  var offset = 0;
  while (offset + 5 <= data.length) {
    final flag = data[offset];
    final length =
        (data[offset + 1] << 24) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 8) |
        data[offset + 4];
    offset += 5;
    if (offset + length > data.length) break;
    final frame = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
    if ((flag & 0x80) != 0) {
      _parseGrpcWebTrailers(frame, trailers);
    } else {
      buffer.add(frame);
    }
  }
  if (trailers.isNotEmpty) {
    final status = trailers['grpc-status'];
    if (status != null && status != '0') {
      final message = trailers['grpc-message'] ?? 'grpc status $status';
      throw FormatException(message);
    }
  }
  return _GrpcWebMessage(messageBytes: buffer.toBytes(), trailers: trailers);
}

Uint8List? _maybeDecodeGrpcWebText(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  var isAscii = true;
  for (final b in bytes) {
    if (b < 9 || b > 126) {
      if (b != 10 && b != 13) {
        isAscii = false;
        break;
      }
    }
  }
  if (!isAscii) return null;
  final text = utf8.decode(bytes, allowMalformed: true).trim();
  if (text.isEmpty) return null;
  final base64Text = text.replaceAll(RegExp(r'\s+'), '');
  if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(base64Text)) return null;
  try {
    return Uint8List.fromList(base64.decode(base64Text));
  } catch (_) {
    return null;
  }
}

void _parseGrpcWebTrailers(Uint8List frame, Map<String, String> out) {
  final text = utf8.decode(frame, allowMalformed: true);
  final lines = text.split('\r\n');
  for (final line in lines) {
    if (line.isEmpty) continue;
    final index = line.indexOf(':');
    if (index <= 0) continue;
    final key = line.substring(0, index).trim().toLowerCase();
    final value = line.substring(index + 1).trim();
    out[key] = value;
  }
}

Uint8List _encodeCreateSessionRequest({
  required String username,
  required String password,
}) {
  final credentials = _encodePasswordCredentials(
    username: username,
    password: password,
  );
  final buffer = BytesBuilder();
  _writeBytesField(buffer, 1, credentials);
  return buffer.toBytes();
}

Uint8List _encodePasswordCredentials({
  required String username,
  required String password,
}) {
  final buffer = BytesBuilder();
  _writeStringField(buffer, 1, username);
  _writeStringField(buffer, 2, password);
  return buffer.toBytes();
}

Uint8List _encodeCreateUserAccessTokenRequest({
  required String parent,
  required String description,
}) {
  final accessToken = _encodeUserAccessToken(description: description);
  final buffer = BytesBuilder();
  _writeStringField(buffer, 1, parent);
  _writeBytesField(buffer, 2, accessToken);
  return buffer.toBytes();
}

Uint8List _encodeUserAccessToken({required String description}) {
  final buffer = BytesBuilder();
  _writeStringField(buffer, 3, description);
  return buffer.toBytes();
}

void _writeStringField(BytesBuilder buffer, int fieldNumber, String value) {
  final bytes = utf8.encode(value);
  _writeTag(buffer, fieldNumber, 2);
  _writeVarint(buffer, bytes.length);
  buffer.add(bytes);
}

void _writeBytesField(BytesBuilder buffer, int fieldNumber, Uint8List bytes) {
  _writeTag(buffer, fieldNumber, 2);
  _writeVarint(buffer, bytes.length);
  buffer.add(bytes);
}

void _writeTag(BytesBuilder buffer, int fieldNumber, int wireType) {
  final tag = (fieldNumber << 3) | wireType;
  _writeVarint(buffer, tag);
}

void _writeVarint(BytesBuilder buffer, int value) {
  var v = value;
  while (v >= 0x80) {
    buffer.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  buffer.addByte(v);
}

User _parseCreateSessionUser(Uint8List messageBytes) {
  final reader = _ProtoReader(messageBytes);
  Uint8List? userBytes;
  while (!reader.isAtEnd) {
    final tag = reader.readTag();
    final field = tag >> 3;
    final wire = tag & 0x7;
    if (field == 1 && wire == 2) {
      userBytes = reader.readBytes();
      break;
    }
    reader.skipField(wire);
  }
  if (userBytes == null) {
    throw const FormatException('Missing user in response');
  }
  return _parseUserMessage(userBytes);
}

User _parseUserMessage(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  var name = '';
  var username = '';
  var displayName = '';
  var avatarUrl = '';
  var description = '';
  while (!reader.isAtEnd) {
    final tag = reader.readTag();
    final field = tag >> 3;
    final wire = tag & 0x7;
    var handled = false;
    switch (field) {
      case 1:
        if (wire == 2) {
          name = reader.readString();
          handled = true;
        }
        break;
      case 3:
        if (wire == 2) {
          username = reader.readString();
          handled = true;
        }
        break;
      case 5:
        if (wire == 2) {
          displayName = reader.readString();
          handled = true;
        }
        break;
      case 6:
        if (wire == 2) {
          avatarUrl = reader.readString();
          handled = true;
        }
        break;
      case 7:
        if (wire == 2) {
          description = reader.readString();
          handled = true;
        }
        break;
    }
    if (!handled) {
      reader.skipField(wire);
    }
  }
  final normalizedName = name.startsWith('users/') || name.isEmpty
      ? name
      : 'users/$name';
  final finalUsername = username.isNotEmpty
      ? username
      : normalizedName.split('/').last;
  final finalDisplayName = displayName.isNotEmpty ? displayName : finalUsername;
  return User(
    name: normalizedName,
    username: finalUsername,
    displayName: finalDisplayName,
    avatarUrl: avatarUrl,
    description: description,
  );
}

String _parseUserAccessToken(Uint8List messageBytes) {
  final reader = _ProtoReader(messageBytes);
  while (!reader.isAtEnd) {
    final tag = reader.readTag();
    final field = tag >> 3;
    final wire = tag & 0x7;
    if (field == 2 && wire == 2) {
      return reader.readString();
    }
    reader.skipField(wire);
  }
  return '';
}

class _ProtoReader {
  _ProtoReader(this._data);

  final Uint8List _data;
  int _pos = 0;

  bool get isAtEnd => _pos >= _data.length;

  int readTag() => readVarint();

  int readVarint() {
    var shift = 0;
    var result = 0;
    while (_pos < _data.length) {
      final byte = _data[_pos++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    return result;
  }

  Uint8List readBytes() {
    final length = readVarint();
    final end = (_pos + length).clamp(0, _data.length);
    final bytes = Uint8List.sublistView(_data, _pos, end);
    _pos = end;
    return bytes;
  }

  String readString() => utf8.decode(readBytes(), allowMalformed: true);

  void skipField(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
        return;
      case 2:
        final length = readVarint();
        _pos = (_pos + length).clamp(0, _data.length);
        return;
      case 5:
        _pos = (_pos + 4).clamp(0, _data.length);
        return;
      case 1:
        _pos = (_pos + 8).clamp(0, _data.length);
        return;
      default:
        return;
    }
  }
}
