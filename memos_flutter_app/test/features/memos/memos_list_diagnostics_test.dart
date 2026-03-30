import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/data/logs/sync_queue_progress_tracker.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/features/memos/memos_list_diagnostics.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  test('maybeLogEmptyViewDiagnostics skips work outside debug mode', () async {
    var emptyDiagnosticsCalls = 0;
    final diagnostics = MemosListDiagnostics(
      debugLog: (_, {error, stackTrace, context}) {},
      infoLog: (_, {error, stackTrace, context}) {},
      logEmptyViewDiagnostics:
          ({
            required queryKey,
            required providerCount,
            required animatedCount,
            required searchQuery,
            required resolvedTag,
            required useShortcutFilter,
            required useQuickSearch,
            required useRemoteSearch,
            required startTimeSec,
            required endTimeSecExclusive,
            required shortcutFilter,
            required quickSearchKind,
          }) async {
            emptyDiagnosticsCalls++;
          },
    );

    diagnostics.maybeLogEmptyViewDiagnostics(
      debugMode: false,
      queryKey: 'NORMAL|tag|secret query|shortcut filter',
      memosValue: const <LocalMemo>[],
      memosLoading: false,
      memosError: null,
      visibleMemos: const <LocalMemo>[],
      searchQuery: 'secret query',
      resolvedTag: 'tag',
      useShortcutFilter: false,
      useQuickSearch: false,
      useRemoteSearch: true,
      startTimeSec: null,
      endTimeSecExclusive: null,
      shortcutFilter: 'shortcut filter',
      quickSearchKind: null,
    );

    await Future<void>.delayed(Duration.zero);

    expect(emptyDiagnosticsCalls, 0);
  });

  test('maybeLogMemosLoadingPhase redacts query metadata', () {
    Map<String, Object?>? capturedContext;
    final diagnostics = MemosListDiagnostics(
      debugLog: (_, {error, stackTrace, context}) {},
      infoLog: (message, {error, stackTrace, context}) {
        if (message == 'Memos loading: phase') {
          capturedContext = context;
        }
      },
      logEmptyViewDiagnostics:
          ({
            required queryKey,
            required providerCount,
            required animatedCount,
            required searchQuery,
            required resolvedTag,
            required useShortcutFilter,
            required useQuickSearch,
            required useRemoteSearch,
            required startTimeSec,
            required endTimeSecExclusive,
            required shortcutFilter,
            required quickSearchKind,
          }) async {},
    );

    diagnostics.maybeLogMemosLoadingPhase(
      debugMode: true,
      queryKey: 'NORMAL|tag|secret query|shortcut filter',
      memosLoading: false,
      memosError: null,
      memosValue: const <LocalMemo>[],
      visibleMemos: const <LocalMemo>[],
      useShortcutFilter: true,
      useQuickSearch: false,
      useRemoteSearch: false,
      shortcutFilter: 'shortcut filter',
      quickSearchKind: QuickSearchKind.attachments,
      syncState: SyncFlowStatus.idle,
      syncQueueSnapshot: SyncQueueProgressSnapshot.idle,
      pageSize: 50,
      reachedEnd: true,
      loadingMore: false,
      providerLoading: false,
      showSearchLanding: false,
    );

    expect(capturedContext, isNotNull);
    expect(capturedContext!.containsKey('queryKey'), isFalse);
    expect(capturedContext!['queryKeyFingerprint'], isA<String>());
    expect(
      (capturedContext!['queryKeyFingerprint'] as String).contains(
        'secret query',
      ),
      isFalse,
    );
    expect(capturedContext!.containsKey('shortcutFilter'), isFalse);
    expect(capturedContext!['shortcutFilterFingerprint'], isA<String>());
    expect(
      (capturedContext!['shortcutFilterFingerprint'] as String).contains(
        'shortcut filter',
      ),
      isFalse,
    );
    expect(capturedContext!['shortcutFilterLength'], 'shortcut filter'.length);
  });
}
