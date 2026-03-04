part of 'submit_logs_providers.dart';

class SubmitLogsController {
  SubmitLogsController(this._ref);

  final Ref _ref;

  Future<LogQueueResult> queueServerLogSubmission({
    required String reportText,
    required String reportPath,
    required bool includeErrors,
    required bool includeOutbox,
  }) async {
    final report = reportText.trim();
    if (report.isEmpty) return LogQueueResult.skipped;
    if (_ref.read(currentLocalLibraryProvider) != null) {
      return LogQueueResult.skipped;
    }

    final session = _ref.read(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    if (account == null) return LogQueueResult.skipped;

    final sessionController = _ref.read(appSessionProvider.notifier);
    final versionRaw = sessionController
        .resolveEffectiveServerVersionForAccount(account: account);
    final version = parseMemoApiVersion(versionRaw);
    if (version == null) return LogQueueResult.skipped;

    final now = DateTime.now().toUtc();
    final submissionId = now.microsecondsSinceEpoch.toString();
    final payload = <String, dynamic>{
      'title': 'MemoFlow Log Report (${version.versionString})',
      'submission_id': submissionId,
      'report': report,
      'report_path': reportPath,
      'api_version': version.versionString,
      'created_time': now.toIso8601String(),
      'include_errors': includeErrors,
      'include_outbox': includeOutbox,
    };

    try {
      await _ref
          .read(databaseProvider)
          .enqueueOutbox(type: 'submit_log_report', payload: payload);
    } catch (error, stackTrace) {
      _ref
          .read(logManagerProvider)
          .warn(
            'Failed to queue log report submission',
            error: error,
            stackTrace: stackTrace,
          );
      return LogQueueResult.failed;
    }

    _ref
        .read(logManagerProvider)
        .info(
          'Queued log report submission',
          context: <String, Object?>{
            'apiVersion': version.versionString,
            'reportLength': report.length,
          },
        );

    unawaited(
      _ref
          .read(syncCoordinatorProvider.notifier)
          .requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          ),
    );
    return LogQueueResult.queued;
  }
}

enum LogQueueResult { queued, skipped, failed }
