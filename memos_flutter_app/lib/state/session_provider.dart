import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api/memo_api_facade.dart';
import '../data/api/memo_api_version.dart';
import '../data/api/memos_api.dart';
import '../data/api/password_sign_in_api.dart';
import '../data/logs/log_manager.dart';
import '../data/models/account.dart';
import '../data/models/instance_profile.dart';
import '../data/settings/accounts_repository.dart';
import '../data/settings/queued_secure_storage.dart';
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
  return QueuedFlutterSecureStorage();
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
    String? serverVersionOverride,
  });

  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  });

  Future<void> setCurrentKey(String? key);

  Future<void> switchAccount(String accountKey);

  Future<void> switchWorkspace(String workspaceKey);

  Future<void> removeAccount(String accountKey);

  Future<void> reloadFromStorage();

  Future<void> refreshCurrentUser({bool ignoreErrors = true});

  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  });

  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  });

  String resolveEffectiveServerVersionForAccount({required Account account});

  Future<void> setCurrentAccountUseLegacyApiOverride(bool value);

  Future<void> setCurrentAccountServerVersionOverride(String? version);

  Future<InstanceProfile> detectCurrentAccountInstanceProfile();
}

class AppSessionNotifier extends AppSessionController {
  AppSessionNotifier(this._accountsRepository)
    : super(const AsyncValue.loading()) {
    _loadFromStorage();
  }

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
    try {
      final stored = await _accountsRepository.read();
      state = AsyncValue.data(
        AppSessionState(
          accounts: stored.accounts,
          currentKey: stored.currentKey,
        ),
      );
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'Failed to load session from secure storage. Falling back to empty session.',
        error: error,
        stackTrace: stackTrace,
      );
      state = const AsyncValue.data(
        AppSessionState(accounts: [], currentKey: null),
      );
    }
  }

  @override
  Future<void> reloadFromStorage() async {
    await _loadFromStorage();
  }

  Future<AppSessionState> _upsertAccount({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {
    final normalizedServerVersionOverride = _normalizeVersionOverride(
      serverVersionOverride,
    );
    final resolvedVersion = normalizedServerVersionOverride != null
        ? parseMemoApiVersion(normalizedServerVersionOverride)!
        : await _detectVersionFromBaseUrl(baseUrl);

    InstanceProfile instanceProfile;
    if (normalizedServerVersionOverride != null) {
      instanceProfile = InstanceProfile(
        version: resolvedVersion.versionString,
        mode: '',
        instanceUrl: '',
        owner: '',
      );
    } else {
      instanceProfile = await _loadInstanceProfileOrEmpty(baseUrl);
      instanceProfile = InstanceProfile(
        version: resolvedVersion.versionString,
        mode: instanceProfile.mode,
        instanceUrl: instanceProfile.instanceUrl,
        owner: instanceProfile.owner,
      );
    }

    final user = await MemoApiFacade.authenticated(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      version: resolvedVersion,
      logManager: LogManager.instance,
    ).getCurrentUser();

    final normalizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    final accountKey =
        '${canonicalBaseUrlString(normalizedBaseUrl)}|${user.name}';

    final current =
        state.valueOrNull ??
        const AppSessionState(accounts: [], currentKey: null);
    final accounts = [...current.accounts];
    final existingIndex = accounts.indexWhere((a) => a.key == accountKey);
    final resolvedUseLegacyApiOverride =
        useLegacyApiOverride ?? resolvedVersion.defaultUseLegacyApi;
    final resolvedServerVersionOverride = resolvedVersion.versionString;

    final account = Account(
      key: accountKey,
      baseUrl: normalizedBaseUrl,
      personalAccessToken: personalAccessToken,
      user: user,
      instanceProfile: instanceProfile,
      useLegacyApiOverride: resolvedUseLegacyApiOverride,
      serverVersionOverride: resolvedServerVersionOverride,
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

  Future<InstanceProfile> _loadInstanceProfileOrEmpty(Uri baseUrl) async {
    try {
      final dio = _newDio(
        baseUrl,
        connectTimeout: _kLoginConnectTimeout,
        receiveTimeout: _kLoginReceiveTimeout,
      );
      final response = await dio.get('api/v1/instance/profile');
      return InstanceProfile.fromJson(_expectJsonMap(response.data));
    } catch (_) {
      return const InstanceProfile.empty();
    }
  }

  Future<MemoApiVersion> _detectVersionFromBaseUrl(Uri baseUrl) async {
    final profile = await _loadInstanceProfileOrEmpty(baseUrl);
    final parsed = parseMemoApiVersion(profile.version);
    if (parsed != null) return parsed;
    final raw = profile.version.trim();
    if (raw.isNotEmpty) {
      throw FormatException(
        'Unsupported server version "$raw". Supported: 0.21.0~0.26.0.',
      );
    }
    throw const FormatException(
      'Unable to detect backend version. Please select API version manually.',
    );
  }

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {
    // Keep the previous state while connecting so the login form doesn't reset.
    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return _upsertAccount(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        useLegacyApiOverride: useLegacyApiOverride,
        serverVersionOverride: serverVersionOverride,
      );
    });
  }

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {
    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final _ = useLegacyApi;
      final normalizedServerVersionOverride = _normalizeVersionOverride(
        serverVersionOverride,
      );
      final loginVersion = normalizedServerVersionOverride != null
          ? parseMemoApiVersion(normalizedServerVersionOverride)!
          : await _detectVersionFromBaseUrl(baseUrl);
      final signIn = await _signInWithPassword(
        baseUrl: baseUrl,
        username: username,
        password: password,
        version: loginVersion,
      );
      final token = await _createTokenFromPasswordSignIn(
        baseUrl: baseUrl,
        signIn: signIn,
        version: loginVersion,
      );
      return _upsertAccount(
        baseUrl: baseUrl,
        personalAccessToken: token,
        useLegacyApiOverride: loginVersion.defaultUseLegacyApi,
        serverVersionOverride: loginVersion.versionString,
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
    final next = AppSessionState(accounts: current.accounts, currentKey: key);

    // Optimistically switch workspace in memory first so local mode can start
    // even if secure storage is temporarily unavailable.
    state = AsyncValue.data(next);
    try {
      await _accountsRepository.write(
        AccountsState(accounts: current.accounts, currentKey: key),
      );
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Failed to persist workspace switch. Keeping in-memory session state.',
        error: error,
        stackTrace: stackTrace,
        context: {'workspaceKey': key},
      );
    }
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

    final parsedVersion = _resolveMemoApiVersionForAccount(account: account);

    try {
      final api = MemoApiFacade.authenticated(
        baseUrl: account.baseUrl,
        personalAccessToken: account.personalAccessToken,
        version: parsedVersion,
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
        serverVersionOverride: account.serverVersionOverride,
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

  MemoApiVersion _resolveMemoApiVersionForAccount({required Account account}) {
    final manual = parseMemoApiVersion(account.serverVersionOverride);
    if (manual != null) return manual;

    final detected = parseMemoApiVersion(account.instanceProfile.version);
    if (detected != null) return detected;

    throw const FormatException(
      'No fixed API version selected. Please select version manually.',
    );
  }

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) {
    final _ = globalDefault;
    final override = account.useLegacyApiOverride;
    if (override != null) {
      return override;
    }
    return _resolveMemoApiVersionForAccount(
      account: account,
    ).defaultUseLegacyApi;
  }

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) {
    final version = _resolveMemoApiVersionForAccount(
      account: account,
    ).versionString;
    if (version == account.instanceProfile.version.trim()) {
      return account.instanceProfile;
    }
    return InstanceProfile(
      version: version,
      mode: account.instanceProfile.mode,
      instanceUrl: account.instanceProfile.instanceUrl,
      owner: account.instanceProfile.owner,
    );
  }

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) {
    return _resolveMemoApiVersionForAccount(account: account).versionString;
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
      serverVersionOverride: account.serverVersionOverride,
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

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {
    final current = state.valueOrNull;
    final account = current?.currentAccount;
    if (current == null || account == null) {
      return;
    }

    final normalized = _normalizeVersionOverride(version);
    final derivedLegacyOverride = normalized == null
        ? account.useLegacyApiOverride
        : (parseMemoApiVersion(normalized)?.defaultUseLegacyApi ??
              account.useLegacyApiOverride);

    if (account.serverVersionOverride == normalized &&
        account.useLegacyApiOverride == derivedLegacyOverride) {
      return;
    }

    final updatedAccount = Account(
      key: account.key,
      baseUrl: account.baseUrl,
      personalAccessToken: account.personalAccessToken,
      user: account.user,
      instanceProfile: account.instanceProfile,
      useLegacyApiOverride: derivedLegacyOverride,
      serverVersionOverride: normalized,
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

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    final current = state.valueOrNull;
    final account = current?.currentAccount;
    if (current == null || account == null) {
      throw StateError('No current account');
    }

    final version = _resolveMemoApiVersionForAccount(account: account);
    final profile = await MemoApiFacade.unauthenticated(
      baseUrl: account.baseUrl,
      version: version,
      logManager: LogManager.instance,
    ).getInstanceProfile();
    final mergedProfile = _mergeInstanceProfile(
      oldProfile: account.instanceProfile,
      newProfile: profile,
    );

    final updatedAccount = Account(
      key: account.key,
      baseUrl: account.baseUrl,
      personalAccessToken: account.personalAccessToken,
      user: account.user,
      instanceProfile: mergedProfile,
      useLegacyApiOverride: account.useLegacyApiOverride,
      serverVersionOverride: account.serverVersionOverride,
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
    return mergedProfile;
  }

  static InstanceProfile _mergeInstanceProfile({
    required InstanceProfile oldProfile,
    required InstanceProfile newProfile,
  }) {
    return InstanceProfile(
      version: newProfile.version.trim().isNotEmpty
          ? newProfile.version
          : oldProfile.version,
      mode: newProfile.mode.trim().isNotEmpty
          ? newProfile.mode
          : oldProfile.mode,
      instanceUrl: newProfile.instanceUrl.trim().isNotEmpty
          ? newProfile.instanceUrl
          : oldProfile.instanceUrl,
      owner: newProfile.owner.trim().isNotEmpty
          ? newProfile.owner
          : oldProfile.owner,
    );
  }

  static String? _normalizeVersionOverride(String? version) {
    final trimmed = (version ?? '').trim();
    if (trimmed.isEmpty) return null;
    final normalized = normalizeMemoApiVersion(trimmed);
    if (normalized.isEmpty) {
      throw const FormatException('Only API 0.21.0 ~ 0.26.0 are supported');
    }
    return normalized;
  }

  Future<MemoPasswordSignInResult> _signInWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required MemoApiVersion version,
  }) async {
    final usernameCandidates = _buildSignInUsernameCandidates(username);
    LogManager.instance.info(
      'Password sign-in start',
      context: <String, Object?>{
        'baseUrl': canonicalBaseUrlString(baseUrl),
        'version': version.versionString,
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

      try {
        final result = await MemoApiFacade.passwordSignIn(
          baseUrl: baseUrl,
          username: signInUsername,
          password: password,
          version: version,
        );
        LogManager.instance.info(
          'Password sign-in success',
          context: <String, Object?>{
            'endpoint': result.endpoint.label,
            'user': result.user.name,
            'hasAccessToken': result.accessToken?.isNotEmpty ?? false,
          },
        );
        return result;
      } on DioException catch (e) {
        LogManager.instance.warn(
          'Password sign-in failed',
          error: e,
          context: <String, Object?>{
            'status': e.response?.statusCode,
            'message': _extractDioMessage(e),
            'url': e.requestOptions.uri.toString(),
          },
        );
        if (hasNextCandidate && _shouldTryNextUsernameCandidate(e)) {
          LogManager.instance.warn(
            'Password sign-in retry with normalized username',
            context: <String, Object?>{
              'candidateIndex': candidateIndex + 2,
              'candidateCount': usernameCandidates.length,
            },
          );
          continue;
        }
        rethrow;
      } catch (e, stackTrace) {
        LogManager.instance.error(
          'Password sign-in failed',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    throw StateError('Unable to sign in');
  }

  Future<String> _createTokenFromPasswordSignIn({
    required Uri baseUrl,
    required MemoPasswordSignInResult signIn,
    required MemoApiVersion version,
  }) async {
    final bearerToken = (signIn.accessToken ?? '').trim();
    final sessionCookie = (signIn.sessionCookie ?? '').trim();

    if ((version == MemoApiVersion.v021 || version == MemoApiVersion.v023) &&
        bearerToken.isNotEmpty) {
      LogManager.instance.debug(
        'Use sign-in access token directly',
        context: <String, Object?>{
          'baseUrl': canonicalBaseUrlString(baseUrl),
          'user': signIn.user.name,
          'version': version.versionString,
        },
      );
      return bearerToken;
    }

    final description = _kPasswordLoginTokenDescription;
    final userName = signIn.user.name;

    Future<String> createViaApi(MemosApi api) {
      return api.createUserAccessToken(
        userName: userName,
        description: description,
        expiresInDays: 0,
      );
    }

    if (version == MemoApiVersion.v025) {
      if (sessionCookie.isNotEmpty) {
        final api = MemoApiFacade.sessionAuthenticated(
          baseUrl: baseUrl,
          sessionCookie: sessionCookie,
          version: version,
          logManager: LogManager.instance,
        );
        LogManager.instance.debug(
          'Create access token (session cookie)',
          context: <String, Object?>{
            'baseUrl': canonicalBaseUrlString(baseUrl),
            'user': userName,
            'version': version.versionString,
          },
        );
        return createViaApi(api);
      }

      if (bearerToken.isNotEmpty) {
        final api = MemoApiFacade.authenticated(
          baseUrl: baseUrl,
          personalAccessToken: bearerToken,
          version: version,
          logManager: LogManager.instance,
        );
        LogManager.instance.debug(
          'Create access token (bearer)',
          context: <String, Object?>{
            'baseUrl': canonicalBaseUrlString(baseUrl),
            'user': userName,
            'version': version.versionString,
          },
        );
        return createViaApi(api);
      }

      throw StateError('Missing auth credential for access token creation');
    }

    if (bearerToken.isEmpty) {
      throw StateError('Missing access token for access token creation');
    }

    final api = MemoApiFacade.authenticated(
      baseUrl: baseUrl,
      personalAccessToken: bearerToken,
      version: version,
      logManager: LogManager.instance,
    );
    LogManager.instance.debug(
      'Create access token (bearer)',
      context: <String, Object?>{
        'baseUrl': canonicalBaseUrlString(baseUrl),
        'user': userName,
        'version': version.versionString,
      },
    );
    return createViaApi(api);
  }
}

extension _FirstOrNullAccountExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

const String _kPasswordLoginTokenDescription = 'MemoFlow (password login)';
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

Map<String, dynamic> _expectJsonMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return data.cast<String, dynamic>();
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  throw const FormatException('Expected JSON object');
}
