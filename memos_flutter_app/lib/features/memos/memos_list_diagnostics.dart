import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/sync/sync_types.dart';
import '../../core/log_sanitizer.dart';
import '../../data/logs/sync_queue_progress_tracker.dart';
import '../../data/models/local_memo.dart';
import '../../state/memos/memos_providers.dart';

typedef MemosListDiagnosticsLog =
    void Function(
      String message, {
      Object? error,
      StackTrace? stackTrace,
      Map<String, Object?>? context,
    });

typedef MemosListEmptyViewDiagnosticsLogger =
    Future<void> Function({
      required String queryKey,
      required int providerCount,
      required int animatedCount,
      required String searchQuery,
      required String? resolvedTag,
      required bool useShortcutFilter,
      required bool useQuickSearch,
      required bool useRemoteSearch,
      required int? startTimeSec,
      required int? endTimeSecExclusive,
      required String shortcutFilter,
      required QuickSearchKind? quickSearchKind,
    });

class MemosListDiagnostics {
  MemosListDiagnostics({
    required MemosListDiagnosticsLog debugLog,
    required MemosListDiagnosticsLog infoLog,
    required MemosListEmptyViewDiagnosticsLogger logEmptyViewDiagnostics,
  }) : _debugLog = debugLog,
       _infoLog = infoLog,
       _logEmptyViewDiagnostics = logEmptyViewDiagnostics;

  final MemosListDiagnosticsLog _debugLog;
  final MemosListDiagnosticsLog _infoLog;
  final MemosListEmptyViewDiagnosticsLogger _logEmptyViewDiagnostics;

  String? _lastEmptyDiagnosticKey;
  String? _lastLoadingPhaseKey;
  String? _lastWorkspaceDebugSignature;

  String? get lastWorkspaceDebugSignature => _lastWorkspaceDebugSignature;

  void logPaginationDebug(
    String event, {
    required int pageSize,
    required int resultCount,
    required int lastResultCount,
    required bool loadingMore,
    required bool reachedEnd,
    required bool providerLoading,
    required bool showSearchLanding,
    int? activeRequestId,
    String? activeRequestSource,
    ScrollMetrics? metrics,
    Map<String, Object?>? extra,
  }) {
    final context = <String, Object?>{
      'pageSize': pageSize,
      'resultCount': resultCount,
      'lastResultCount': lastResultCount,
      'loadingMore': loadingMore,
      'reachedEnd': reachedEnd,
      'providerLoading': providerLoading,
      'showSearchLanding': showSearchLanding,
      if (activeRequestId != null) 'activeRequestId': activeRequestId,
      if (activeRequestSource != null)
        'activeRequestSource': activeRequestSource,
      if (metrics != null) ...<String, Object?>{
        'pixels': metrics.pixels,
        'maxScrollExtent': metrics.maxScrollExtent,
        'viewportDimension': metrics.viewportDimension,
        'axis': metrics.axis.name,
      },
      if (extra != null) ...extra,
    };
    _debugLog('Memos pagination: $event', context: context);
  }

  void logVisibleCountDecrease({
    required int beforeLength,
    required int afterLength,
    required bool signatureChanged,
    required bool listChanged,
    required String fromSignature,
    required String toSignature,
    required List<String> removedSample,
  }) {
    if (afterLength >= beforeLength) return;
    _infoLog(
      'Memos list: visible_count_decreased',
      context: <String, Object?>{
        'beforeLength': beforeLength,
        'afterLength': afterLength,
        'decreasedBy': beforeLength - afterLength,
        'signatureChanged': signatureChanged,
        'listChanged': listChanged,
        'fromSignature': fromSignature,
        'toSignature': toSignature,
        if (removedSample.isNotEmpty) 'removedSample': removedSample,
      },
    );
  }

  void maybeLogEmptyViewDiagnostics({
    required bool debugMode,
    required String queryKey,
    required List<LocalMemo>? memosValue,
    required bool memosLoading,
    required Object? memosError,
    required List<LocalMemo> visibleMemos,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) {
    if (!debugMode) return;
    if (memosValue == null || memosLoading || memosError != null) return;
    if (visibleMemos.isNotEmpty) return;
    final providerCount = memosValue.length;
    final safeQueryKey = _redactQueryKey(queryKey);
    final diagnosticKey =
        '$safeQueryKey|provider:$providerCount|animated:${visibleMemos.length}';
    if (_lastEmptyDiagnosticKey == diagnosticKey) return;
    _lastEmptyDiagnosticKey = diagnosticKey;
    unawaited(
      logEmptyViewDiagnostics(
        queryKey: queryKey,
        providerCount: providerCount,
        animatedCount: visibleMemos.length,
        searchQuery: searchQuery,
        resolvedTag: resolvedTag,
        useShortcutFilter: useShortcutFilter,
        useQuickSearch: useQuickSearch,
        useRemoteSearch: useRemoteSearch,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        shortcutFilter: shortcutFilter,
        quickSearchKind: quickSearchKind,
      ),
    );
  }

  Future<void> logEmptyViewDiagnostics({
    required String queryKey,
    required int providerCount,
    required int animatedCount,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) {
    return _logEmptyViewDiagnostics(
      queryKey: queryKey,
      providerCount: providerCount,
      animatedCount: animatedCount,
      searchQuery: searchQuery,
      resolvedTag: resolvedTag,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useRemoteSearch: useRemoteSearch,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      shortcutFilter: shortcutFilter,
      quickSearchKind: quickSearchKind,
    );
  }

  String describeSyncState(SyncFlowStatus state) {
    if (state.running) return 'loading';
    if (state.lastError != null) return 'error';
    if (state.lastSuccessAt != null) return 'value';
    return 'idle';
  }

  String buildMemosLoadingPhase({
    required bool memosLoading,
    required bool hasProviderValue,
    required Object? memosError,
    required int providerCount,
    required int animatedCount,
  }) {
    if (memosError != null) return 'provider_error';
    if (memosLoading && !hasProviderValue) return 'initial_loading';
    if (memosLoading && hasProviderValue) return 'refreshing_with_cached';
    if (!hasProviderValue) return 'no_provider_value';
    if (providerCount > 0) return 'data_ready';
    if (animatedCount > 0) return 'rendering_cached';
    return 'data_empty';
  }

  void maybeLogMemosLoadingPhase({
    required bool debugMode,
    required String queryKey,
    required bool memosLoading,
    required Object? memosError,
    required List<LocalMemo>? memosValue,
    required List<LocalMemo> visibleMemos,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
    required SyncFlowStatus syncState,
    required SyncQueueProgressSnapshot syncQueueSnapshot,
    required int pageSize,
    required bool reachedEnd,
    required bool loadingMore,
    required bool providerLoading,
    required bool showSearchLanding,
  }) {
    if (!debugMode) return;
    final hasProviderValue = memosValue != null;
    final providerCount = memosValue?.length ?? 0;
    final animatedCount = visibleMemos.length;
    final phase = buildMemosLoadingPhase(
      memosLoading: memosLoading,
      hasProviderValue: hasProviderValue,
      memosError: memosError,
      providerCount: providerCount,
      animatedCount: animatedCount,
    );
    final key = [
      phase,
      _redactQueryKey(queryKey),
      memosLoading,
      hasProviderValue,
      providerCount,
      animatedCount,
      pageSize,
      reachedEnd,
      loadingMore,
      describeSyncState(syncState),
      syncQueueSnapshot.syncing,
      syncQueueSnapshot.totalTasks,
      syncQueueSnapshot.completedTasks,
      syncQueueSnapshot.currentOutboxId,
      syncQueueSnapshot.currentProgress?.toStringAsFixed(2) ?? '-',
      useShortcutFilter,
      useQuickSearch,
      useRemoteSearch,
      _redactFilterValue(shortcutFilter.trim(), kind: 'shortcut_filter'),
      quickSearchKind?.name ?? '-',
    ].join('|');
    if (_lastLoadingPhaseKey == key) return;
    _lastLoadingPhaseKey = key;

    _infoLog(
      'Memos loading: phase',
      context: <String, Object?>{
        'phase': phase,
        'queryKeyFingerprint': _redactQueryKey(queryKey),
        'memosLoading': memosLoading,
        'hasProviderValue': hasProviderValue,
        'providerCount': providerCount,
        'animatedCount': animatedCount,
        'pageSize': pageSize,
        'reachedEnd': reachedEnd,
        'loadingMore': loadingMore,
        'providerLoading': providerLoading,
        'showSearchLanding': showSearchLanding,
        'syncState': describeSyncState(syncState),
        'queueSyncing': syncQueueSnapshot.syncing,
        'queueTotalTasks': syncQueueSnapshot.totalTasks,
        'queueCompletedTasks': syncQueueSnapshot.completedTasks,
        'queueCurrentOutboxId': syncQueueSnapshot.currentOutboxId,
        'queueCurrentProgress': syncQueueSnapshot.currentProgress,
        'useShortcutFilter': useShortcutFilter,
        'useQuickSearch': useQuickSearch,
        'useRemoteSearch': useRemoteSearch,
        ..._buildRedactedTextLogFields(
          shortcutFilter,
          kind: 'shortcut_filter',
          fingerprintKey: 'shortcutFilterFingerprint',
          lengthKey: 'shortcutFilterLength',
        ),
        if (quickSearchKind != null) 'quickSearchKind': quickSearchKind.name,
        if (memosError != null)
          'error': LogSanitizer.sanitizeText(memosError.toString()),
      },
    );
  }

  void maybeLogWorkspaceDebug({
    required bool debugMode,
    required String? currentKey,
    required String? resolvedDbName,
    required String workspaceMode,
    required Object? currentLocalLibrary,
    required String? localLibraryKey,
    required String? localLibraryName,
    required String? localLibraryLocation,
  }) {
    if (!debugMode) return;
    final debugSignature = [
      currentKey ?? '',
      resolvedDbName ?? '',
      workspaceMode,
      localLibraryKey ?? '',
      localLibraryName ?? '',
      localLibraryLocation ?? '',
    ].join('|');
    if (_lastWorkspaceDebugSignature == debugSignature) return;
    _lastWorkspaceDebugSignature = debugSignature;
    _infoLog(
      'MemosList build: workspace_debug',
      context: <String, Object?>{
        'event': 'build',
        'currentKey': currentKey,
        'resolvedDbName': resolvedDbName,
        'workspaceMode': workspaceMode,
        'currentLocalLibraryNull': currentLocalLibrary == null,
        'localLibraryKey': localLibraryKey,
        'localLibraryName': localLibraryName,
        'localLibraryLocation': localLibraryLocation,
      },
    );
  }
}

String _redactQueryKey(String queryKey) {
  return _redactFilterValue(queryKey.trim(), kind: 'memos_query_key');
}

String _redactFilterValue(String value, {required String kind}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return LogSanitizer.redactSemanticText(trimmed, kind: kind);
}

Map<String, Object?> _buildRedactedTextLogFields(
  String value, {
  required String kind,
  required String fingerprintKey,
  required String lengthKey,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const <String, Object?>{};
  return <String, Object?>{
    fingerprintKey: LogSanitizer.redactSemanticText(trimmed, kind: kind),
    lengthKey: trimmed.length,
  };
}
