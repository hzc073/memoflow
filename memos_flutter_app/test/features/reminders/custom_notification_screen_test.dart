import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/reminders/custom_notification_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('custom notification form uses settings field seams', (
    tester,
  ) async {
    (String, String)? result;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<(String, String)>(
                            MaterialPageRoute<(String, String)>(
                              builder: (_) => const CustomNotificationScreen(
                                initialTitle: 'MemoFlow',
                                initialBody: 'Reminder body',
                              ),
                            ),
                          );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsInlineTextFieldRow), findsOneWidget);
    expect(find.byType(SettingsMultilineFieldRow), findsOneWidget);
    expect(find.byType(SettingsFieldBlock), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Custom title');
    await tester.enterText(find.byType(TextField).at(1), 'Custom body');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, ('Custom title', 'Custom body'));
  });
}
