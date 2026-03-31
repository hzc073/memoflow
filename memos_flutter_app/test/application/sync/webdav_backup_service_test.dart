import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_vault_service.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/local_library/local_attachment_store.dart';
import 'package:memos_flutter_app/data/logs/debug_log_store.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/data/models/image_bed_settings.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/models/tag_snapshot.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_password_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_vault_password_repository.dart';
import 'package:memos_flutter_app/data/webdav/webdav_client.dart';
import 'package:memos_flutter_app/state/settings/app_lock_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/reminder_settings_provider.dart';

import '../../test_support.dart';

class _FakeWebDavBackupStateRepository extends WebDavBackupStateRepository {
  _FakeWebDavBackupStateRepository()
    : super(const FlutterSecureStorage(), accountKey: 'test');

  WebDavBackupState value = WebDavBackupState.empty;

  @override
  Future<WebDavBackupState> read() async => value;

  @override
  Future<void> write(WebDavBackupState state) async {
    value = state;
  }

  @override
  Future<void> clear() async {
    value = WebDavBackupState.empty;
  }
}

class _FakeWebDavBackupPasswordRepository
    extends WebDavBackupPasswordRepository {
  _FakeWebDavBackupPasswordRepository()
    : super(const FlutterSecureStorage(), accountKey: 'test');

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String password) async {
    value = password;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _FakeWebDavVaultPasswordRepository extends WebDavVaultPasswordRepository {
  _FakeWebDavVaultPasswordRepository()
    : super(const FlutterSecureStorage(), accountKey: 'test');

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String password) async {
    value = password;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _FakeConfigAdapter implements WebDavSyncLocalAdapter {
  _FakeConfigAdapter({
    required this.snapshot,
    List<ComposeDraftRecord>? drafts,
    this.workspaceKey = 'workspace-1',
  }) : _drafts = List<ComposeDraftRecord>.from(drafts ?? const []);

  final WebDavSyncLocalSnapshot snapshot;
  final String workspaceKey;
  List<ComposeDraftRecord> _drafts;
  List<ComposeDraftRecord>? replacedDrafts;

  @override
  String? get currentWorkspaceKey => workspaceKey;

  @override
  Future<WebDavSyncLocalSnapshot> readSnapshot() async => snapshot;

  @override
  Future<void> applyPreferences(AppPreferences preferences) async {}

  @override
  Future<void> applyAiSettings(AiSettings settings) async {}

  @override
  Future<void> applyReminderSettings(ReminderSettings settings) async {}

  @override
  Future<void> applyImageBedSettings(ImageBedSettings settings) async {}

  @override
  Future<void> applyImageCompressionSettings(
    ImageCompressionSettings settings,
  ) async {}

  @override
  Future<void> applyLocationSettings(LocationSettings settings) async {}

  @override
  Future<void> applyTemplateSettings(MemoTemplateSettings settings) async {}

  @override
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot) async {}

  @override
  Future<void> applyNoteDraft(String text) async {}

  @override
  Future<List<ComposeDraftRecord>> readComposeDrafts() async =>
      List<ComposeDraftRecord>.from(_drafts);

  @override
  Future<void> replaceComposeDrafts(List<ComposeDraftRecord> drafts) async {
    replacedDrafts = List<ComposeDraftRecord>.from(drafts);
    _drafts = List<ComposeDraftRecord>.from(drafts);
  }

  @override
  Future<void> applyTags(TagSnapshot snapshot) async {}

  @override
  Future<void> applyWebDavSettings(WebDavSettings settings) async {}
}

class _PutCall {
  _PutCall(this.uri, this.body);

  final Uri uri;
  final List<int>? body;
}

class _FakeWebDavClient implements WebDavClient {
  _FakeWebDavClient({
    required this.baseUrl,
    this.username = '',
    this.password = '',
    this.authMode = WebDavAuthMode.basic,
    this.ignoreBadCert = false,
    this.logWriter,
    Map<String, WebDavResponse>? responsesBySuffix,
    this.putResponse,
    this.mkcolResponse,
    this.deleteResponse,
  }) : _responsesBySuffix = responsesBySuffix ?? <String, WebDavResponse>{};

  @override
  final Uri baseUrl;

  @override
  final String username;

  @override
  final String password;

  @override
  final WebDavAuthMode authMode;

  @override
  final bool ignoreBadCert;

  @override
  final void Function(DebugLogEntry entry)? logWriter;

  final Map<String, WebDavResponse> _responsesBySuffix;
  final WebDavResponse? putResponse;
  final WebDavResponse? mkcolResponse;
  final WebDavResponse? deleteResponse;

  final List<_PutCall> putCalls = <_PutCall>[];

  @override
  Future<WebDavResponse> get(Uri url, {Map<String, String>? headers}) async {
    for (final entry in _responsesBySuffix.entries) {
      if (url.path.endsWith(entry.key)) {
        return entry.value;
      }
    }
    return WebDavResponse(statusCode: 404, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> head(Uri url, {Map<String, String>? headers}) async {
    return WebDavResponse(statusCode: 404, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> put(
    Uri url, {
    Map<String, String>? headers,
    List<int>? body,
  }) async {
    putCalls.add(_PutCall(url, body));
    return putResponse ??
        WebDavResponse(statusCode: 200, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> mkcol(Uri url, {Map<String, String>? headers}) async {
    return mkcolResponse ??
        WebDavResponse(statusCode: 201, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> delete(Uri url, {Map<String, String>? headers}) async {
    return deleteResponse ??
        WebDavResponse(statusCode: 204, headers: const {}, bytes: const []);
  }

  @override
  Future<void> close() async {}
}

WebDavSyncLocalSnapshot _defaultSnapshot() {
  return WebDavSyncLocalSnapshot(
    preferences: AppPreferences.defaults,
    aiSettings: AiSettings.defaults,
    reminderSettings: ReminderSettings.defaultsFor(AppLanguage.en),
    imageBedSettings: ImageBedSettings.defaults,
    imageCompressionSettings: ImageCompressionSettings.defaults,
    locationSettings: LocationSettings.defaults,
    templateSettings: MemoTemplateSettings.defaults,
    appLockSnapshot: const AppLockSnapshot(
      settings: AppLockSettings.defaults,
      passwordRecord: null,
    ),
    noteDraft: '',
    tagsSnapshot: const TagSnapshot(tags: [], aliases: []),
  );
}

WebDavSettings _backupSettings() {
  return WebDavSettings.defaults.copyWith(
    enabled: true,
    backupEnabled: true,
    backupContentMemos: false,
    backupConfigScope: WebDavBackupConfigScope.safe,
    backupEncryptionMode: WebDavBackupEncryptionMode.plain,
    serverUrl: 'https://example.com',
    username: 'user',
    password: 'pass',
  );
}

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'backupNow uploads empty draft box snapshot when there are no drafts',
    () async {
      final dbName = uniqueDbName('webdav_backup');
      final database = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await database.close();
        await deleteTestDatabase(dbName);
      });

      final adapter = _FakeConfigAdapter(snapshot: _defaultSnapshot());
      final client = _FakeWebDavClient(
        baseUrl: Uri.parse('https://example.com'),
      );
      final service = WebDavBackupService(
        readDatabase: () => database,
        attachmentStore: LocalAttachmentStore(),
        stateRepository: _FakeWebDavBackupStateRepository(),
        passwordRepository: _FakeWebDavBackupPasswordRepository(),
        vaultService: WebDavVaultService(),
        vaultPasswordRepository: _FakeWebDavVaultPasswordRepository(),
        configAdapter: adapter,
        clientFactory:
            ({
              required Uri baseUrl,
              required WebDavSettings settings,
              void Function(DebugLogEntry entry)? logWriter,
            }) => client,
      );

      final result = await service.backupNow(
        settings: _backupSettings(),
        accountKey: 'account',
        activeLocalLibrary: null,
      );

      expect(result, isA<WebDavBackupSuccess>());
      final draftBoxPut = client.putCalls.firstWhere(
        (call) => call.uri.path.endsWith('config/draft_box.json'),
      );
      final payload =
          jsonDecode(utf8.decode(draftBoxPut.body!)) as Map<String, dynamic>;
      expect(payload['data'], isA<Map<String, dynamic>>());
      expect((payload['data'] as Map<String, dynamic>)['drafts'], isEmpty);
    },
  );
}
