import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/platform/widgets/platform_list_section.dart';

void main() {
  void setTargetPlatform(TargetPlatform platform) {
    debugPlatformTargetOverride = platform;
    addTearDown(() {
      debugPlatformTargetOverride = null;
    });
  }

  Future<void> pumpSettingsSectionForBrightness(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    setTargetPlatform(TargetPlatform.windows);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Scaffold(
          body: SettingsSection(
            children: [
              SettingsValueRow(
                label: 'Language',
                value: 'System',
                onTap: () {},
              ),
              SettingsToggleRow(
                label: 'Fold content',
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('settings section rows resolve light mode surface tokens', (
    tester,
  ) async {
    await pumpSettingsSectionForBrightness(tester, Brightness.light);

    final context = tester.element(find.byType(SettingsSection));
    final tokens = settingsPageTokens(context);
    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect(rows, hasLength(2));
    expect(rows.every((row) => row.tileColor == tokens.rowBackground), isTrue);
    expect(rows.every((row) => row.hoverColor == tokens.rowHover), isTrue);
    expect(rows.every((row) => row.splashColor == tokens.rowPressed), isTrue);
    expect(tester.widget<Divider>(find.byType(Divider)).color, tokens.divider);
    expect(_hasDecoratedBoxColor(tester, tokens.sectionBackground), isTrue);

    final section = tester.widget<PlatformListSection>(
      find.byType(PlatformListSection),
    );
    expect(section.style?.borderRadius, isNull);
    expect(section.style?.boxShadow, isNull);
  });

  testWidgets('settings section rows resolve dark mode surface tokens', (
    tester,
  ) async {
    await pumpSettingsSectionForBrightness(tester, Brightness.dark);

    final context = tester.element(find.byType(SettingsSection));
    final tokens = settingsPageTokens(context);
    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect(rows, hasLength(2));
    expect(rows.every((row) => row.tileColor == tokens.rowBackground), isTrue);
    expect(rows.every((row) => row.hoverColor == tokens.rowHover), isTrue);
    expect(rows.every((row) => row.splashColor == tokens.rowPressed), isTrue);
    expect(tester.widget<Divider>(find.byType(Divider)).color, tokens.divider);
    expect(_hasDecoratedBoxColor(tester, tokens.sectionBackground), isTrue);

    final section = tester.widget<PlatformListSection>(
      find.byType(PlatformListSection),
    );
    expect(section.style?.borderRadius, isNull);
    expect(section.style?.boxShadow, isNull);
  });

  Future<void> pumpSettingsHomeHierarchyForBrightness(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    setTargetPlatform(TargetPlatform.android);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Scaffold(
          body: ListView(
            children: [
              SettingsHomeProfileEntry(
                avatar: const CircleAvatar(child: Icon(Icons.person)),
                name: 'MemoFlow',
                subtitle: 'Capture every moment',
                onTap: () {},
              ),
              Row(
                children: [
                  Expanded(
                    child: SettingsHomeShortcutTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'Stats',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SettingsHomeShortcutTile(
                      icon: Icons.widgets_outlined,
                      label: 'Widgets',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              SettingsHomeSection(
                children: [
                  SettingsNavigationRow(label: 'Guide', onTap: () {}),
                  SettingsNavigationRow(label: 'Preferences', onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('settings home hierarchy resolves light mode tokens', (
    tester,
  ) async {
    await pumpSettingsHomeHierarchyForBrightness(tester, Brightness.light);

    final context = tester.element(find.byType(SettingsHomeSection));
    final tokens = settingsPageTokens(context);
    final home = tokens.homeHierarchy;

    expect(home.usesLayeredCards, isTrue);
    expect(home.cardElevation, greaterThan(0));

    final profileMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SettingsHomeProfileEntry),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(profileMaterial.color, home.cardBackground);
    expect(profileMaterial.elevation, home.cardElevation);
    expect(profileMaterial.shadowColor, home.shadowColor);
    expect(
      (profileMaterial.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(home.profileRadius),
    );

    final shortcutSize = tester.getSize(
      find.byType(SettingsHomeShortcutTile).first,
    );
    expect(shortcutSize.height, home.shortcutTileHeight);

    final section = tester.widget<PlatformListSection>(
      find.descendant(
        of: find.byType(SettingsHomeSection),
        matching: find.byType(PlatformListSection),
      ),
    );
    expect(section.style?.sectionColor, home.cardBackground);
    expect(section.style?.borderColor, home.border);
    expect(section.style?.dividerColor, home.divider);
    expect(
      section.style?.borderRadius,
      BorderRadius.circular(home.sectionRadius),
    );
    expect(section.style?.boxShadow, home.sectionShadow);
  });

  testWidgets('settings home hierarchy resolves dark mode equivalent tokens', (
    tester,
  ) async {
    await pumpSettingsHomeHierarchyForBrightness(tester, Brightness.dark);

    final context = tester.element(find.byType(SettingsHomeSection));
    final tokens = settingsPageTokens(context);
    final home = tokens.homeHierarchy;

    expect(home.usesLayeredCards, isTrue);
    expect(home.cardElevation, 0);
    expect(home.sectionShadow, isEmpty);

    final section = tester.widget<PlatformListSection>(
      find.descendant(
        of: find.byType(SettingsHomeSection),
        matching: find.byType(PlatformListSection),
      ),
    );
    expect(section.style?.sectionColor, home.cardBackground);
    expect(section.style?.borderColor, home.border);
    expect(section.style?.dividerColor, home.divider);
    expect(
      section.style?.borderRadius,
      BorderRadius.circular(home.sectionRadius),
    );
  });

  testWidgets('settings page applies row surface to direct nested list tiles', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.windows);

    late SettingsPageTokens tokens;
    late ListTileThemeData rowTheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Builder(
          builder: (context) {
            tokens = settingsPageTokens(context);
            return SettingsPage(
              title: const Text('Settings'),
              children: [
                Builder(
                  builder: (context) {
                    rowTheme = ListTileTheme.of(context);
                    return const ListTile(
                      title: Text('Direct row'),
                      trailing: Icon(Icons.chevron_right),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(rowTheme.tileColor, tokens.rowBackground);
    expect(rowTheme.selectedTileColor, tokens.rowSelected);
  });

  testWidgets('settings semantic form seams dispatch basic interactions', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'initial');
    addTearDown(controller.dispose);

    var textValue = '';
    var selectedValue = 'one';
    var stepValue = 3;
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                children: [
                  SettingsSection(
                    children: [
                      SettingsInputRow(
                        label: 'Endpoint',
                        hint: 'https://example.com',
                        controller: controller,
                        onChanged: (value) => textValue = value,
                      ),
                      SettingsMenuRow<String>(
                        label: 'Mode',
                        value: selectedValue,
                        values: const ['one', 'two'],
                        labelFor: (value) => value == 'one' ? 'One' : 'Two',
                        onChanged: (value) =>
                            setState(() => selectedValue = value),
                      ),
                      SettingsStepperRow(
                        label: 'Retries',
                        value: stepValue,
                        unit: 'x',
                        onDecrease: () => setState(() => stepValue -= 1),
                        onIncrease: () => setState(() => stepValue += 1),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SettingsAction(
                      label: const Text('Save'),
                      onPressed: () => actionCount += 1,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'updated');
    await tester.pump();

    expect(textValue, 'updated');

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byWidgetPredicate((widget) => widget is DropdownButton<String>),
    );
    dropdown.onChanged?.call('two');
    await tester.pump();

    expect(selectedValue, 'two');
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(stepValue, 4);
    expect(find.text('4x'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(actionCount, 1);
  });
}

bool _hasDecoratedBoxColor(WidgetTester tester, Color color) {
  return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}
