import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/settings/import_export_screen.dart';

import 'settings_test_harness.dart';

void main() {
  testWidgets('shows export entry and navigates to export screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const ImportExportScreen(showBackButton: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import / Export'), findsOneWidget);
    expect(find.text('Export'), findsNWidgets(2));
    expect(find.text('Markdown + ZIP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Export'), findsNWidgets(2));
    expect(find.text('Date Range'), findsOneWidget);
    expect(find.text('Export Format'), findsOneWidget);
  });

  testWidgets(
    'shows local network migration entry and navigates to target hub',
    (tester) async {
      await tester.pumpWidget(
        buildSettingsTestApp(
          home: const ImportExportScreen(showBackButton: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import / Export'), findsOneWidget);
      expect(find.text('Local Network Migration'), findsNWidgets(2));
      expect(find.text('MemoFlow / Obsidian'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.devices_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Local Network Migration'), findsOneWidget);
      expect(find.text('MemoFlow Migration'), findsOneWidget);
      expect(find.text('Connect Obsidian'), findsOneWidget);
    },
  );
}
