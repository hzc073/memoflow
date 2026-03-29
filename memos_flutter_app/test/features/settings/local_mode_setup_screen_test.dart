import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/settings/local_mode_setup_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  testWidgets('default mode shows storage info card', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);

    await tester.pumpWidget(
      TranslationProvider(
        child: const MaterialApp(
          home: LocalModeSetupScreen(
            title: 'Add local library',
            confirmLabel: 'Confirm',
            cancelLabel: 'Cancel',
            initialName: 'Local Library',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        "Local mode data is stored in the app's private files by default.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('rename mode hides storage info card and returns trimmed name', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);

    LocalModeSetupResult? result;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await LocalModeSetupScreen.show(
                      context,
                      title: 'Local library name',
                      confirmLabel: 'Confirm',
                      cancelLabel: 'Cancel',
                      initialName: 'Old Name',
                      subtitle: 'C:/MemoFlow/local_workspace',
                      showStorageInfoCard: false,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Local mode data is stored in the app's private files by default.",
      ),
      findsNothing,
    );
    expect(find.text('C:/MemoFlow/local_workspace'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Renamed Library  ');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Renamed Library');
  });
}
