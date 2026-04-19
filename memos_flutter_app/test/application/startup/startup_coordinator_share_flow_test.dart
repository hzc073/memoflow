import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';

import 'startup_coordinator_test_harness.dart';

void main() {
  group('StartupCoordinator share flow', () {
    testWidgets(
      'clears startup share state when third-party share is disabled',
      (tester) async {
        final bootstrapAdapter = FakeBootstrapAdapter(
          preferences: AppPreferences.defaults.copyWith(
            thirdPartyShareEnabled: false,
          ),
          preferencesLoaded: true,
          session: buildTestSessionWithAccount(),
        );
        final harness = await pumpStartupCoordinatorHarness(
          tester,
          bootstrapAdapter: bootstrapAdapter,
        );

        await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
        await tester.pump();
        await tester.pump();

        expect(harness.coordinator.startupSharePreviewPayload, isNull);
        expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
        expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
      },
    );

    testWidgets(
      'preview flow opens clip sheet directly with link-only enabled',
      (tester) async {
        final bootstrapAdapter = FakeBootstrapAdapter(
          preferences: AppPreferences.defaults.copyWith(
            thirdPartyShareEnabled: true,
          ),
          preferencesLoaded: true,
          session: buildTestSessionWithAccount(),
        );
        final harness = await pumpStartupCoordinatorHarness(
          tester,
          bootstrapAdapter: bootstrapAdapter,
        );

        await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
        await tester.pumpAndSettle();
        expect(find.text('Clip now'), findsOneWidget);
        expect(find.text('Clipboard link detected'), findsNothing);

        final linkOnlyTile = tester.widget<SwitchListTile>(
          find.ancestor(
            of: find.text('Save title and link only'),
            matching: find.byType(SwitchListTile),
          ),
        );
        final textOnlyTile = tester.widget<SwitchListTile>(
          find.ancestor(
            of: find.text('Save text only'),
            matching: find.byType(SwitchListTile),
          ),
        );
        expect(linkOnlyTile.value, isTrue);
        expect(textOnlyTile.value, isFalse);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(harness.coordinator.startupSharePreviewPayload, isNull);
        expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
        expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
        expect(
          harness.syncOrchestrator.lastLaunchPrefs,
          bootstrapAdapter.workspacePreferences,
        );
      },
    );

    testWidgets('preview sheet can be dismissed without clipping', (
      tester,
    ) async {
      final bootstrapAdapter = FakeBootstrapAdapter(
        preferences: AppPreferences.defaults.copyWith(
          thirdPartyShareEnabled: true,
        ),
        preferencesLoaded: true,
        session: buildTestSessionWithAccount(),
      );
      final harness = await pumpStartupCoordinatorHarness(
        tester,
        bootstrapAdapter: bootstrapAdapter,
      );

      await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
      await tester.pumpAndSettle();
      expect(find.text('Clip now'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Clip now'), findsNothing);
      expect(harness.coordinator.startupSharePreviewPayload, isNull);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
      expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
    });
  });
}
