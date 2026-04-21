part of 'login_provider.dart';

class LoginController {
  LoginController(this._ref);

  final Ref _ref;

  String normalizeServerVersion(String raw) {
    return normalizeMemoApiVersion(raw);
  }

  LoginApiVersion? parseVersion(String raw) {
    final parsed = parseMemoApiVersion(raw);
    if (parsed == null) return null;
    return LoginApiVersion._(parsed);
  }

  Future<LoginProbeReport> probeSingleVersion({
    required Uri baseUrl,
    required String personalAccessToken,
    required LoginApiVersion version,
    required String probeMemoNotice,
  }) async {
    final report = await const MemoApiProbeService().probeSingle(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      version: version._value,
      probeMemoNotice: probeMemoNotice,
      deferCleanup: true,
    );
    final diagnostics = report.passed
        ? ''
        : MemoApiProbeSummary(
            reports: <MemoApiVersionProbeReport>[report],
          ).buildDiagnostics();
    final deferred = report.deferredCleanup;
    return LoginProbeReport(
      passed: report.passed,
      diagnostics: diagnostics,
      cleanup: LoginProbeCleanup(
        hasPending: deferred.hasPending,
        attachmentName: deferred.attachmentName,
        memoUid: deferred.memoUid,
      ),
    );
  }

  Future<void> cleanupProbeArtifactsAfterSync({
    required LoginApiVersion version,
    required LoginProbeCleanup cleanup,
    required Uri baseUrl,
    required String personalAccessToken,
  }) async {
    if (!cleanup.hasPending) return;

    try {
      await _ref
          .read(syncCoordinatorProvider.notifier)
          .requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          );
    } catch (_) {
      return;
    }

    final api = MemoApiFacade.authenticated(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      version: version._value,
    );

    final attachmentName = cleanup.attachmentName?.trim() ?? '';
    if (attachmentName.isNotEmpty) {
      try {
        await api.deleteAttachment(attachmentName: attachmentName);
      } catch (_) {}
    }

    final memoUid = cleanup.memoUid?.trim() ?? '';
    if (memoUid.isNotEmpty) {
      try {
        await api.deleteMemo(
          memoUid: memoUid,
          force: _supportsForceDeleteMemo(version._value),
        );
      } catch (_) {}
    }

    try {
      await _ref
          .read(syncCoordinatorProvider.notifier)
          .requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          );
    } catch (_) {}
  }

  bool _supportsForceDeleteMemo(MemoApiVersion version) {
    return switch (version) {
      MemoApiVersion.v025 || MemoApiVersion.v026 || MemoApiVersion.v027 => true,
      MemoApiVersion.v021 ||
      MemoApiVersion.v022 ||
      MemoApiVersion.v023 ||
      MemoApiVersion.v024 => false,
    };
  }
}
