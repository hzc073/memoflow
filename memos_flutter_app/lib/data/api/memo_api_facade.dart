import '../logs/breadcrumb_store.dart';
import '../logs/log_manager.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_store.dart';
import 'memo_api_021.dart';
import 'memo_api_022.dart';
import 'memo_api_023.dart';
import 'memo_api_024.dart';
import 'memo_api_025.dart';
import 'memo_api_026.dart';
import 'memo_api_version.dart';
import 'memos_api.dart';
import 'password_sign_in_api.dart';

class MemoApiFacade {
  static MemosApi unauthenticated({
    required Uri baseUrl,
    required MemoApiVersion version,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    return switch (version) {
      MemoApiVersion.v021 => MemoApi021.unauthenticated(
        baseUrl,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v022 => MemoApi022.unauthenticated(
        baseUrl,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v023 => MemoApi023.unauthenticated(
        baseUrl,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v024 => MemoApi024.unauthenticated(
        baseUrl,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v025 => MemoApi025.unauthenticated(
        baseUrl,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v026 => MemoApi026.unauthenticated(
        baseUrl,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
    };
  }

  static MemosApi authenticated({
    required Uri baseUrl,
    required String personalAccessToken,
    required MemoApiVersion version,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    return switch (version) {
      MemoApiVersion.v021 => MemoApi021.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v022 => MemoApi022.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v023 => MemoApi023.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v024 => MemoApi024.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v025 => MemoApi025.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v026 => MemoApi026.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
    };
  }

  static MemosApi sessionAuthenticated({
    required Uri baseUrl,
    required String sessionCookie,
    required MemoApiVersion version,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    return switch (version) {
      MemoApiVersion.v021 => MemoApi021.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: sessionCookie,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v022 => MemoApi022.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: sessionCookie,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v023 => MemoApi023.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: sessionCookie,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v024 => MemoApi024.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: sessionCookie,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v025 => MemoApi025.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: sessionCookie,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
      MemoApiVersion.v026 => MemoApi026.sessionAuthenticated(
        baseUrl: baseUrl,
        sessionCookie: sessionCookie,
        logStore: logStore,
        logBuffer: logBuffer,
        breadcrumbStore: breadcrumbStore,
        logManager: logManager,
      ),
    };
  }

  static Future<MemoPasswordSignInResult> passwordSignIn({
    required Uri baseUrl,
    required String username,
    required String password,
    required MemoApiVersion version,
  }) {
    return switch (version) {
      MemoApiVersion.v021 => MemoApi021.passwordSignIn(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
      MemoApiVersion.v022 => MemoApi022.passwordSignIn(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
      MemoApiVersion.v023 => MemoApi023.passwordSignIn(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
      MemoApiVersion.v024 => MemoApi024.passwordSignIn(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
      MemoApiVersion.v025 => MemoApi025.passwordSignIn(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
      MemoApiVersion.v026 => MemoApi026.passwordSignIn(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
    };
  }

  static MemosApi authenticatedByVersionString({
    required Uri baseUrl,
    required String personalAccessToken,
    required String version,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    final parsed = parseMemoApiVersion(version) ?? MemoApiVersion.v026;
    return authenticated(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      version: parsed,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
      logManager: logManager,
    );
  }
}
