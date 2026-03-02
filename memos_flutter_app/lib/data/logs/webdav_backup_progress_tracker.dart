import 'dart:async';

import 'package:flutter/foundation.dart';

enum WebDavBackupProgressOperation { backup, restore }

enum WebDavBackupProgressStage {
  preparing,
  exporting,
  uploading,
  writingManifest,
  downloading,
  writing,
  scanning,
  completed,
}

enum WebDavBackupProgressItemGroup {
  memo,
  attachment,
  config,
  manifest,
  other,
}

class WebDavBackupProgressSnapshot {
  const WebDavBackupProgressSnapshot({
    required this.running,
    required this.paused,
    required this.operation,
    required this.stage,
    required this.completed,
    required this.total,
    required this.currentPath,
    required this.itemGroup,
  });

  static const idle = WebDavBackupProgressSnapshot(
    running: false,
    paused: false,
    operation: null,
    stage: null,
    completed: 0,
    total: 0,
    currentPath: null,
    itemGroup: null,
  );

  final bool running;
  final bool paused;
  final WebDavBackupProgressOperation? operation;
  final WebDavBackupProgressStage? stage;
  final int completed;
  final int total;
  final String? currentPath;
  final WebDavBackupProgressItemGroup? itemGroup;

  double? get progress {
    if (!running) return null;
    if (total <= 0) return null;
    final safeTotal = total <= 0 ? 1 : total;
    final safeCompleted = completed < 0
        ? 0
        : (completed > safeTotal ? safeTotal : completed);
    return (safeCompleted / safeTotal).clamp(0.0, 1.0).toDouble();
  }

  WebDavBackupProgressSnapshot copyWith({
    bool? running,
    bool? paused,
    WebDavBackupProgressOperation? operation,
    WebDavBackupProgressStage? stage,
    int? completed,
    int? total,
    String? currentPath,
    WebDavBackupProgressItemGroup? itemGroup,
  }) {
    return WebDavBackupProgressSnapshot(
      running: running ?? this.running,
      paused: paused ?? this.paused,
      operation: operation ?? this.operation,
      stage: stage ?? this.stage,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      currentPath: currentPath ?? this.currentPath,
      itemGroup: itemGroup ?? this.itemGroup,
    );
  }
}

class WebDavBackupProgressTracker extends ChangeNotifier {
  WebDavBackupProgressSnapshot _snapshot = WebDavBackupProgressSnapshot.idle;
  Completer<void>? _pauseCompleter;

  WebDavBackupProgressSnapshot get snapshot => _snapshot;

  bool get paused => _snapshot.paused;

  void start({required WebDavBackupProgressOperation operation}) {
    _pauseCompleter?.complete();
    _pauseCompleter = null;
    _setSnapshot(
      WebDavBackupProgressSnapshot(
        running: true,
        paused: false,
        operation: operation,
        stage: WebDavBackupProgressStage.preparing,
        completed: 0,
        total: 0,
        currentPath: null,
        itemGroup: null,
      ),
    );
  }

  void update({
    WebDavBackupProgressStage? stage,
    int? completed,
    int? total,
    String? currentPath,
    WebDavBackupProgressItemGroup? itemGroup,
  }) {
    if (!_snapshot.running) return;
    _setSnapshot(
      _snapshot.copyWith(
        stage: stage,
        completed: completed,
        total: total,
        currentPath: currentPath,
        itemGroup: itemGroup,
      ),
    );
  }

  void pauseIfRunning() {
    if (!_snapshot.running || _snapshot.paused) return;
    _pauseCompleter ??= Completer<void>();
    _setSnapshot(_snapshot.copyWith(paused: true));
  }

  void resume() {
    if (!_snapshot.paused) return;
    _pauseCompleter?.complete();
    _pauseCompleter = null;
    _setSnapshot(_snapshot.copyWith(paused: false));
  }

  Future<void> waitIfPaused() async {
    if (!_snapshot.paused) return;
    final completer = _pauseCompleter;
    if (completer == null) return;
    await completer.future;
  }

  void finish() {
    _pauseCompleter?.complete();
    _pauseCompleter = null;
    _setSnapshot(WebDavBackupProgressSnapshot.idle);
  }

  void _setSnapshot(WebDavBackupProgressSnapshot next) {
    final prev = _snapshot;
    final unchanged =
        prev.running == next.running &&
        prev.paused == next.paused &&
        prev.operation == next.operation &&
        prev.stage == next.stage &&
        prev.completed == next.completed &&
        prev.total == next.total &&
        prev.currentPath == next.currentPath &&
        prev.itemGroup == next.itemGroup;
    if (unchanged) return;
    _snapshot = next;
    notifyListeners();
  }
}
