import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/local_library_scan_service.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/local_library_scanner.dart';

typedef MemosListLocalLibraryRead =
    T Function<T>(ProviderListenable<T> provider);

abstract interface class MemosListLocalLibraryPromptDelegate {
  Future<bool> confirmManualScan();

  Future<bool> resolveConflict(LocalScanConflict conflict);

  void showSyncBusy();

  void showScanSuccess();

  void showScanFailure(Object error);
}

abstract interface class MemosListLocalLibraryAdapter {
  LocalLibraryScanService? currentScanner();

  SyncFlowStatus currentSyncStatus();

  Future<bool> hasAnyLocalMemos();

  Future<void> requestMemosSync();
}

class RiverpodMemosListLocalLibraryAdapter
    implements MemosListLocalLibraryAdapter {
  RiverpodMemosListLocalLibraryAdapter({
    required MemosListLocalLibraryRead read,
  }) : _read = read;

  final MemosListLocalLibraryRead _read;

  @override
  LocalLibraryScanService? currentScanner() {
    return _read(localLibraryScannerProvider);
  }

  @override
  SyncFlowStatus currentSyncStatus() {
    return _read(syncCoordinatorProvider).memos;
  }

  @override
  Future<bool> hasAnyLocalMemos() {
    return _read(memosListControllerProvider).hasAnyLocalMemos();
  }

  @override
  Future<void> requestMemosSync() {
    return _read(syncCoordinatorProvider.notifier).requestSync(
      const SyncRequest(
        kind: SyncRequestKind.memos,
        reason: SyncRequestReason.manual,
      ),
    );
  }
}

class MemosListLocalLibraryCoordinator extends ChangeNotifier {
  MemosListLocalLibraryCoordinator({
    required MemosListLocalLibraryRead read,
    MemosListLocalLibraryAdapter? adapterOverride,
    String Function(SyncError error)? errorFormatter,
    DateTime Function()? now,
    void Function(Object error)? onAutoScanFailure,
    int bootstrapImportThreshold = 50,
  }) : _adapter =
           adapterOverride ?? RiverpodMemosListLocalLibraryAdapter(read: read),
       _errorFormatter =
           errorFormatter ?? ((error) => error.message ?? error.toString()),
       _now = now ?? DateTime.now,
       _onAutoScanFailure = onAutoScanFailure,
       _bootstrapImportThreshold = bootstrapImportThreshold;

  final MemosListLocalLibraryAdapter _adapter;
  final String Function(SyncError error) _errorFormatter;
  final DateTime Function() _now;
  final void Function(Object error)? _onAutoScanFailure;
  final int _bootstrapImportThreshold;

  bool _autoScanTriggered = false;
  bool _autoScanInFlight = false;
  bool _bootstrapImportActive = false;
  int _bootstrapImportTotal = 0;
  DateTime? _bootstrapImportStartedAt;

  bool get autoScanTriggered => _autoScanTriggered;
  bool get autoScanInFlight => _autoScanInFlight;
  bool get bootstrapImportActive => _bootstrapImportActive;
  int get bootstrapImportTotal => _bootstrapImportTotal;
  DateTime? get bootstrapImportStartedAt => _bootstrapImportStartedAt;

  void markAutoScanTriggered() {
    if (_autoScanTriggered) return;
    _autoScanTriggered = true;
    notifyListeners();
  }

  Future<void> runManualScan(
    MemosListLocalLibraryPromptDelegate prompts,
  ) async {
    if (_adapter.currentSyncStatus().running) {
      prompts.showSyncBusy();
      return;
    }
    final confirmed = await prompts.confirmManualScan();
    if (!confirmed) return;
    if (_adapter.currentSyncStatus().running) {
      prompts.showSyncBusy();
      return;
    }
    final scanner = _adapter.currentScanner();
    if (scanner == null) return;

    try {
      var result = await scanner.scanAndMerge(forceDisk: false);
      while (result is LocalScanConflictResult) {
        final decisions = <String, bool>{};
        for (final conflict in result.conflicts) {
          decisions[conflict.memoUid] = await prompts.resolveConflict(conflict);
        }
        result = await scanner.scanAndMerge(
          forceDisk: false,
          conflictDecisions: decisions,
        );
      }
      switch (result) {
        case LocalScanSuccess():
          prompts.showScanSuccess();
          return;
        case LocalScanFailure(:final error):
          prompts.showScanFailure(formatLocalScanError(error));
          return;
        default:
          return;
      }
    } catch (error) {
      prompts.showScanFailure(error);
    }
  }

  Future<void> maybeAutoScan({
    required bool hasCurrentLibrary,
    required int normalMemoCount,
    required bool syncRunning,
  }) async {
    if (_autoScanTriggered || _autoScanInFlight) return;
    if (!hasCurrentLibrary || syncRunning || normalMemoCount > 0) return;

    final scanner = _adapter.currentScanner();
    if (scanner == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_autoScanTriggered || _autoScanInFlight) return;
      _autoScanInFlight = true;
      var bootstrapModeEnabled = false;
      notifyListeners();
      try {
        final hasLocalMemos = await _adapter.hasAnyLocalMemos();
        if (hasLocalMemos) return;

        final diskMemos = await scanner.fileSystem.listMemos();
        if (diskMemos.isEmpty) return;
        if (diskMemos.length >= _bootstrapImportThreshold) {
          bootstrapModeEnabled = true;
          _bootstrapImportActive = true;
          _bootstrapImportTotal = diskMemos.length;
          _bootstrapImportStartedAt = _now();
          notifyListeners();
        }
        _autoScanTriggered = true;
        notifyListeners();
        await _adapter.requestMemosSync();
      } catch (error) {
        _onAutoScanFailure?.call(error);
      } finally {
        if (bootstrapModeEnabled) {
          _bootstrapImportActive = false;
          _bootstrapImportTotal = 0;
          _bootstrapImportStartedAt = null;
        }
        _autoScanInFlight = false;
        notifyListeners();
      }
    });
  }

  String formatLocalScanError(SyncError error) {
    return _errorFormatter(error);
  }
}
