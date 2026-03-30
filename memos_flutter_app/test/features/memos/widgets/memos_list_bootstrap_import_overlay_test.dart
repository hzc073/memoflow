import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_bootstrap_import_overlay.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inactive overlay renders nothing', (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: MemosListBootstrapImportOverlay(
          active: false,
          importedCount: 0,
          totalCount: 0,
          startedAt: null,
          formatDuration: (_) => 'unused',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'active overlay shows progress, clamps counts and shows elapsed',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: MemosListBootstrapImportOverlay(
            active: true,
            importedCount: 9,
            totalCount: 5,
            startedAt: DateTime.now(),
            formatDuration: (_) => 'elapsed',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('5 / 5'), findsOneWidget);
      expect(find.textContaining('elapsed'), findsOneWidget);
    },
  );
}

Widget _buildHarness({required Widget child}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    ),
  );
}
