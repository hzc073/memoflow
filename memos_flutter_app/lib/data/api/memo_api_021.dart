import '../logs/breadcrumb_store.dart';
import '../logs/log_manager.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_store.dart';
import '../models/instance_profile.dart';
import 'memos_api.dart';
import 'password_sign_in_api.dart';

class MemoApi021 {
  static const String version = '0.21.0';

  static const InstanceProfile _profile = InstanceProfile(
    version: version,
    mode: '',
    instanceUrl: '',
    owner: '',
  );

  static MemosApi unauthenticated(
    Uri baseUrl, {
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    return MemosApi.unauthenticated(
      baseUrl,
      useLegacyApi: true,
      instanceProfile: _profile,
      strictRouteLock: true,
      strictServerVersion: version,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
      logManager: logManager,
    );
  }

  static MemosApi authenticated({
    required Uri baseUrl,
    required String personalAccessToken,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    return MemosApi.authenticated(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      useLegacyApi: true,
      instanceProfile: _profile,
      strictRouteLock: true,
      strictServerVersion: version,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
      logManager: logManager,
    );
  }

  static Future<MemoPasswordSignInResult> passwordSignIn({
    required Uri baseUrl,
    required String username,
    required String password,
  }) {
    return MemoPasswordSignInApi.signInV2GrpcWeb(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  static MemosApi sessionAuthenticated({
    required Uri baseUrl,
    required String sessionCookie,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    return MemosApi.sessionAuthenticated(
      baseUrl: baseUrl,
      sessionCookie: sessionCookie,
      useLegacyApi: true,
      instanceProfile: _profile,
      strictRouteLock: true,
      strictServerVersion: version,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
      logManager: logManager,
    );
  }
}
