import 'dart:convert';

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
  const AppSessionState({
    required this.accounts,
    required this.currentKey,
  });

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

final appSessionProvider = StateNotifierProvider<AppSessionController, AsyncValue<AppSessionState>>((ref) {
  return AppSessionNotifier(ref.watch(accountsRepositoryProvider));
});

abstract class AppSessionController extends StateNotifier<AsyncValue<AppSessionState>> {
  AppSessionController(super.state);

  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
  });

  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
  });

  Future<void> switchAccount(String accountKey);

  Future<void> removeAccount(String accountKey);

  Future<void> refreshCurrentUser({bool ignoreErrors = true});
}

class AppSessionNotifier extends AppSessionController {
  AppSessionNotifier(this._accountsRepository) : super(const AsyncValue.loading()) {
    _loadFromStorage();
  }

  final AccountsRepository _accountsRepository;

  Future<void> _loadFromStorage() async {
    final stored = await _accountsRepository.read();
    state = AsyncValue.data(AppSessionState(accounts: stored.accounts, currentKey: stored.currentKey));
  }

  Future<AppSessionState> _upsertAccount({
    required Uri baseUrl,
    required String personalAccessToken,
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

    final normalizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    final accountKey = '${canonicalBaseUrlString(normalizedBaseUrl)}|${user.name}';

    final current = state.valueOrNull ?? const AppSessionState(accounts: [], currentKey: null);
    final accounts = [...current.accounts];
    final account = Account(
      key: accountKey,
      baseUrl: normalizedBaseUrl,
      personalAccessToken: personalAccessToken,
      user: user,
      instanceProfile: instanceProfile,
    );
    final existingIndex = accounts.indexWhere((a) => a.key == accountKey);
    if (existingIndex >= 0) {
      accounts[existingIndex] = account;
    } else {
      accounts.add(account);
    }

    await _accountsRepository.write(AccountsState(accounts: accounts, currentKey: accountKey));
    return AppSessionState(accounts: accounts, currentKey: accountKey);
  }

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
  }) async {
    // Keep the previous state while connecting so the login form doesn't reset.
    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return _upsertAccount(baseUrl: baseUrl, personalAccessToken: personalAccessToken);
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
      final signIn = await _signInWithPassword(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useLegacyApi: useLegacyApi,
      );
      final token = await _createTokenFromPasswordSignIn(
        baseUrl: baseUrl,
        signIn: signIn,
        useLegacyApi: useLegacyApi,
      );
      return _upsertAccount(baseUrl: baseUrl, personalAccessToken: token);
    });
  }

  @override
  Future<void> switchAccount(String accountKey) async {
    final current = state.valueOrNull ?? const AppSessionState(accounts: [], currentKey: null);
    if (!current.accounts.any((a) => a.key == accountKey)) return;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(AccountsState(accounts: current.accounts, currentKey: accountKey));
      return AppSessionState(accounts: current.accounts, currentKey: accountKey);
    });
  }

  @override
  Future<void> removeAccount(String accountKey) async {
    final current = state.valueOrNull ?? const AppSessionState(accounts: [], currentKey: null);
    final accounts = current.accounts.where((a) => a.key != accountKey).toList(growable: false);
    final nextKey = current.currentKey == accountKey ? (accounts.firstOrNull?.key) : current.currentKey;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(AccountsState(accounts: accounts, currentKey: nextKey));
      return AppSessionState(accounts: accounts, currentKey: nextKey);
    });
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final account = current.currentAccount;
    if (account == null) return;

    try {
      final user = await MemosApi.authenticated(
        baseUrl: account.baseUrl,
        personalAccessToken: account.personalAccessToken,
        logManager: LogManager.instance,
      ).getCurrentUser();

      final updatedAccount = Account(
        key: account.key,
        baseUrl: account.baseUrl,
        personalAccessToken: account.personalAccessToken,
        user: user,
        instanceProfile: account.instanceProfile,
      );
      final accounts = current.accounts
          .map((a) => a.key == account.key ? updatedAccount : a)
          .toList(growable: false);
      final next = AppSessionState(accounts: accounts, currentKey: current.currentKey);
      state = AsyncValue.data(next);
      await _accountsRepository.write(AccountsState(accounts: accounts, currentKey: current.currentKey));
    } catch (e) {
      if (!ignoreErrors) rethrow;
    }
  }

  Future<_PasswordSignInResult> _signInWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
  }) async {
    final attempts = useLegacyApi
        ? <_PasswordSignInAttempt>[
            _PasswordSignInAttempt(
              _PasswordSignInEndpoint.signinV2,
              () => _signInV2(baseUrl: baseUrl, username: username, password: password),
            ),
            _PasswordSignInAttempt(
              _PasswordSignInEndpoint.signinV1,
              () => _signInV1(baseUrl: baseUrl, username: username, password: password),
            ),
            _PasswordSignInAttempt(
              _PasswordSignInEndpoint.sessionV1,
              () => _signInSessions(baseUrl: baseUrl, username: username, password: password),
            ),
          ]
        : <_PasswordSignInAttempt>[
            _PasswordSignInAttempt(
              _PasswordSignInEndpoint.sessionV1,
              () => _signInSessions(baseUrl: baseUrl, username: username, password: password),
            ),
            _PasswordSignInAttempt(
              _PasswordSignInEndpoint.signinV1,
              () => _signInV1(baseUrl: baseUrl, username: username, password: password),
            ),
            _PasswordSignInAttempt(
              _PasswordSignInEndpoint.signinV2,
              () => _signInV2(baseUrl: baseUrl, username: username, password: password),
            ),
          ];

    DioException? lastNonFallback;
    DioException? lastFallback;
    FormatException? lastFormat;
    Object? lastOtherError;

    LogManager.instance.info(
      'Password sign-in start',
      context: <String, Object?>{
        'baseUrl': canonicalBaseUrlString(baseUrl),
        'mode': useLegacyApi ? 'legacy' : 'new',
        'attempts': attempts.map((a) => a.endpoint.label).toList(),
      },
    );

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

    if (lastNonFallback != null) throw lastNonFallback;
    if (lastOtherError != null) throw lastOtherError;
    if (lastFallback != null) throw lastFallback;
    if (lastFormat != null) throw lastFormat;
    throw StateError('Unable to sign in');
  }

  Future<_PasswordSignInResult> _signInSessions({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(baseUrl);
    final response = await dio.post(
      'api/v1/auth/sessions',
      data: {
        'passwordCredentials': {'username': username, 'password': password},
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final sessionValue = _extractCookieValue(response.headers, _kSessionCookieName);
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

  Future<_PasswordSignInResult> _signInV1({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = _newDio(baseUrl);
    final response = await dio.post(
      'api/v1/auth/signin',
      data: {
        'passwordCredentials': {'username': username, 'password': password},
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token = _extractAccessToken(body) ?? _extractCookieValue(response.headers, _kAccessTokenCookieName);
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
    final dio = _newDio(baseUrl);
    final response = await dio.post(
      'api/v2/auth/signin',
      data: {
        'username': username,
        'password': password,
        'neverExpire': false,
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token = _extractAccessToken(body) ?? _extractCookieValue(response.headers, _kAccessTokenCookieName);
    if (token == null || token.isEmpty) {
      throw const FormatException('Access token missing in response');
    }
    return _PasswordSignInResult(
      user: user,
      endpoint: _PasswordSignInEndpoint.signinV2,
      accessToken: token,
    );
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
    final dio = _newDio(baseUrl, headers: {'Authorization': 'Bearer $accessToken'});
    final expiresAt = expiresInDays > 0 ? DateTime.now().toUtc().add(Duration(days: expiresInDays)) : null;
    final path = userName.startsWith('users/') ? 'api/v2/$userName/access_tokens' : 'api/v2/users/$userName/access_tokens';
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
      final tokenValue = _readString(tokenJson['accessToken'] ?? tokenJson['access_token']);
      if (tokenValue.isNotEmpty) return tokenValue;
    }
    final tokenValue = _readString(body['accessToken'] ?? body['access_token']);
    if (tokenValue.isEmpty) {
      throw const FormatException('Token missing in response');
    }
    return tokenValue;
  }
}

extension _FirstOrNullAccountExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum _PasswordSignInEndpoint {
  sessionV1,
  signinV1,
  signinV2,
}

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

const String _kPasswordLoginTokenDescription = 'MemoFlow (password login)';
const String _kAccessTokenCookieName = 'memos.access-token';
const String _kSessionCookieName = 'user_session';

Dio _newDio(Uri baseUrl, {Map<String, Object?>? headers}) {
  return Dio(
    BaseOptions(
      baseUrl: dioBaseUrlString(baseUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: headers,
    ),
  );
}

bool _shouldFallback(DioException e) {
  final status = e.response?.statusCode ?? 0;
  return status == 404 || status == 405;
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
