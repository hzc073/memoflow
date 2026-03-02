import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_vault_service.dart';
import 'package:memos_flutter_app/data/logs/debug_log_store.dart';
import 'package:memos_flutter_app/data/models/image_bed_settings.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_state.dart';
import 'package:memos_flutter_app/data/settings/ai_settings_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_vault_password_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_device_id_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_sync_state_repository.dart';
import 'package:memos_flutter_app/data/webdav/webdav_client.dart';
import 'package:memos_flutter_app/state/app_lock_provider.dart';
import 'package:memos_flutter_app/state/preferences_provider.dart';
import 'package:memos_flutter_app/state/reminder_settings_provider.dart';

const _preferencesFile = 'preferences.json';
const _aiFile = 'ai_settings.json';
const _reminderFile = 'reminder_settings.json';
const _imageBedFile = 'image_bed.json';
const _locationFile = 'location_settings.json';
const _templateFile = 'template_settings.json';
const _appLockFile = 'app_lock.json';
const _draftFile = 'note_draft.json';
const _metaFile = 'meta.json';

class FakeWebDavSyncStateRepository implements WebDavSyncStateRepository {
  FakeWebDavSyncStateRepository(this.state);

  WebDavSyncState state;
  WebDavSyncState? lastWritten;

  @override
  Future<WebDavSyncState> read() async => state;

  @override
  Future<void> write(WebDavSyncState state) async {
    lastWritten = state;
  }

  @override
  Future<void> clear() async {
    state = WebDavSyncState.empty;
  }
}

class FakeWebDavDeviceIdRepository implements WebDavDeviceIdRepository {
  FakeWebDavDeviceIdRepository(this.deviceId);

  final String deviceId;

  @override
  Future<String> readOrCreate() async => deviceId;
}

class FakeWebDavVaultPasswordRepository extends WebDavVaultPasswordRepository {
  FakeWebDavVaultPasswordRepository() : super(const FlutterSecureStorage(), accountKey: 'test');

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

class FakeWebDavSyncLocalAdapter implements WebDavSyncLocalAdapter {
  FakeWebDavSyncLocalAdapter(this.snapshot);

  final WebDavSyncLocalSnapshot snapshot;

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
  Future<void> applyLocationSettings(LocationSettings settings) async {}

  @override
  Future<void> applyTemplateSettings(MemoTemplateSettings settings) async {}

  @override
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot) async {}

  @override
  Future<void> applyNoteDraft(String text) async {}

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
    Map<String, WebDavResponse>? responsesByName,
  }) : _responsesByName = responsesByName ?? <String, WebDavResponse>{};

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

  final Map<String, WebDavResponse> _responsesByName;
  final List<_PutCall> putCalls = <_PutCall>[];
  final List<Uri> mkcolCalls = <Uri>[];
  final List<String> getCalls = <String>[];

  @override
  Future<void> close() async {}

  @override
  Future<WebDavResponse> get(Uri url, {Map<String, String>? headers}) async {
    final name = url.pathSegments.isNotEmpty ? url.pathSegments.last : '';
    getCalls.add(name);
    return _responsesByName[name] ??
        WebDavResponse(statusCode: 404, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> head(Uri url, {Map<String, String>? headers}) async {
    return WebDavResponse(statusCode: 200, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> put(
    Uri url, {
    Map<String, String>? headers,
    List<int>? body,
  }) async {
    putCalls.add(_PutCall(url, body));
    return WebDavResponse(statusCode: 200, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> mkcol(Uri url, {Map<String, String>? headers}) async {
    mkcolCalls.add(url);
    return WebDavResponse(statusCode: 201, headers: const {}, bytes: const []);
  }

  @override
  Future<WebDavResponse> delete(Uri url, {Map<String, String>? headers}) async {
    return WebDavResponse(statusCode: 200, headers: const {}, bytes: const []);
  }
}

String _preferencesHash(AppPreferences prefs) {
  final json = Map<String, dynamic>.from(prefs.toJson())
    ..remove('lastSeenAppVersion')
    ..remove('lastSeenAnnouncementVersion')
    ..remove('lastSeenAnnouncementId')
    ..remove('lastSeenNoticeHash')
    ..remove('fontFile')
    ..remove('homeInitialLoadingOverlayShown');
  final encoded = jsonEncode(json);
  return sha256.convert(utf8.encode(encoded)).toString();
}

String _jsonHash(Map<String, dynamic> json) {
  final encoded = jsonEncode(json);
  return sha256.convert(utf8.encode(encoded)).toString();
}

WebDavSyncLocalSnapshot _defaultSnapshot() {
  return WebDavSyncLocalSnapshot(
    preferences: AppPreferences.defaults,
    aiSettings: AiSettings.defaults,
    reminderSettings: ReminderSettings.defaultsFor(AppLanguage.en),
    imageBedSettings: ImageBedSettings.defaults,
    locationSettings: LocationSettings.defaults,
    templateSettings: MemoTemplateSettings.defaults,
    appLockSnapshot: const AppLockSnapshot(
      settings: AppLockSettings.defaults,
      passwordRecord: null,
    ),
    noteDraft: '',
  );
}

WebDavSettings _validSettings() {
  return WebDavSettings.defaults.copyWith(
    enabled: true,
    serverUrl: 'https://example.com',
    username: 'user',
    password: 'pass',
  );
}

WebDavResponse _jsonResponse(Object json) {
  return WebDavResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    bytes: utf8.encode(jsonEncode(json)),
  );
}

void main() {
  test('returns conflict when local and remote changed', () async {
    final snapshot = _defaultSnapshot();
    final stateRepo = FakeWebDavSyncStateRepository(
      WebDavSyncState(
        lastSyncAt: '2024-01-01T00:00:00Z',
        files: const {
          _preferencesFile: WebDavFileMeta(
            hash: 'last-hash',
            updatedAt: '2024-01-01T00:00:00Z',
            size: 10,
          ),
        },
      ),
    );
    final deviceRepo = FakeWebDavDeviceIdRepository('device-1');
    final localAdapter = FakeWebDavSyncLocalAdapter(snapshot);
    final remoteMeta = WebDavSyncMeta(
      schemaVersion: 1,
      deviceId: 'remote-device',
      updatedAt: '2024-01-02T00:00:00Z',
      files: const {
        _preferencesFile: WebDavFileMeta(
          hash: 'remote-hash',
          updatedAt: '2024-01-02T00:00:00Z',
          size: 12,
        ),
      },
    );
    final fakeClient = _FakeWebDavClient(
      baseUrl: Uri.parse('https://example.com'),
      responsesByName: {_metaFile: _jsonResponse(remoteMeta.toJson())},
    );

    final service = WebDavSyncService(
      syncStateRepository: stateRepo,
      deviceIdRepository: deviceRepo,
      localAdapter: localAdapter,
      vaultService: WebDavVaultService(),
      vaultPasswordRepository: FakeWebDavVaultPasswordRepository(),
      clientFactory: ({
        required Uri baseUrl,
        required WebDavSettings settings,
        void Function(DebugLogEntry entry)? logWriter,
      }) =>
          fakeClient,
    );

    final result = await service.syncNow(
      settings: _validSettings(),
      accountKey: 'account',
    );

    expect(result, isA<WebDavSyncConflict>());
    expect(fakeClient.putCalls, isEmpty);
  });

  test('applies conflict resolutions and writes sync state', () async {
    final snapshot = _defaultSnapshot();
    final localHash = _preferencesHash(snapshot.preferences);
    final stateRepo = FakeWebDavSyncStateRepository(
      WebDavSyncState(
        lastSyncAt: '2024-01-01T00:00:00Z',
        files: const {
          _preferencesFile: WebDavFileMeta(
            hash: 'last-hash',
            updatedAt: '2024-01-01T00:00:00Z',
            size: 10,
          ),
        },
      ),
    );
    final deviceRepo = FakeWebDavDeviceIdRepository('device-1');
    final localAdapter = FakeWebDavSyncLocalAdapter(snapshot);
    final remoteMeta = WebDavSyncMeta(
      schemaVersion: 1,
      deviceId: 'remote-device',
      updatedAt: '2024-01-02T00:00:00Z',
      files: const {
        _preferencesFile: WebDavFileMeta(
          hash: 'remote-hash',
          updatedAt: '2024-01-02T00:00:00Z',
          size: 12,
        ),
      },
    );
    final fakeClient = _FakeWebDavClient(
      baseUrl: Uri.parse('https://example.com'),
      responsesByName: {_metaFile: _jsonResponse(remoteMeta.toJson())},
    );

    final service = WebDavSyncService(
      syncStateRepository: stateRepo,
      deviceIdRepository: deviceRepo,
      localAdapter: localAdapter,
      vaultService: WebDavVaultService(),
      vaultPasswordRepository: FakeWebDavVaultPasswordRepository(),
      clientFactory: ({
        required Uri baseUrl,
        required WebDavSettings settings,
        void Function(DebugLogEntry entry)? logWriter,
      }) =>
          fakeClient,
    );

    final result = await service.syncNow(
      settings: _validSettings(),
      accountKey: 'account',
      conflictResolutions: const {_preferencesFile: true},
    );

    expect(result, isA<WebDavSyncSuccess>());
    expect(fakeClient.putCalls.length, greaterThanOrEqualTo(2));
    expect(
      fakeClient.putCalls.map((c) => c.uri.pathSegments.last),
      contains(_preferencesFile),
    );
    expect(
      fakeClient.putCalls.map((c) => c.uri.pathSegments.last),
      contains(_metaFile),
    );
    expect(stateRepo.lastWritten, isNotNull);
    expect(stateRepo.lastWritten!.files[_preferencesFile]!.hash, localHash);
  });

  test('uploads when remote meta is missing and local unchanged', () async {
    final snapshot = _defaultSnapshot();
    final fileMeta = <String, WebDavFileMeta>{
      _preferencesFile: WebDavFileMeta(
        hash: _preferencesHash(snapshot.preferences),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _aiFile: WebDavFileMeta(
        hash: _jsonHash(snapshot.aiSettings.toJson()),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _reminderFile: WebDavFileMeta(
        hash: _jsonHash(snapshot.reminderSettings.toJson()),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _imageBedFile: WebDavFileMeta(
        hash: _jsonHash(snapshot.imageBedSettings.toJson()),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _locationFile: WebDavFileMeta(
        hash: _jsonHash(snapshot.locationSettings.toJson()),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _templateFile: WebDavFileMeta(
        hash: _jsonHash(snapshot.templateSettings.toJson()),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _appLockFile: WebDavFileMeta(
        hash: _jsonHash(snapshot.appLockSnapshot.toJson()),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
      _draftFile: WebDavFileMeta(
        hash: _jsonHash({'text': snapshot.noteDraft}),
        updatedAt: '2024-01-01T00:00:00Z',
        size: 10,
      ),
    };
    final stateRepo = FakeWebDavSyncStateRepository(
      WebDavSyncState(
        lastSyncAt: '2024-01-01T00:00:00Z',
        files: fileMeta,
      ),
    );
    final deviceRepo = FakeWebDavDeviceIdRepository('device-1');
    final localAdapter = FakeWebDavSyncLocalAdapter(snapshot);
    final fakeClient = _FakeWebDavClient(
      baseUrl: Uri.parse('https://example.com'),
    );

    final service = WebDavSyncService(
      syncStateRepository: stateRepo,
      deviceIdRepository: deviceRepo,
      localAdapter: localAdapter,
      vaultService: WebDavVaultService(),
      vaultPasswordRepository: FakeWebDavVaultPasswordRepository(),
      clientFactory: ({
        required Uri baseUrl,
        required WebDavSettings settings,
        void Function(DebugLogEntry entry)? logWriter,
      }) =>
          fakeClient,
    );

    final result = await service.syncNow(
      settings: _validSettings(),
      accountKey: 'account',
    );

    expect(result, isA<WebDavSyncSuccess>());
    expect(
      fakeClient.putCalls.map((c) => c.uri.pathSegments.last),
      contains(_preferencesFile),
    );
    expect(
      fakeClient.putCalls.map((c) => c.uri.pathSegments.last),
      contains(_metaFile),
    );
  });
}
