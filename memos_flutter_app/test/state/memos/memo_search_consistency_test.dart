import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/memo_sort_order.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/state/memos/link_memo_providers.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'remoteSearchMemosProvider merges local substring matches and filters remote nonmatches',
    () async {
      final dbName = uniqueDbName('remote_search_merge');
      final db = AppDatabase(dbName: dbName);
      final nowSec =
          DateTime.utc(2026, 4, 18, 6, 0).millisecondsSinceEpoch ~/ 1000;
      const phrase = '\u5728\u79e9\u5e8f\u4e2d\u5b89\u987f';

      await _insertMemo(
        db,
        uid: 'memo-local',
        content: phrase,
        createTimeSec: nowSec,
      );

      final server = await _FakeSearchServer.start(
        memos: const <Map<String, Object?>>[
          <String, Object?>{
            'name': 'memos/memo-remote',
            'creator': 'users/1',
            'content': 'remote unrelated',
            'visibility': 'PRIVATE',
            'pinned': false,
            'state': 'NORMAL',
            'createTime': '2026-04-18T06:00:00Z',
            'updateTime': '2026-04-18T06:00:00Z',
            'tags': <String>[],
            'attachments': <Object>[],
          },
        ],
      );
      addTearDown(() async {
        await server.close();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(server.baseUrl),
          ),
        ],
      );
      addTearDown(container.dispose);

      final query = (
        searchQuery: '\u79e9\u5e8f',
        state: 'NORMAL',
        tag: null,
        startTimeSec: null,
        endTimeSecExclusive: null,
        advancedFilters: AdvancedSearchFilters.empty,
        pageSize: 20,
        sortOrder: MemoSortOrder.createDesc,
      );

      final results = await HttpOverrides.runWithHttpOverrides(
        () => container.read(remoteSearchMemosProvider(query).future),
        _PassthroughHttpOverrides(),
      );
      final uids = results.map((memo) => memo.uid).toList(growable: false);

      expect(uids, contains('memo-local'));
      expect(uids, isNot(contains('memo-remote')));
    },
  );

  test(
    'remoteSearchMemosProvider excludes remote-only memos outside current user scope',
    () async {
      final dbName = uniqueDbName('remote_search_user_scope');
      final db = AppDatabase(dbName: dbName);
      final server = await _FakeSearchServer.start(
        memos: const <Map<String, Object?>>[
          <String, Object?>{
            'name': 'memos/memo-mine',
            'creator': 'users/1',
            'content': 'scope needle owned',
            'visibility': 'PRIVATE',
            'pinned': false,
            'state': 'NORMAL',
            'createTime': '2026-04-18T06:00:00Z',
            'updateTime': '2026-04-18T06:00:00Z',
            'tags': <String>[],
            'attachments': <Object>[],
          },
          <String, Object?>{
            'name': 'memos/memo-other',
            'creator': 'users/2',
            'content': 'scope needle other',
            'visibility': 'PUBLIC',
            'pinned': false,
            'state': 'NORMAL',
            'createTime': '2026-04-18T06:01:00Z',
            'updateTime': '2026-04-18T06:01:00Z',
            'tags': <String>[],
            'attachments': <Object>[],
          },
          <String, Object?>{
            'name': 'memos/memo-missing-creator',
            'creator': '',
            'content': 'scope needle untrusted',
            'visibility': 'PUBLIC',
            'pinned': false,
            'state': 'NORMAL',
            'createTime': '2026-04-18T06:02:00Z',
            'updateTime': '2026-04-18T06:02:00Z',
            'tags': <String>[],
            'attachments': <Object>[],
          },
        ],
      );
      addTearDown(() async {
        await server.close();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(server.baseUrl),
          ),
        ],
      );
      addTearDown(container.dispose);

      final query = (
        searchQuery: 'scope needle',
        state: 'NORMAL',
        tag: null,
        startTimeSec: null,
        endTimeSecExclusive: null,
        advancedFilters: AdvancedSearchFilters.empty,
        pageSize: 20,
        sortOrder: MemoSortOrder.createDesc,
      );

      final results = await HttpOverrides.runWithHttpOverrides(
        () => container.read(remoteSearchMemosProvider(query).future),
        _PassthroughHttpOverrides(),
      );
      final uids = results.map((memo) => memo.uid).toList(growable: false);

      expect(uids, contains('memo-mine'));
      expect(uids, isNot(contains('memo-other')));
      expect(uids, isNot(contains('memo-missing-creator')));
    },
  );

  test(
    'remoteSearchMemosProvider keeps local library matches when remote creator is not trusted',
    () async {
      final dbName = uniqueDbName('remote_search_local_scope');
      final db = AppDatabase(dbName: dbName);
      final nowSec =
          DateTime.utc(2026, 4, 18, 6, 0).millisecondsSinceEpoch ~/ 1000;

      await _insertMemo(
        db,
        uid: 'memo-local',
        content: 'local scope needle',
        createTimeSec: nowSec,
      );

      final server = await _FakeSearchServer.start(
        memos: const <Map<String, Object?>>[
          <String, Object?>{
            'name': 'memos/memo-local',
            'creator': 'users/2',
            'content': 'local scope needle',
            'visibility': 'PUBLIC',
            'pinned': false,
            'state': 'NORMAL',
            'createTime': '2026-04-18T06:00:00Z',
            'updateTime': '2026-04-18T06:00:00Z',
            'tags': <String>[],
            'attachments': <Object>[],
          },
        ],
      );
      addTearDown(() async {
        await server.close();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(server.baseUrl),
          ),
        ],
      );
      addTearDown(container.dispose);

      final query = (
        searchQuery: 'scope needle',
        state: 'NORMAL',
        tag: null,
        startTimeSec: null,
        endTimeSecExclusive: null,
        advancedFilters: AdvancedSearchFilters.empty,
        pageSize: 20,
        sortOrder: MemoSortOrder.createDesc,
      );

      final results = await HttpOverrides.runWithHttpOverrides(
        () => container.read(remoteSearchMemosProvider(query).future),
        _PassthroughHttpOverrides(),
      );
      final uids = results.map((memo) => memo.uid).toList(growable: false);

      expect(uids, contains('memo-local'));
    },
  );

  test(
    'LinkMemoController uses the same substring semantics for remote search',
    () async {
      final dbName = uniqueDbName('link_memo_search_merge');
      final db = AppDatabase(dbName: dbName);
      final nowSec =
          DateTime.utc(2026, 4, 18, 7, 0).millisecondsSinceEpoch ~/ 1000;
      const phrase = '\u5728\u79e9\u5e8f\u4e2d\u5b89\u987f';

      await _insertMemo(
        db,
        uid: 'memo-local',
        content: phrase,
        createTimeSec: nowSec,
      );

      final server = await _FakeSearchServer.start(
        memos: const <Map<String, Object?>>[
          <String, Object?>{
            'name': 'memos/memo-remote',
            'creator': 'users/1',
            'content': 'remote unrelated',
            'visibility': 'PRIVATE',
            'pinned': false,
            'state': 'NORMAL',
            'createTime': '2026-04-18T07:00:00Z',
            'updateTime': '2026-04-18T07:00:00Z',
            'tags': <String>[],
            'attachments': <Object>[],
          },
        ],
      );
      addTearDown(() async {
        await server.close();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(server.baseUrl),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(linkMemoControllerProvider);
      final results = await HttpOverrides.runWithHttpOverrides(
        () => controller.loadMemos(query: '  \u79e9\u5e8f  '),
        _PassthroughHttpOverrides(),
      );
      final uids = results.map((memo) => memo.uid).toList(growable: false);

      expect(uids, contains('memo-local'));
      expect(uids, isNot(contains('memo-remote')));
    },
  );

  test(
    'memosStreamProvider sees dirty matches after bounded index maintenance',
    () async {
      final dbName = uniqueDbName('memo_search_provider_dirty_backlog');
      final db = AppDatabase(
        dbName: dbName,
        enableMemoSearchBackgroundMaintenance: false,
      );
      final nowSec =
          DateTime.utc(2026, 4, 18, 8, 0).millisecondsSinceEpoch ~/ 1000;

      for (var index = 0; index < 70; index += 1) {
        final id = index.toString().padLeft(3, '0');
        await _insertMemo(
          db,
          uid: 'memo-$id',
          content: index == 0 ? 'provider needle body' : 'provider body $id',
          createTimeSec: nowSec + index,
        );
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final query = (
        searchQuery: 'needle',
        state: 'NORMAL',
        tag: null,
        startTimeSec: null,
        endTimeSecExclusive: null,
        advancedFilters: AdvancedSearchFilters.empty,
        pageSize: 20,
        sortOrder: MemoSortOrder.createDesc,
      );

      final initialResults = await container.read(
        memosStreamProvider(query).future,
      );
      final initialUids = initialResults
          .map((memo) => memo.uid)
          .toList(growable: false);

      expect(initialUids, isNot(contains('memo-000')));

      expect(await db.drainMemoSearchDirtyEntries(limit: 64), 64);

      final maintainedResults = await container.refresh(
        memosStreamProvider(query).future,
      );
      final maintainedUids = maintainedResults
          .map((memo) => memo.uid)
          .toList(growable: false);
      final dirtyCountRows = await (await db.db).rawQuery(
        'SELECT COUNT(*) AS c FROM memo_search_dirty;',
      );
      final dirtyValue = dirtyCountRows.first['c'];
      final dirtyCount = switch (dirtyValue) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(dirtyValue.toString()) ?? 0,
      };

      expect(maintainedUids, contains('memo-000'));
      expect(dirtyCount, 6);
    },
  );
}

class _PassthroughHttpOverrides extends HttpOverrides {}

Future<void> _insertMemo(
  AppDatabase db, {
  required String uid,
  required String content,
  required int createTimeSec,
}) {
  return db.upsertMemo(
    uid: uid,
    content: content,
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTimeSec: createTimeSec,
    updateTimeSec: createTimeSec,
    tags: const <String>[],
    attachments: const <Map<String, dynamic>>[],
    location: null,
    relationCount: 0,
    syncState: 0,
    lastError: null,
  );
}

class _TestSessionController extends AppSessionController {
  _TestSessionController(Uri baseUrl)
    : _account = Account(
        key: 'users/1',
        baseUrl: baseUrl,
        personalAccessToken: 'test-pat',
        user: const User(
          name: 'users/1',
          username: 'demo',
          displayName: 'Demo User',
          avatarUrl: '',
          description: '',
        ),
        instanceProfile: const InstanceProfile(
          version: '0.27.0',
          mode: '',
          instanceUrl: '',
          owner: '',
        ),
      ),
      super(const AsyncValue.loading()) {
    state = AsyncValue.data(
      AppSessionState(accounts: [_account], currentKey: _account.key),
    );
  }

  final Account _account;

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return _account.instanceProfile;
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) {
    return false;
  }

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) {
    return account.instanceProfile;
  }

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) {
    return '0.27.0';
  }

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}
}

class _FakeSearchServer {
  _FakeSearchServer._(this._server, this.memos);

  final HttpServer _server;
  final List<Map<String, Object?>> memos;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeSearchServer> start({
    required List<Map<String, Object?>> memos,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _FakeSearchServer._(server, memos);
    server.listen(harness._handleRequest);
    return harness;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    await utf8.decoder.bind(request).join();

    if (request.method == 'GET' && request.uri.path == '/api/v1/memos') {
      await _writeJson(request.response, <String, Object?>{
        'memos': memos,
        'nextPageToken': '',
      });
      return;
    }

    await _writeJson(request.response, <String, Object?>{
      'error': 'Unhandled route',
      'method': request.method,
      'path': request.uri.path,
    }, statusCode: HttpStatus.notFound);
  }
}

Future<void> _writeJson(
  HttpResponse response,
  Object payload, {
  int statusCode = HttpStatus.ok,
}) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(payload));
  await response.close();
}
