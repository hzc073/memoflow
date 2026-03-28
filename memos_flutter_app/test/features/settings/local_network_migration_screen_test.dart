import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/settings/local_network_migration_screen.dart';

import 'settings_test_harness.dart';

void main() {
  testWidgets('shows MemoFlow migration and Obsidian targets', (tester) async {
    await tester.pumpWidget(
      buildSettingsTestApp(home: const LocalNetworkMigrationScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Network Migration'), findsOneWidget);
    expect(find.text('MemoFlow Migration'), findsOneWidget);
    expect(find.text('Connect Obsidian'), findsOneWidget);
    expect(
      find.textContaining('MemoFlow migration and Obsidian'),
      findsOneWidget,
    );
  });

  testWidgets('navigates from migration hub to MemoFlow role screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(home: const LocalNetworkMigrationScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('MemoFlow Migration'));
    await tester.pumpAndSettle();

    expect(find.text("I'm the Sender"), findsOneWidget);
    expect(find.text("I'm the Receiver"), findsOneWidget);
  });

  testWidgets('navigates from migration hub to Obsidian bridge screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(home: const LocalNetworkMigrationScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Obsidian'));
    await tester.pumpAndSettle();

    expect(find.text('Connect Obsidian'), findsOneWidget);
    expect(find.text('MemoFlow Bridge'), findsNothing);
    expect(
      find.text(
        'Pair with Obsidian over your local network. Other targets may come later.',
      ),
      findsOneWidget,
    );
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
