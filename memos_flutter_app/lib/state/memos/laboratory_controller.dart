part of 'laboratory_providers.dart';

class LaboratoryVersion {
  LaboratoryVersion._(this._value);

  final MemoApiVersion _value;

  String get versionString => _value.versionString;
}

class LaboratoryProbeCleanup {
  const LaboratoryProbeCleanup({
    required this.hasPending,
    this.attachmentName,
    this.memoUid,
  });

  final bool hasPending;
  final String? attachmentName;
  final String? memoUid;
}

class LaboratoryProbeResult {
  const LaboratoryProbeResult({
    required this.passed,
    required this.diagnostics,
    required this.cleanup,
  });

  final bool passed;
  final String diagnostics;
  final LaboratoryProbeCleanup cleanup;
}

class LaboratoryController {
  LaboratoryController(this._ref);

  final Ref _ref;

  LaboratoryVersion get defaultVersion =>
      LaboratoryVersion._(MemoApiVersion.v027);

  String normalizeServerVersion(String raw) {
    return normalizeMemoApiVersion(raw);
  }

  LaboratoryVersion? parseVersion(String raw) {
    final parsed = parseMemoApiVersion(raw);
    if (parsed == null) return null;
    return LaboratoryVersion._(parsed);
  }

  Future<LaboratoryProbeResult?> probeSingleVersion({
    required Account account,
    required LaboratoryVersion version,
    required String probeMemoNotice,
  }) async {
    final report = await const MemoApiProbeService().probeSingle(
      baseUrl: account.baseUrl,
      personalAccessToken: account.personalAccessToken,
      version: version._value,
      probeMemoNotice: probeMemoNotice,
      deferCleanup: true,
    );
    final diagnostics = report.failures
        .map((failure) => failure.toDiagnosticLine())
        .join('\n');
    final deferred = report.deferredCleanup;
    return LaboratoryProbeResult(
      passed: report.passed,
      diagnostics: diagnostics,
      cleanup: LaboratoryProbeCleanup(
        hasPending: deferred.hasPending,
        attachmentName: deferred.attachmentName,
        memoUid: deferred.memoUid,
      ),
    );
  }

  Future<void> cleanupProbeArtifactsAfterSync({
    required Account account,
    required LaboratoryVersion version,
    required LaboratoryProbeCleanup cleanup,
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
      baseUrl: account.baseUrl,
      personalAccessToken: account.personalAccessToken,
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
