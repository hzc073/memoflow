import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/share_quick_clip_models.dart';

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

    testWidgets('quick clip link-only success shows local-save toast', (
      tester,
    ) async {
      ShareQuickClipSubmission? submitted;
      String? toastMessage;
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
        shareQuickClipStartOverride:
            ({required payload, required submission, required locale}) async {
              submitted = submission;
            },
        topToastPresenterOverride: (_, message) {
          toastMessage = message;
          return true;
        },
      );

      await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clip now'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.titleAndLinkOnly, isTrue);
      expect(toastMessage, 'Saved locally. Sync will continue when available.');
      expect(find.text('Clip now'), findsNothing);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
      expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
    });

    testWidgets('direct text share opens composer with local-save toast enabled', (
      tester,
    ) async {
      ShareComposeRequest? presented;
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
        appNavigatorBuilder: TestMemosAppNavigator.new,
        shareComposeRequestPresenterOverride: (context, request) {
          presented = request;
        },
      );

      await harness.coordinator.handleShareLaunch(
        const SharePayload(
          type: SharePayloadType.text,
          text: 'Shared thoughts without a URL',
          title: 'Shared thoughts',
        ),
      );
      await tester.pumpAndSettle();

      expect(presented, isNotNull);
      expect(presented!.text, 'Shared thoughts without a URL');
      expect(presented!.showLocalSaveSuccessToast, isTrue);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
    });

    testWidgets('image share opens composer with local-save toast enabled', (
      tester,
    ) async {
      ShareComposeRequest? presented;
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
        appNavigatorBuilder: TestMemosAppNavigator.new,
        shareComposeRequestPresenterOverride: (context, request) {
          presented = request;
        },
      );

      await harness.coordinator.handleShareLaunch(
        const SharePayload(
          type: SharePayloadType.images,
          paths: <String>['C:/tmp/shared-image.png'],
        ),
      );
      await tester.pumpAndSettle();

      expect(presented, isNotNull);
      expect(presented!.attachmentPaths, <String>['C:/tmp/shared-image.png']);
      expect(presented!.showLocalSaveSuccessToast, isTrue);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
    });
  });
}
