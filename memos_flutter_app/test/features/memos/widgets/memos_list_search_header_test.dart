import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memos_list_header_controller.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_search_header.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_icons.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugPlatformTargetOverride = null;
  });

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

    await tester.tap(find.byIcon(PlatformIcons.filter));
    await tester.pump();
    expect(openAdvancedFiltersCount, 1);
  });

  testWidgets('top search field centers text within the fixed height', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.android;
    final controller = TextEditingController(text: 'Search');
    final focusNode = FocusNode();
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
          hasAdvancedFilters: false,
          onOpenAdvancedFilters: () {},
          onSubmitted: (_) {},
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlignVertical, TextAlignVertical.center);
    expect(field.cursorHeight, 20);
    expect(field.style?.fontSize, 16);
    expect(field.style?.height, 1.25);
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.symmetric(vertical: 8),
    );
    expect(
      field.decoration?.prefixIconConstraints,
      const BoxConstraints(minWidth: 40, minHeight: 36),
    );
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets(
      'top search field aligns Chinese text and cursor on $platform',
      (tester) async {
        debugPlatformTargetOverride = platform;
        final controller = TextEditingController(text: '搜索')
          ..selection = const TextSelection.collapsed(offset: 0);
        final focusNode = FocusNode();
        addTearDown(() {
          controller.dispose();
          focusNode.dispose();
        });

        await tester.pumpWidget(
          _buildHarness(
            locale: AppLocale.zhHans,
            child: MemosListTopSearchField(
              controller: controller,
              focusNode: focusNode,
              isDark: false,
              autofocus: true,
              hasAdvancedFilters: false,
              onOpenAdvancedFilters: () {},
              onSubmitted: (_) {},
            ),
          ),
        );
        await tester.pump();

        final renderEditable = tester.renderObject<RenderEditable>(
          find
              .byElementPredicate(
                (element) => element.renderObject is RenderEditable,
              )
              .first,
        );
        final textBoxes = renderEditable.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
        );
        expect(textBoxes, isNotEmpty);

        final textRect = textBoxes.first.toRect();
        final caretRect = renderEditable.getLocalRectForCaret(
          const TextPosition(offset: 0),
        );
        final centerDelta = (caretRect.center.dy - textRect.center.dy).abs();

        expect(centerDelta, lessThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

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

Widget _buildHarness({required Widget child, AppLocale locale = AppLocale.en}) {
  LocaleSettings.setLocale(locale);
  return TranslationProvider(
    child: MaterialApp(
      locale: locale.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: Center(child: SizedBox(width: 900, child: child)),
      ),
    ),
  );
}
