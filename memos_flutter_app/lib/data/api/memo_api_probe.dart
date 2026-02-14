import 'package:dio/dio.dart';

import 'memo_api_facade.dart';
import 'memo_api_version.dart';

class MemoApiProbeFailure {
  const MemoApiProbeFailure({
    required this.version,
    required this.step,
    required this.endpoint,
    required this.statusCode,
    required this.reason,
  });

  final MemoApiVersion version;
  final String step;
  final String endpoint;
  final int? statusCode;
  final String reason;

  String toDiagnosticLine() {
    final statusLabel = statusCode == null ? '-' : statusCode.toString();
    return '[${version.versionString}] step=$step endpoint=$endpoint status=$statusLabel reason=$reason';
  }
}

class MemoApiVersionProbeReport {
  const MemoApiVersionProbeReport({
    required this.version,
    required this.passed,
    required this.failures,
  });

  final MemoApiVersion version;
  final bool passed;
  final List<MemoApiProbeFailure> failures;
}

class MemoApiProbeSummary {
  const MemoApiProbeSummary({required this.reports});

  final List<MemoApiVersionProbeReport> reports;

  List<MemoApiVersion> get passedVersions => reports
      .where((report) => report.passed)
      .map((report) => report.version)
      .toList(growable: false);

  bool get hasSuccess => passedVersions.isNotEmpty;

  String buildDiagnostics() {
    final buffer = StringBuffer();
    for (final report in reports) {
      final status = report.passed ? 'PASS' : 'FAIL';
      buffer.writeln('${report.version.versionString}: $status');
      for (final failure in report.failures) {
        buffer.writeln('  ${failure.toDiagnosticLine()}');
      }
    }
    return buffer.toString().trim();
  }
}

class MemoApiProbeService {
  const MemoApiProbeService();

  Future<MemoApiProbeSummary> probeAll({
    required Uri baseUrl,
    required String personalAccessToken,
    List<MemoApiVersion> versions = kMemoApiVersionsProbeOrder,
  }) async {
    final reports = <MemoApiVersionProbeReport>[];
    for (final version in versions) {
      reports.add(
        await probeSingle(
          baseUrl: baseUrl,
          personalAccessToken: personalAccessToken,
          version: version,
        ),
      );
    }
    return MemoApiProbeSummary(reports: reports);
  }

  Future<MemoApiVersionProbeReport> probeSingle({
    required Uri baseUrl,
    required String personalAccessToken,
    required MemoApiVersion version,
  }) async {
    final api = MemoApiFacade.authenticated(
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
      version: version,
    );

    final failures = <MemoApiProbeFailure>[];
    String? createdMemoUid;
    String? createdAttachmentName;
    final forceDeleteMemo = _supportsForceDeleteMemo(version);
    final seed = DateTime.now().toUtc().microsecondsSinceEpoch;
    final memoId = 'memoflow-probe-$seed';
    final contentPrefix = '[MemoFlow Probe ${version.versionString}]';

    try {
      await _runStep(
        failures: failures,
        version: version,
        step: 'current_user',
        endpointHint: _endpointHint(version: version, step: 'current_user'),
        action: () async {
          await api.getCurrentUser();
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'list_memos_normal',
        endpointHint: _endpointHint(
          version: version,
          step: 'list_memos_normal',
        ),
        action: () async {
          await api.listMemos(pageSize: 1, state: 'NORMAL');
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'list_memos_archived',
        endpointHint: _endpointHint(
          version: version,
          step: 'list_memos_archived',
        ),
        action: () async {
          await api.listMemos(pageSize: 1, state: 'ARCHIVED');
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'create_memo',
        endpointHint: _endpointHint(version: version, step: 'create_memo'),
        action: () async {
          final memo = await api.createMemo(
            memoId: memoId,
            content: '$contentPrefix create',
            visibility: 'PRIVATE',
            pinned: false,
          );
          createdMemoUid = memo.uid;
          if (createdMemoUid == null || createdMemoUid!.trim().isEmpty) {
            throw const FormatException('create_memo returned empty uid');
          }
        },
      );

      final memoUid = createdMemoUid!;
      await _runStep(
        failures: failures,
        version: version,
        step: 'update_memo',
        endpointHint: _endpointHint(version: version, step: 'update_memo'),
        action: () async {
          await api.updateMemo(
            memoUid: memoUid,
            content: '$contentPrefix update',
          );
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'archive_memo',
        endpointHint: _endpointHint(version: version, step: 'archive_memo'),
        action: () async {
          await api.updateMemo(memoUid: memoUid, state: 'ARCHIVED');
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'attachment_upload',
        endpointHint: _endpointHint(
          version: version,
          step: 'attachment_upload',
        ),
        action: () async {
          final attachment = await api.createAttachment(
            attachmentId: 'probe-file-$seed',
            filename: 'probe.txt',
            mimeType: 'text/plain',
            bytes: _probeFileBytes,
          );
          createdAttachmentName = attachment.name;
          if (createdAttachmentName == null ||
              createdAttachmentName!.trim().isEmpty) {
            throw const FormatException(
              'attachment_upload returned empty name',
            );
          }
        },
      );

      final attachmentName = createdAttachmentName!;
      await _runStep(
        failures: failures,
        version: version,
        step: 'attachment_bind',
        endpointHint: _endpointHint(version: version, step: 'attachment_bind'),
        action: () async {
          await api.setMemoAttachments(
            memoUid: memoUid,
            attachmentNames: <String>[attachmentName],
          );
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'attachment_list',
        endpointHint: _endpointHint(version: version, step: 'attachment_list'),
        action: () async {
          final expectedUid = _attachmentUidFromName(attachmentName);
          if (version == MemoApiVersion.v021) {
            final memo = await api.getMemo(memoUid: memoUid);
            final exists = memo.attachments.any(
              (item) =>
                  item.name == attachmentName ||
                  item.uid == expectedUid ||
                  _attachmentUidFromName(item.name) == expectedUid,
            );
            if (!exists) {
              throw const FormatException(
                'attachment missing from memo response',
              );
            }
            return;
          }

          final list = await api.listMemoAttachments(memoUid: memoUid);
          final exists = list.any(
            (item) =>
                item.name == attachmentName ||
                item.uid == expectedUid ||
                _attachmentUidFromName(item.name) == expectedUid,
          );
          if (!exists) {
            throw const FormatException(
              'attachment missing from list response',
            );
          }
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'attachment_get',
        endpointHint: _endpointHint(version: version, step: 'attachment_get'),
        action: () async {
          final uid = _attachmentUidFromName(attachmentName);
          if (uid.isEmpty) {
            throw const FormatException('attachment uid is empty');
          }
          await api.getAttachment(attachmentUid: uid);
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'attachment_delete',
        endpointHint: _endpointHint(
          version: version,
          step: 'attachment_delete',
        ),
        action: () async {
          await api.deleteAttachment(attachmentName: attachmentName);
          createdAttachmentName = null;
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'explore',
        endpointHint: _endpointHint(version: version, step: 'explore'),
        action: () async {
          await api.listExploreMemos(pageSize: 1, state: 'NORMAL');
        },
      );

      await _runStep(
        failures: failures,
        version: version,
        step: 'delete_memo',
        endpointHint: _endpointHint(version: version, step: 'delete_memo'),
        action: () async {
          await api.deleteMemo(memoUid: memoUid, force: forceDeleteMemo);
          createdMemoUid = null;
        },
      );
    } on _ProbeStop {
      // Stop at first failed required step.
    } finally {
      if (createdAttachmentName != null && createdAttachmentName!.isNotEmpty) {
        try {
          await api.deleteAttachment(attachmentName: createdAttachmentName!);
        } catch (_) {}
      }
      if (createdMemoUid != null && createdMemoUid!.isNotEmpty) {
        try {
          await api.deleteMemo(
            memoUid: createdMemoUid!,
            force: forceDeleteMemo,
          );
        } catch (_) {}
      }
    }

    return MemoApiVersionProbeReport(
      version: version,
      passed: failures.isEmpty,
      failures: failures,
    );
  }

  Future<void> _runStep({
    required List<MemoApiProbeFailure> failures,
    required MemoApiVersion version,
    required String step,
    required String endpointHint,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error) {
      failures.add(
        _failureFromError(
          version: version,
          step: step,
          endpointHint: endpointHint,
          error: error,
        ),
      );
      throw const _ProbeStop();
    }
  }

  MemoApiProbeFailure _failureFromError({
    required MemoApiVersion version,
    required String step,
    required String endpointHint,
    required Object error,
  }) {
    if (error is DioException) {
      final path = error.requestOptions.path.trim();
      final endpoint = path.isEmpty ? endpointHint : path;
      final statusCode = error.response?.statusCode;
      final reason = _readDioReason(error);
      return MemoApiProbeFailure(
        version: version,
        step: step,
        endpoint: endpoint,
        statusCode: statusCode,
        reason: reason,
      );
    }

    return MemoApiProbeFailure(
      version: version,
      step: step,
      endpoint: endpointHint,
      statusCode: null,
      reason: error.toString(),
    );
  }

  String _readDioReason(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    final message = (error.message ?? '').trim();
    if (message.isNotEmpty) return message;
    return error.type.name;
  }

  String _endpointHint({
    required MemoApiVersion version,
    required String step,
  }) {
    switch (step) {
      case 'current_user':
        return switch (version) {
          MemoApiVersion.v021 => 'api/v2/auth/status',
          MemoApiVersion.v022 ||
          MemoApiVersion.v023 ||
          MemoApiVersion.v024 => 'api/v1/auth/status',
          MemoApiVersion.v025 => 'api/v1/auth/sessions/current',
          MemoApiVersion.v026 => 'api/v1/auth/me',
        };
      case 'list_memos_normal':
      case 'list_memos_archived':
      case 'create_memo':
        return version == MemoApiVersion.v021 ? 'api/v1/memo' : 'api/v1/memos';
      case 'update_memo':
      case 'archive_memo':
      case 'delete_memo':
        return version == MemoApiVersion.v021
            ? 'api/v1/memo/{id}'
            : 'api/v1/memos/{uid}';
      case 'attachment_upload':
        return switch (version) {
          MemoApiVersion.v021 => 'api/v1/resource',
          MemoApiVersion.v022 ||
          MemoApiVersion.v023 ||
          MemoApiVersion.v024 => 'api/v1/resources',
          MemoApiVersion.v025 || MemoApiVersion.v026 => 'api/v1/attachments',
        };
      case 'attachment_bind':
      case 'attachment_list':
        return switch (version) {
          MemoApiVersion.v021 => 'api/v1/memo/{id}',
          MemoApiVersion.v022 ||
          MemoApiVersion.v023 ||
          MemoApiVersion.v024 => 'api/v1/memos/{uid}/resources',
          MemoApiVersion.v025 ||
          MemoApiVersion.v026 => 'api/v1/memos/{uid}/attachments',
        };
      case 'attachment_get':
      case 'attachment_delete':
        return switch (version) {
          MemoApiVersion.v021 => 'api/v1/resource/{id}',
          MemoApiVersion.v022 ||
          MemoApiVersion.v023 ||
          MemoApiVersion.v024 => 'api/v1/resources/{uid}',
          MemoApiVersion.v025 ||
          MemoApiVersion.v026 => 'api/v1/attachments/{uid}',
        };
      case 'explore':
        return version == MemoApiVersion.v021
            ? 'api/v1/memo/all'
            : 'api/v1/memos';
      default:
        return 'api/v1';
    }
  }

  bool _supportsForceDeleteMemo(MemoApiVersion version) {
    return switch (version) {
      MemoApiVersion.v025 || MemoApiVersion.v026 => true,
      MemoApiVersion.v021 ||
      MemoApiVersion.v022 ||
      MemoApiVersion.v023 ||
      MemoApiVersion.v024 => false,
    };
  }

  String _attachmentUidFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.startsWith('attachments/')) {
      return trimmed.substring('attachments/'.length);
    }
    if (trimmed.startsWith('resources/')) {
      return trimmed.substring('resources/'.length);
    }
    return trimmed;
  }

  static const List<int> _probeFileBytes = <int>[
    0x4D,
    0x65,
    0x6D,
    0x6F,
    0x46,
    0x6C,
    0x6F,
    0x77,
    0x20,
    0x41,
    0x50,
    0x49,
    0x20,
    0x70,
    0x72,
    0x6F,
    0x62,
    0x65,
    0x2E,
  ];
}

class _ProbeStop implements Exception {
  const _ProbeStop();
}
