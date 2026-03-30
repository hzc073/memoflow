import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memos_list_header_controller.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_search_header.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('top search field opens advanced filters', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var openAdvancedFiltersCount = 0;
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      _buildHarness(
        child: MemosListTopSearchField(
          controller: controller,
          focusNode: focusNode,
          isDark: false,
          autofocus: false,
          hasAdvancedFilters: true,
          onOpenAdvancedFilters: () => openAdvancedFiltersCount++,
          onSubmitted: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pump();
    expect(openAdvancedFiltersCount, 1);
  });

  testWidgets('active advanced filter sliver forwards clear actions', (
    tester,
  ) async {
    var clearAllCount = 0;
    final removedKinds = <MemosListAdvancedSearchChipKind>[];

    await tester.pumpWidget(
      _buildHarness(
        child: CustomScrollView(
          slivers: [
            MemosListActiveAdvancedFilterSliver(
              chips: const <MemosListAdvancedSearchChipData>[
                MemosListAdvancedSearchChipData(
                  label: 'Location: Paris',
                  kind: MemosListAdvancedSearchChipKind.locationContains,
                ),
              ],
              onClearAll: () => clearAllCount++,
              onRemoveSingle: removedKinds.add,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Location: Paris'), findsOneWidget);

    await tester.tap(find.text('Location: Paris'));
    await tester.pump();
    expect(removedKinds, <MemosListAdvancedSearchChipKind>[
      MemosListAdvancedSearchChipKind.locationContains,
    ]);

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(clearAllCount, 1);
  });
}

Widget _buildHarness({required Widget child}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: Center(child: SizedBox(width: 900, child: child)),
      ),
    ),
  );
}
