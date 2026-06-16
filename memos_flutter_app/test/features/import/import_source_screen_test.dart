import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/features/import/import_flow_screens.dart';
import 'package:memos_flutter_app/features/import/import_source_kind.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/memos/flomo_import_models.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';

import '../settings/settings_test_harness.dart';

void main() {
  testWidgets('shows four import sources without subtitle copy', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    var flomoTapped = false;
    var swashbucklerTapped = false;
    var memoFlowTapped = false;
    var genericTapped = false;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: ImportSourceScreen(
          onSelectFlomo: () {
            flomoTapped = true;
          },
          onSelectSwashbucklerDiary: () {
            swashbucklerTapped = true;
          },
          onSelectMemoFlowMarkdown: () {
            memoFlowTapped = true;
          },
          onSelectGenericMarkdown: () {
            genericTapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flomo export package'), findsOneWidget);
    expect(find.text('Swashbuckler Diary export package'), findsOneWidget);
    expect(find.text('MemoFlow Markdown package'), findsOneWidget);
    expect(find.text('Generic Markdown package'), findsOneWidget);
    expect(find.text('HTML / ZIP'), findsNothing);
    expect(find.text('JSON / Markdown / TXT ZIP'), findsNothing);
    expect(find.text('Upload a .zip package with .md files'), findsNothing);
    expect(find.byTooltip('Format help'), findsNWidgets(4));

    await tester.tap(find.text('Flomo export package'));
    await tester.pump();
    await tester.tap(find.text('Swashbuckler Diary export package'));
    await tester.pump();
    await tester.tap(find.text('MemoFlow Markdown package'));
    await tester.pump();
    await tester.tap(find.text('Generic Markdown package'));
    await tester.pump();

    expect(flomoTapped, isTrue);
    expect(swashbucklerTapped, isTrue);
    expect(memoFlowTapped, isTrue);
    expect(genericTapped, isTrue);
  });

  testWidgets('shows source-specific format help dialog', (tester) async {
    LocaleSettings.setLocale(AppLocale.en);

    await tester.pumpWidget(
      buildSettingsTestApp(home: const ImportSourceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Format help').at(3));
    await tester.pumpAndSettle();

    expect(find.text('Generic Markdown package'), findsWidgets);
    expect(
      find.textContaining('Each Markdown file becomes one memo'),
      findsOneWidget,
    );
    expect(find.textContaining('README.md'), findsWidgets);
    expect(find.textContaining('markdown.zip'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('markdown.zip'), findsNothing);
  });

  testWidgets('shows source-specific failure dialog with valid structure', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final dbName =
        'generic_markdown_failure_dialog_'
        '${DateTime.now().microsecondsSinceEpoch}.db';
    final db = AppDatabase(dbName: dbName);

    addTearDown(() async {
      await db.close();
    });
    await tester.pumpWidget(
      buildSettingsTestApp(
        overrides: [
          devicePreferencesRepositoryProvider.overrideWithValue(
            _TestDevicePreferencesRepository(),
          ),
          isLocalLibraryModeProvider.overrideWithValue(true),
          databaseProvider.overrideWithValue(db),
        ],
        home: ImportRunScreen(
          filePath: 'generic.zip',
          fileName: 'generic.zip',
          sourceKind: ImportSourceKind.genericMarkdown,
          importOverride:
              ({
                required ImportProgressCallback onProgress,
                required ImportCancelCheck isCancelled,
              }) async {
                throw const ImportException(
                  'No importable Markdown files found in ZIP.',
                );
              },
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Import failed').evaluate().isNotEmpty) break;
    }

    expect(find.text('Import failed'), findsOneWidget);
    expect(
      find.text('No importable Markdown files found in ZIP.'),
      findsOneWidget,
    );
    expect(find.textContaining('markdown.zip'), findsOneWidget);
    expect(find.textContaining('README.md'), findsOneWidget);
    expect(find.textContaining('export.html'), findsNothing);
    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository()
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(
      DevicePreferences.defaultsForLanguage(AppLanguage.en),
    );
  }

  @override
  Future<DevicePreferences> read() async {
    return DevicePreferences.defaultsForLanguage(AppLanguage.en);
  }

  @override
  Future<void> write(DevicePreferences prefs) async {}
}
