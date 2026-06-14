import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/platform/widgets/platform_list_section.dart';
import 'package:memos_flutter_app/platform/widgets/platform_primary_action.dart';

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
            header: const SettingsSectionHeader(title: 'Basics'),
            children: [
              SettingsValueRow(
                label: 'Language',
                value: 'System',
                description: 'Follow system behavior',
                onTap: () {},
              ),
              SettingsToggleRow(
                label: 'Fold content',
                description: 'Hide long text',
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

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CupertinoListTile), findsNothing);
    expect(find.byType(PlatformListSection), findsNothing);
    expect(tester.widget<Divider>(find.byType(Divider)).color, tokens.divider);
    expect(_hasDecoratedBoxColor(tester, tokens.sectionBackground), isTrue);

    final headerStyle = tester.widget<Text>(find.text('Basics')).style!;
    final titleStyle = tester.widget<Text>(find.text('Language')).style!;
    final valueStyle = tester.widget<Text>(find.text('System')).style!;
    final descriptionStyle = tester
        .widget<Text>(find.text('Follow system behavior'))
        .style!;

    expect(headerStyle.fontSize, lessThan(titleStyle.fontSize!));
    expect(titleStyle.fontSize, greaterThan(valueStyle.fontSize!));
    expect(
      valueStyle.fontWeight!.index,
      lessThan(titleStyle.fontWeight!.index),
    );
    expect(descriptionStyle.fontSize, lessThanOrEqualTo(12));
    expect(descriptionStyle.color, isNot(titleStyle.color));
  });

  testWidgets('settings section rows resolve dark mode surface tokens', (
    tester,
  ) async {
    await pumpSettingsSectionForBrightness(tester, Brightness.dark);

    final context = tester.element(find.byType(SettingsSection));
    final tokens = settingsPageTokens(context);

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CupertinoListTile), findsNothing);
    expect(find.byType(PlatformListSection), findsNothing);
    expect(tester.widget<Divider>(find.byType(Divider)).color, tokens.divider);
    expect(_hasDecoratedBoxColor(tester, tokens.sectionBackground), isTrue);

    final headerStyle = tester.widget<Text>(find.text('Basics')).style!;
    final titleStyle = tester.widget<Text>(find.text('Language')).style!;
    final valueStyle = tester.widget<Text>(find.text('System')).style!;
    final descriptionStyle = tester
        .widget<Text>(find.text('Follow system behavior'))
        .style!;

    expect(headerStyle.fontSize, lessThan(titleStyle.fontSize!));
    expect(titleStyle.fontSize, greaterThan(valueStyle.fontSize!));
    expect(
      valueStyle.fontWeight!.index,
      lessThan(titleStyle.fontWeight!.index),
    );
    expect(descriptionStyle.fontSize, lessThanOrEqualTo(12));
    expect(descriptionStyle.color, isNot(titleStyle.color));
  });

  testWidgets('settings rows keep mobile touch height on iPhone and Android', (
    tester,
  ) async {
    Future<double> rowHeightFor(TargetPlatform platform) async {
      setTargetPlatform(platform);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSection(
              children: [SettingsNavigationRow(label: 'Account', onTap: () {})],
            ),
          ),
        ),
      );
      await tester.pump();
      return tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Account'),
                  matching: find.byType(ConstrainedBox),
                )
                .first,
          )
          .height;
    }

    final iPhoneHeight = await rowHeightFor(TargetPlatform.iOS);
    final androidHeight = await rowHeightFor(TargetPlatform.android);

    expect(iPhoneHeight, greaterThanOrEqualTo(52));
    expect(androidHeight, greaterThanOrEqualTo(52));
  });

  testWidgets('settings value rows pin selected values to the trailing edge', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 560,
              child: SettingsSection(
                children: [
                  SettingsValueRow(
                    label: 'Language',
                    value: 'System',
                    icon: Icons.expand_more,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final sectionRect = tester.getRect(find.byType(SettingsSection));
    final valueRect = tester.getRect(find.text('System'));
    final iconRect = tester.getRect(find.byIcon(Icons.expand_more));

    expect(valueRect.right, greaterThan(sectionRect.right - 72));
    expect(iconRect.right, greaterThan(sectionRect.right - 32));
    expect(valueRect.right, lessThan(iconRect.left));
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
    expect(home.shortcutTileHeight, 80);
    expect(home.sectionSpacing, 12);
    expect(home.navigationRowMinHeight, 48);
    expect(home.profilePadding, const EdgeInsets.all(16));

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

    final guideRowSize = tester.getSize(
      find
          .ancestor(
            of: find.text('Guide'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    final preferencesRowSize = tester.getSize(
      find
          .ancestor(
            of: find.text('Preferences'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(guideRowSize.height, greaterThanOrEqualTo(48));
    expect(preferencesRowSize.height, greaterThanOrEqualTo(48));

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
    expect(home.shortcutTileHeight, 80);
    expect(home.sectionSpacing, 12);
    expect(home.navigationRowMinHeight, 48);
    expect(home.profilePadding, const EdgeInsets.all(16));
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

    expect(find.text('One'), findsOneWidget);

    await tester.tap(find.byType(SettingsMenuRow<String>), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsSingleChoiceList<String>), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();

    expect(selectedValue, 'two');
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(stepValue, 4);
    expect(find.text('4x'), findsOneWidget);
    expect(tester.widget<Text>(find.text('4x')).style?.fontSize, 13);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(actionCount, 1);
  });

  testWidgets('settings form field seams keep padded Apple mobile inputs', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);
    final usernameController = TextEditingController(text: 'alice');
    final portController = TextEditingController(text: '443');
    final urlController = TextEditingController(text: 'https://example.com');
    final notesController = TextEditingController(text: 'notes');
    addTearDown(usernameController.dispose);
    addTearDown(portController.dispose);
    addTearDown(urlController.dispose);
    addTearDown(notesController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          title: const Text('Settings'),
          showBackButton: false,
          children: [
            SettingsSection(
              children: [
                SettingsInlineTextFieldRow(
                  label: 'Username',
                  controller: usernameController,
                ),
                SettingsNumericInlineFieldRow(
                  label: 'Port',
                  controller: portController,
                ),
                SettingsFormFieldRow(
                  label: 'Server URL',
                  controller: urlController,
                  hint: 'https://example.com',
                  errorText: 'Server URL is invalid',
                  suffixIcon: const Icon(Icons.visibility_outlined),
                ),
                SettingsMultilineFieldRow(
                  label: 'Notes',
                  controller: notesController,
                  helperText: 'Optional notes',
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsFieldBlock), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text('Server URL is invalid'), findsOneWidget);
    expect(find.text('Optional notes'), findsOneWidget);
    final fields = tester
        .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
        .toList();
    expect(fields, hasLength(4));
    expect(fields[3].minLines, 3);
    expect(fields[3].maxLines, 5);
    expect(find.byType(CupertinoListTile), findsNothing);
    for (final field in fields) {
      final padding = field.padding.resolve(TextDirection.ltr);
      expect(padding.horizontal, greaterThan(0));
      expect(padding.vertical, greaterThan(0));
    }

    await tester.enterText(find.byType(CupertinoTextField).first, 'bob');
    await tester.pump();

    expect(usernameController.text, 'bob');
  });

  testWidgets('inline text field falls back when label cannot fit', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'alice');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: SettingsSection(
                children: [
                  SettingsInlineTextFieldRow(
                    label: 'Very long username label',
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SettingsFormFieldRow), findsOneWidget);
    expect(find.byType(SettingsFieldBlock), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('settings long value row constrains trailing text', (
    tester,
  ) async {
    const longValue = 'https://example.com/a/very/long/path/that/must/truncate';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SettingsSection(
              children: [
                SettingsLongValueRow(
                  label: 'Root path',
                  value: longValue,
                  trailingIcon: Icons.chevron_right,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final valueSize = tester.getSize(find.text(longValue));
    expect(valueSize.width, lessThanOrEqualTo(320 * 0.42));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled settings menu row does not open picker', (
    tester,
  ) async {
    var selectedValue = 'one';
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSection(
            children: [
              SettingsMenuRow<String>(
                label: 'Mode',
                value: selectedValue,
                values: const ['one', 'two'],
                labelFor: (value) => value == 'one' ? 'One' : 'Two',
                enabled: false,
                onChanged: (value) {
                  selectedValue = value;
                  changeCount += 1;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SettingsMenuRow<String>), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(selectedValue, 'one');
    expect(changeCount, 0);
    expect(find.text('Two'), findsNothing);
  });

  testWidgets('settings menu row renders and selects on iOS', (tester) async {
    setTargetPlatform(TargetPlatform.iOS);

    var selectedValue = 'one';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SettingsPage(
              title: const Text('Settings'),
              children: [
                SettingsSection(
                  children: [
                    SettingsMenuRow<String>(
                      label: 'Mode',
                      value: selectedValue,
                      values: const ['one', 'two'],
                      labelFor: (value) => value == 'one' ? 'One' : 'Two',
                      onChanged: (value) =>
                          setState(() => selectedValue = value),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('One'), findsOneWidget);

    await tester.tap(find.byType(SettingsMenuRow<String>));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();

    expect(selectedValue, 'two');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings option choice row renders and selects on iOS', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    var selectedValue = 'one';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SettingsPage(
              title: const Text('Settings'),
              showBackButton: false,
              children: [
                SettingsSection(
                  children: [
                    SettingsOptionChoiceRow<String>(
                      label: 'Density',
                      description: 'Choose how much content each row shows.',
                      value: selectedValue,
                      options: const [
                        SettingsChoiceOption(value: 'one', label: 'Compact'),
                        SettingsChoiceOption(
                          value: 'two',
                          label: 'Comfortable',
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedValue = value),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Compact'), findsOneWidget);

    await tester.tap(find.text('Comfortable'));
    await tester.pumpAndSettle();

    expect(selectedValue, 'two');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings single and multi choice lists work on iOS', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    var singleValue = 'system';
    var multiValues = <String>{'local'};

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SettingsPage(
              title: const Text('Settings'),
              showBackButton: false,
              children: [
                SettingsSection(
                  children: [
                    SettingsSingleChoiceList<String>(
                      value: singleValue,
                      options: const [
                        SettingsChoiceOption(
                          value: 'system',
                          label: 'System',
                          description: 'Follow system behavior.',
                        ),
                        SettingsChoiceOption(
                          value: 'manual',
                          label: 'Manual',
                          description: 'Keep the chosen value.',
                        ),
                      ],
                      onChanged: (value) => setState(() => singleValue = value),
                    ),
                    SettingsMultiChoiceList<String>(
                      values: multiValues,
                      options: const [
                        SettingsChoiceOption(value: 'local', label: 'Local'),
                        SettingsChoiceOption(value: 'cloud', label: 'Cloud'),
                      ],
                      onChanged: (values) =>
                          setState(() => multiValues = values),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Radio<String>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();

    expect(singleValue, 'manual');

    await tester.tap(find.text('Cloud'));
    await tester.pumpAndSettle();

    expect(multiValues, contains('cloud'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings action dialog feedback and progress work on iOS', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    var actionCount = 0;
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return SettingsPage(
              title: const Text('Settings'),
              showBackButton: false,
              children: [
                SettingsSection(
                  children: [
                    const SettingsFeedbackRow(
                      kind: SettingsFeedbackKind.success,
                      title: 'Saved',
                      message: 'Settings were updated.',
                    ),
                    const SettingsProgressRow(
                      label: 'Syncing',
                      description: 'Updating local settings.',
                      value: 0.4,
                    ),
                    SettingsNavigationRow(
                      label: 'Open confirmation',
                      onTap: () async {
                        confirmed = await showSettingsConfirmationDialog(
                          context: context,
                          title: 'Reset settings',
                          message: 'This cannot be undone.',
                          confirmLabel: 'Proceed',
                          destructive: true,
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SettingsAction(
                    label: const Text('Delete'),
                    variant: PlatformPrimaryActionVariant.destructive,
                    onPressed: () => actionCount += 1,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(CupertinoButton, 'Delete'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(actionCount, 1);

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);

    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings form dialog text uses compact undecorated body style', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsFormDialog(
          title: Text('Dialog title'),
          children: [Text('Plain body text')],
        ),
      ),
    );

    final bodyStyle = DefaultTextStyle.of(
      tester.element(find.text('Plain body text')),
    ).style;
    expect(bodyStyle.fontSize, 14);
    expect(bodyStyle.decoration, TextDecoration.none);
  });
}

bool _hasDecoratedBoxColor(WidgetTester tester, Color color) {
  return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}
