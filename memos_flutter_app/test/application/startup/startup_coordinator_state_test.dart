import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/resolved_app_settings.dart';

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
      final bootstrapAdapter = FakeBootstrapAdapter(preferencesLoaded: false);
      final harness = await pumpStartupCoordinatorHarness(
        tester,
        bootstrapAdapter: bootstrapAdapter,
      );

      final payload = buildPreviewSharePayload();
      await harness.coordinator.handleShareLaunch(payload);

      expect(harness.coordinator.startupSharePreviewPayload, same(payload));
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);
    });

    testWidgets('share state clears after deferred local-library evaluation', (
      tester,
    ) async {
      final bootstrapAdapter = FakeBootstrapAdapter(
        preferences: AppPreferences.defaults.copyWith(
          thirdPartyShareEnabled: false,
        ),
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
      expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
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

    testWidgets(
      'session-triggered startup recovers from a transient state read failure',
      (tester) async {
        final bootstrapAdapter = _ThrowingResolvedSettingsBootstrapAdapter(
          preferencesLoaded: true,
          localLibrary: buildTestLocalLibrary(),
        );
        final harness = await pumpStartupCoordinatorHarness(
          tester,
          bootstrapAdapter: bootstrapAdapter,
        );

        harness.coordinator.onSessionChanged();
        await tester.pump();
        await tester.pump();

        expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
      },
    );
  });
}

class _ThrowingResolvedSettingsBootstrapAdapter extends FakeBootstrapAdapter {
  _ThrowingResolvedSettingsBootstrapAdapter({
    super.preferencesLoaded,
    super.localLibrary,
  });

  bool _shouldThrow = true;

  @override
  ResolvedAppSettings readResolvedAppSettings(WidgetRef ref) {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw StateError('transient state read failure');
    }
    return super.readResolvedAppSettings(ref);
  }
}
