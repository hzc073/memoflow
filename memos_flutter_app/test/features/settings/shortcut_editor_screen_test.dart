import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/shortcut.dart';
import 'package:memos_flutter_app/features/settings/shortcut_editor_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    debugPlatformTargetOverride = null;
  });

  tearDown(() {
    debugPlatformTargetOverride = null;
  });

  testWidgets('desktop openShortcutEditor uses task surface chrome', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => openShortcutEditor(context),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('platform-secondary-task-surface-dialog'),
      ),
      findsOneWidget,
    );
    expect(find.byType(ShortcutEditorScreen), findsOneWidget);
    expect(find.byType(SettingsSection), findsWidgets);
    expect(find.byType(SettingsInputRow), findsWidgets);
    expect(find.byType(SettingsAction), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
  });

  testWidgets('mobile openShortcutEditor keeps route and returns result', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.android;
    ShortcutEditorResult? result;

    await tester.pumpWidget(
      _buildTestApp(
        tagStats: const <TagStat>[TagStat(tag: 'work', count: 1)],
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await openShortcutEditor(
                    context,
                    shortcut: const Shortcut(
                      name: 'shortcuts/work',
                      id: 'work',
                      title: 'Work',
                      filter: 'tag in ["work"]',
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(ShortcutEditorScreen), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsWidgets);
    expect(find.byType(SettingsInputRow), findsWidgets);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.byType(ShortcutEditorScreen), findsNothing);
    expect(result, isNotNull);
    expect(result?.title, 'Work');
    expect(result?.filter, 'tag in ["work"]');
  });

  testWidgets('tag picker uses settings multi choice seams on iOS', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      _buildTestApp(
        tagStats: const <TagStat>[
          TagStat(tag: 'work', count: 1),
          TagStat(tag: 'personal', count: 2),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  openShortcutEditor(
                    context,
                    shortcut: const Shortcut(
                      name: 'shortcuts/work',
                      id: 'work',
                      title: 'Work',
                      filter: 'tag in ["work"]',
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsRemovableChip), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    await tester.tap(find.text('Select tags'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(SettingsMultiChoiceList<String>), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.text('#personal'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SettingsDialogAction, 'Done'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('#personal'), findsOneWidget);
  });
}

Widget _buildTestApp({
  required Widget child,
  List<TagStat> tagStats = const <TagStat>[],
}) {
  return ProviderScope(
    overrides: [
      tagStatsProvider.overrideWith((ref) => Stream.value(tagStats)),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(tagStats)),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    ),
  );
}
