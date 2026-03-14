import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memo_relations.dart';
import '../../core/tags.dart';
import '../../data/api/server_api_profile.dart';
import '../../data/db/app_database.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/shortcut.dart';
import '../system/database_provider.dart';
import '../system/logging_provider.dart';
import 'create_memo_outbox_payload.dart';
import 'memo_timeline_provider.dart';
import 'memos_providers.dart';
import '../system/reminder_scheduler.dart';
import '../system/session_provider.dart';
import '../settings/user_settings_provider.dart';
part 'memos_list_controller.dart';
part 'memos_list_outbox_parser.dart';

class OutboxMemoStatus {
  const OutboxMemoStatus({required this.pending, required this.failed});
  const OutboxMemoStatus.empty()
    : pending = const <String>{},
      failed = const <String>{};

  final Set<String> pending;
  final Set<String> failed;
}

class MemosListPendingAttachment {
  const MemosListPendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

class MemosListMemoResolveResult {
  const MemosListMemoResolveResult._({this.memo, this.error});
  const MemosListMemoResolveResult.found(LocalMemo memo) : this._(memo: memo);
  const MemosListMemoResolveResult.notFound() : this._();
  const MemosListMemoResolveResult.error(Object error) : this._(error: error);

  final LocalMemo? memo;
  final Object? error;

  bool get isFound => memo != null;
  bool get isNotFound => memo == null && error == null;
  bool get isError => error != null;
}

class MemosListShortcutHints {
  const MemosListShortcutHints({
    required this.useLocalShortcuts,
    required this.canCreateShortcut,
  });

  final bool useLocalShortcuts;
  final bool canCreateShortcut;
}

final memosListControllerProvider = Provider<MemosListController>((ref) {
  return MemosListController(ref);
});

final memosListOutboxStatusProvider = StreamProvider<OutboxMemoStatus>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);

  Future<OutboxMemoStatus> load() async {
    final sqlite = await db.db;
    final rows = await sqlite.query(
      'outbox',
      columns: const ['type', 'payload', 'state'],
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: const [
        AppDatabase.outboxStatePending,
        AppDatabase.outboxStateRunning,
        AppDatabase.outboxStateRetry,
        AppDatabase.outboxStateError,
      ],
      orderBy: 'id ASC',
    );
    final pending = <String>{};
    final failed = <String>{};

    for (final row in rows) {
      final type = row['type'];
      final payload = row['payload'];
      final state = row['state'];
      if (type is! String || payload is! String) continue;

      final decoded = _decodeOutboxPayload(payload);
      final uid = _extractOutboxMemoUid(type, decoded);
      if (uid == null || uid.trim().isEmpty) continue;
      final normalized = uid.trim();

      final stateCode = switch (state) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };
      if (stateCode == AppDatabase.outboxStateError) {
        failed.add(normalized);
        pending.remove(normalized);
      } else {
        if (!failed.contains(normalized)) {
          pending.add(normalized);
        }
      }
    }

    return OutboxMemoStatus(pending: pending, failed: failed);
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final memosListNormalMemoCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<int> load() async {
    final sqlite = await db.db;
    final rows = await sqlite.rawQuery('''
      SELECT COUNT(*) AS memo_count
      FROM memos
      WHERE state = 'NORMAL'
    ''');
    if (rows.isEmpty) return 0;
    final raw = rows.first['memo_count'];
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final memosListShortcutHintsProvider = Provider<MemosListShortcutHints>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    return const MemosListShortcutHints(
      useLocalShortcuts: true,
      canCreateShortcut: false,
    );
  }
  final api = ref.watch(memosApiProvider);
  final useLocalShortcuts =
      api.usesLegacySearchFilterDialect || api.shortcutsSupportedHint == false;
  final canCreateShortcut =
      useLocalShortcuts || api.shortcutsSupportedHint != false;
  return MemosListShortcutHints(
    useLocalShortcuts: useLocalShortcuts,
    canCreateShortcut: canCreateShortcut,
  );
});

final memosListDebugApiVersionTextProvider = Provider<String>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  final resolution = account == null
      ? null
      : MemosServerApiProfiles.resolve(
          manualVersionOverride: account.serverVersionOverride,
          detectedVersion: account.instanceProfile.version,
        );
  return _buildDebugApiVersionText(resolution);
});
