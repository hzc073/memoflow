part of '../webdav_backup_service.dart';

mixin _WebDavBackupProgressMixin on _WebDavBackupServiceBase {
  @override
  void _logEvent(String label, {String? detail, Object? error}) {
    final writer = _logWriter;
    if (writer == null) return;
    writer(
      DebugLogEntry(
        timestamp: DateTime.now(),
        category: 'webdav',
        label: label,
        detail: detail,
        error: error == null
            ? null
            : LogSanitizer.sanitizeText(error.toString()),
      ),
    );
  }

  @override
  void _startProgress(WebDavBackupProgressOperation operation) {
    _progressTracker?.start(operation: operation);
  }

  @override
  void _updateProgress({
    WebDavBackupProgressStage? stage,
    int? completed,
    int? total,
    String? currentPath,
    WebDavBackupProgressItemGroup? itemGroup,
  }) {
    _progressTracker?.update(
      stage: stage,
      completed: completed,
      total: total,
      currentPath: currentPath,
      itemGroup: itemGroup,
    );
  }

  @override
  Future<void> _waitIfPaused() async {
    final tracker = _progressTracker;
    if (tracker == null) return;
    await tracker.waitIfPaused();
  }

  @override
  void _finishProgress() {
    _progressTracker?.finish();
  }

  @override
  Future<void> _setWakelockEnabled(bool enabled) async {
    if (kIsWeb) return;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  @override
  WebDavBackupProgressItemGroup _progressItemGroupForPath(String rawPath) {
    final path = rawPath.trim();
    if (path.isEmpty) return WebDavBackupProgressItemGroup.other;
    if (path == _backupManifestFile ||
        path == _plainBackupIndexFile ||
        path.endsWith('.enc')) {
      return WebDavBackupProgressItemGroup.manifest;
    }
    if (_configTypeForPath(path) != null) {
      return WebDavBackupProgressItemGroup.config;
    }
    if (_isMemoPath(path)) {
      return WebDavBackupProgressItemGroup.memo;
    }
    if (_isAttachmentPath(path)) {
      return WebDavBackupProgressItemGroup.attachment;
    }
    return WebDavBackupProgressItemGroup.other;
  }

  @override
  Duration _scheduleDuration(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.daily => const Duration(days: 1),
      WebDavBackupSchedule.weekly => const Duration(days: 7),
      WebDavBackupSchedule.monthly => const Duration(days: 30),
      WebDavBackupSchedule.onOpen => Duration.zero,
      WebDavBackupSchedule.manual => Duration.zero,
    };
  }

  @override
  DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = min(date.day, lastDayOfMonth);
    return DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  @override
  bool _isBackupDue(DateTime? last, WebDavBackupSchedule schedule) {
    if (schedule == WebDavBackupSchedule.manual) return false;
    if (schedule == WebDavBackupSchedule.onOpen) return true;
    if (last == null) return true;
    if (schedule == WebDavBackupSchedule.monthly) {
      final next = _addMonths(last, 1);
      final now = DateTime.now();
      return !now.isBefore(next);
    }
    final diff = DateTime.now().difference(last);
    return diff >= _scheduleDuration(schedule);
  }

  @override
  DateTime? _parseIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
