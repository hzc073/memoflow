import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';

import 'startup_coordinator_test_harness.dart';

void main() {
  group('StartupCoordinator state', () {
    testWidgets('reads startup snapshot from adapter and navigator state', (
      tester,
    ) async {
      final bootstrapAdapter = FakeBootstrapAdapter(
        preferences: AppPreferences.defaults.copyWith(
          launchAction: LaunchAction.dailyReview,
        ),
        preferencesLoaded: false,
        localLibrary: buildTestLocalLibrary(),
      );

      final harness = await pumpStartupCoordinatorHarness(
        tester,
        bootstrapAdapter: bootstrapAdapter,
      );

      expect(harness.coordinator.debugReadStartupSnapshot(), {
        'prefsLoaded': false,
        'hasAccount': false,
        'hasWorkspace': true,
        'navigatorReady': true,
        'contextReady': true,
        'launchAction': LaunchAction.dailyReview.name,
      });
    });

    testWidgets('share preview startup state defers heavy startup work', (
      tester,
    ) async {
      final bootstrapAdapter = FakeBootstrapAdapter(
        preferencesLoaded: false,
      );
      final harness = await pumpStartupCoordinatorHarness(
        tester,
        bootstrapAdapter: bootstrapAdapter,
      );

      final payload = buildPreviewSharePayload();
      await harness.coordinator.handleShareLaunch(payload);

      expect(harness.coordinator.startupSharePreviewPayload, same(payload));
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);
    });

    testWidgets('share state clears after deferred no-account evaluation', (
      tester,
    ) async {
      final bootstrapAdapter = FakeBootstrapAdapter(
        preferencesLoaded: true,
        localLibrary: buildTestLocalLibrary(),
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
      expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 0);
    });

    testWidgets('local library startup does not open explore launch action', (
      tester,
    ) async {
      final bootstrapAdapter = FakeBootstrapAdapter(
        preferences: AppPreferences.defaults.copyWith(
          launchAction: LaunchAction.explore,
        ),
        preferencesLoaded: true,
        localLibrary: buildTestLocalLibrary(),
      );
      final harness = await pumpStartupCoordinatorHarness(
        tester,
        bootstrapAdapter: bootstrapAdapter,
      );

      harness.coordinator.onPrefsLoaded();
      await tester.pump();
      await tester.pump();

      expect(harness.navigatorKey.currentState?.canPop(), isFalse);
      expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
    });
  });
}
