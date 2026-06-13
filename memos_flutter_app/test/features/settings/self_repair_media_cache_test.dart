import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/maintenance/media_cache_maintenance_models.dart';
import 'package:memos_flutter_app/application/maintenance/media_cache_maintenance_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/core/top_toast.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/features/settings/self_repair_screen.dart';
import 'package:memos_flutter_app/features/settings/storage_space_screen.dart';
import 'package:memos_flutter_app/state/maintenance/media_cache_maintenance_provider.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';

import 'settings_test_harness.dart';

void main() {
  tearDown(() {
    dismissTopToast();
  });

  testWidgets('self repair no longer shows media cache cleanup UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const SelfRepairScreen(),
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) => _TestDevicePreferencesController(ref),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repair abnormal tags'), findsOneWidget);
    expect(find.text('Rebuild search index'), findsOneWidget);
    expect(find.text('Rebuild statistics cache'), findsOneWidget);
    expect(find.text('Clear media cache'), findsNothing);
    expect(find.text('Media cache total'), findsNothing);
    expect(find.text('Network image cache'), findsNothing);
    expect(find.text('Video thumbnail cache'), findsNothing);
  });

  testWidgets('storage space shows MemoFlow known usage and categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const StorageSpaceScreen(),
        overrides: [
          databaseProvider.overrideWithValue(_FakeStorageSummaryDatabase()),
          mediaCacheMaintenanceServiceProvider.overrideWithValue(
            MediaCacheMaintenanceService(
              targets: [
                _FakeMediaCacheTarget(
                  categoryId: MediaCacheCategoryId.networkImage,
                  sizeBytes: 1024,
                ),
                _FakeMediaCacheTarget(
                  categoryId: MediaCacheCategoryId.videoThumbnail,
                  sizeBytes: 2 * 1024 * 1024,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storage Space'), findsOneWidget);
    expect(find.text('MemoFlow known usage'), findsOneWidget);
    expect(
      find.text(
        'Device capacity is unavailable. MemoFlow known usage and categories are still shown.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cache'), findsOneWidget);
    expect(find.text('Note content'), findsOneWidget);
    expect(find.text('Note images'), findsOneWidget);
    expect(find.text('Note videos'), findsOneWidget);
    expect(find.text('Note audio'), findsOneWidget);
    expect(find.text('Note files'), findsOneWidget);
    expect(find.text('2.0 MB'), findsWidgets);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets(
    'confirming storage cache cleanup calls service and refreshes size',
    (tester) async {
      final target = _FakeMediaCacheTarget(
        categoryId: MediaCacheCategoryId.networkImage,
        sizeBytes: 1024,
        sizeAfterClearBytes: 0,
      );

      await tester.pumpWidget(
        buildSettingsTestApp(
          home: const StorageSpaceScreen(),
          overrides: [
            databaseProvider.overrideWithValue(_FakeStorageSummaryDatabase()),
            mediaCacheMaintenanceServiceProvider.overrideWithValue(
              MediaCacheMaintenanceService(targets: [target]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear media cache?'), findsOneWidget);
      expect(find.textContaining('LocalLibrary source files'), findsOneWidget);
      expect(
        find.textContaining('pending sync queues, and remote server data'),
        findsOneWidget,
      );

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(target.clearCalls, 1);
      expect(find.text('Media cache cleared'), findsOneWidget);
      expect(find.text('0 B'), findsWidgets);
      dismissTopToast();
      await tester.pump();
    },
  );

  testWidgets('canceling storage cache cleanup does not call service', (
    tester,
  ) async {
    final target = _FakeMediaCacheTarget(
      categoryId: MediaCacheCategoryId.networkImage,
      sizeBytes: 1024,
    );

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const StorageSpaceScreen(),
        overrides: [
          databaseProvider.overrideWithValue(_FakeStorageSummaryDatabase()),
          mediaCacheMaintenanceServiceProvider.overrideWithValue(
            MediaCacheMaintenanceService(targets: [target]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(target.clearCalls, 0);
    expect(find.text('Clear media cache?'), findsNothing);
  });

  testWidgets('partial storage cache cleanup shows partial result', (
    tester,
  ) async {
    final successTarget = _FakeMediaCacheTarget(
      categoryId: MediaCacheCategoryId.networkImage,
      sizeBytes: 1024,
      sizeAfterClearBytes: 0,
    );
    final failingTarget = _FakeMediaCacheTarget(
      categoryId: MediaCacheCategoryId.videoThumbnail,
      sizeBytes: 2048,
      clearError: StateError('clear failed'),
    );

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const StorageSpaceScreen(),
        overrides: [
          databaseProvider.overrideWithValue(_FakeStorageSummaryDatabase()),
          mediaCacheMaintenanceServiceProvider.overrideWithValue(
            MediaCacheMaintenanceService(
              targets: [successTarget, failingTarget],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(successTarget.clearCalls, 1);
    expect(failingTarget.clearCalls, 1);
    expect(
      find.text('Media cache cleanup partially completed'),
      findsOneWidget,
    );
    dismissTopToast();
    await tester.pump();
  });
}

class _FakeStorageSummaryDatabase extends AppDatabase {
  _FakeStorageSummaryDatabase() : super(dbName: 'fake.db');

  @override
  Future<List<Map<String, dynamic>>> listMemoStorageSummaryRows({
    String? state,
  }) async {
    return const [];
  }
}

class _FakeMediaCacheTarget implements MediaCacheMaintenanceTarget {
  _FakeMediaCacheTarget({
    required this.categoryId,
    required int sizeBytes,
    int? sizeAfterClearBytes,
    Object? clearError,
  }) : _sizeBytes = sizeBytes,
       _sizeAfterClearBytes = sizeAfterClearBytes,
       _clearError = clearError;

  @override
  final MediaCacheCategoryId categoryId;
  final int? _sizeAfterClearBytes;
  final Object? _clearError;
  int _sizeBytes;
  int clearCalls = 0;

  @override
  Future<int?> estimateSizeBytes() async => _sizeBytes;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    final error = _clearError;
    if (error != null) throw error;
    final after = _sizeAfterClearBytes;
    if (after != null) {
      _sizeBytes = after;
    }
  }
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository()
    : _prefs = DevicePreferences.defaultsForLanguage(AppLanguage.en),
      super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _prefs;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<DevicePreferences> read() async {
    return _prefs;
  }

  @override
  Future<void> write(DevicePreferences prefs) async {
    _prefs = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(Ref ref)
    : super(ref, _TestDevicePreferencesRepository());
}
