import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/advanced_search_sheet.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  testWidgets('shows initial values', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: AdvancedSearchFilters(
            createdDateRange: DateTimeRange(
              start: DateTime(2025, 1, 1),
              end: DateTime(2025, 1, 31),
            ),
            hasLocation: SearchToggleFilter.yes,
            locationContains: 'shanghai',
            hasAttachments: SearchToggleFilter.yes,
            attachmentNameContains: 'invoice',
            attachmentType: AdvancedAttachmentType.document,
            hasRelations: SearchToggleFilter.yes,
          ),
          showCreatedDateFilter: true,
          onApply: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2025-01-01 - 2025-01-31'), findsOneWidget);
    expect(find.text('shanghai'), findsOneWidget);
    expect(find.text('invoice'), findsOneWidget);
    expect(find.text('Linked memos'), findsOneWidget);
  });

  testWidgets('apply returns normalized filters', (tester) async {
    AdvancedSearchFilters? applied;

    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: AdvancedSearchFilters.empty,
          showCreatedDateFilter: true,
          onApply: (value) => applied = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('advanced-search-location-contains')),
      'pudong',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-type-document')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advanced-search-type-document')),
    );
    await tester.tap(find.byKey(const ValueKey('advanced-search-apply')));
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.hasLocation, SearchToggleFilter.yes);
    expect(applied!.locationContains, 'pudong');
    expect(applied!.hasAttachments, SearchToggleFilter.yes);
    expect(applied!.attachmentType, AdvancedAttachmentType.document);
  });

  testWidgets('clear resets all filters', (tester) async {
    AdvancedSearchFilters? applied;

    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: const AdvancedSearchFilters(
            hasLocation: SearchToggleFilter.yes,
            locationContains: 'shanghai',
            hasRelations: SearchToggleFilter.yes,
          ),
          showCreatedDateFilter: true,
          onApply: (value) => applied = value,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('advanced-search-clear-all')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('advanced-search-apply')));
    await tester.pump();

    expect(applied, AdvancedSearchFilters.empty);
  });

  testWidgets('setting attachments no clears detail fields', (tester) async {
    AdvancedSearchFilters? applied;

    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: AdvancedSearchFilters.empty,
          showCreatedDateFilter: true,
          onApply: (value) => applied = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('advanced-search-attachment-name')),
      'invoice',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-type-document')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advanced-search-type-document')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-attachments-no')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advanced-search-attachments-no')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('advanced-search-apply')));
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.hasAttachments, SearchToggleFilter.no);
    expect(applied!.attachmentNameContains, isEmpty);
    expect(applied!.attachmentType, isNull);
  });

  testWidgets('setting attachments any clears attachment type', (tester) async {
    AdvancedSearchFilters? applied;

    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: AdvancedSearchFilters.empty,
          showCreatedDateFilter: true,
          onApply: (value) => applied = value,
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-type-image')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advanced-search-type-image')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-attachments-any')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advanced-search-attachments-any')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('advanced-search-apply')));
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.hasAttachments, SearchToggleFilter.any);
    expect(applied!.attachmentType, isNull);
  });

  testWidgets('setting location no clears location text', (tester) async {
    AdvancedSearchFilters? applied;

    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: AdvancedSearchFilters.empty,
          showCreatedDateFilter: true,
          onApply: (value) => applied = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('advanced-search-location-contains')),
      'shanghai',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-location-no')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advanced-search-location-no')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('advanced-search-apply')));
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.hasLocation, SearchToggleFilter.no);
    expect(applied!.locationContains, isEmpty);
  });

  testWidgets('setting location any keeps location text filter', (
    tester,
  ) async {
    AdvancedSearchFilters? applied;

    await tester.pumpWidget(
      _buildTestApp(
        child: AdvancedSearchSheet(
          initial: AdvancedSearchFilters.empty,
          showCreatedDateFilter: true,
          onApply: (value) => applied = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('advanced-search-location-contains')),
      'shanghai',
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('advanced-search-location-any')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advanced-search-location-any')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('advanced-search-apply')));
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.hasLocation, SearchToggleFilter.any);
    expect(applied!.locationContains, 'shanghai');
  });
}

Widget _buildTestApp({required Widget child}) {
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
