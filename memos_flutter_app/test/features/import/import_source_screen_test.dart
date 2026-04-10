import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/import/import_flow_screens.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

import '../settings/settings_test_harness.dart';

void main() {
  testWidgets('shows SwashbucklerDiary import source and triggers callback', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    var tapped = false;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: ImportSourceScreen(
          onSelectSwashbucklerDiary: () {
            tapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import from Swashbuckler Diary'), findsOneWidget);
    expect(find.text('JSON / Markdown / TXT ZIP'), findsOneWidget);

    await tester.tap(find.text('Import from Swashbuckler Diary'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
