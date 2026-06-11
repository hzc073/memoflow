import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/desktop/desktop_share_window.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/features/share/clipboard_share_detector.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/share_quick_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_task_window_codec.dart';

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

    testWidgets(
      'preview flow opens desktop share task window when opener accepts',
      (tester) async {
        final opened = <Map<String, Object?>>[];
        final releasedSources = <String>[];
        var foregroundCalls = 0;
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
          desktopShareTaskRequestIdFactory: () => 'share-request-1',
          desktopShareTaskWindowOpenerOverride:
              ({required requestId, required payloadJson}) async {
                opened.add(<String, Object?>{
                  'requestId': requestId,
                  'payloadJson': payloadJson,
                });
                return const DesktopShareTaskWindowOpenResult.opened(
                  windowId: 42,
                );
              },
          desktopMainWindowForegrounderOverride: () async {
            foregroundCalls += 1;
          },
          shareComposeRequestPresenterOverride: (context, request) {
            presented = request;
          },
          onShareFlowReleased: releasedSources.add,
        );

        await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
        await tester.pump();
        await tester.pump();

        expect(opened, hasLength(1));
        expect(opened.single['requestId'], 'share-request-1');
        final payloadJson =
            opened.single['payloadJson']! as Map<String, dynamic>;
        expect(payloadJson['type'], SharePayloadType.text.name);
        expect(find.text('Clip now'), findsNothing);
        expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);

        final accepted = await harness.coordinator.handleDesktopShareTaskResult(
          DesktopShareTaskResult(
            requestId: 'share-request-1',
            request: const ShareComposeRequest(
              text: '[Interesting Article](https://example.com/articles/1)',
              selectionOffset: 54,
            ),
          ).toJson(),
          42,
        );

        expect(accepted, isTrue);
        expect(foregroundCalls, 1);
        expect(presented, isNotNull);
        expect(presented!.showLocalSaveSuccessToast, isTrue);
        expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
        expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
        expect(releasedSources, <String>['share_task_result']);
      },
    );

    testWidgets('desktop share task request ids keep active windows separate', (
      tester,
    ) async {
      final openedRequestIds = <String>[];
      final releasedSources = <String>[];
      final requestIds = <String>['first-share', 'second-share'];
      final presentedTexts = <String>[];
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
        desktopShareTaskRequestIdFactory: () => requestIds.removeAt(0),
        desktopShareTaskWindowOpenerOverride:
            ({required requestId, required payloadJson}) async {
              openedRequestIds.add(requestId);
              return DesktopShareTaskWindowOpenResult.opened(
                windowId: openedRequestIds.length,
              );
            },
        desktopMainWindowForegrounderOverride: () async {},
        shareComposeRequestPresenterOverride: (context, request) {
          presentedTexts.add(request.text);
        },
        onShareFlowReleased: releasedSources.add,
      );

      await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
      await tester.pumpAndSettle();
      await harness.coordinator.handleShareLaunch(
        const SharePayload(
          type: SharePayloadType.text,
          text: 'Second https://example.com/articles/2',
          title: 'Second Article',
        ),
      );
      await tester.pumpAndSettle();

      expect(openedRequestIds, <String>['first-share', 'second-share']);

      final secondAccepted = await harness.coordinator
          .handleDesktopShareTaskResult(
            DesktopShareTaskResult(
              requestId: 'second-share',
              request: const ShareComposeRequest(
                text: 'second-result',
                selectionOffset: 13,
              ),
            ).toJson(),
            2,
          );

      expect(secondAccepted, isTrue);
      expect(presentedTexts, <String>['second-result']);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);
      expect(releasedSources, isEmpty);

      final firstCanceled = await harness.coordinator
          .handleDesktopShareTaskCanceled(
            desktopShareTaskCanceledToJson('first-share'),
            1,
          );

      expect(firstCanceled, isTrue);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
      expect(harness.syncOrchestrator.maybeSyncOnLaunchCount, 1);
      expect(releasedSources, <String>['share_task_canceled']);
    });

    testWidgets('unknown desktop share task ids do not release active flow', (
      tester,
    ) async {
      final releasedSources = <String>[];
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
        desktopShareTaskRequestIdFactory: () => 'known-share',
        desktopShareTaskWindowOpenerOverride:
            ({required requestId, required payloadJson}) async {
              return const DesktopShareTaskWindowOpenResult.opened(windowId: 7);
            },
        onShareFlowReleased: releasedSources.add,
      );

      await harness.coordinator.handleShareLaunch(buildPreviewSharePayload());
      await tester.pumpAndSettle();

      final unknownCanceled = await harness.coordinator
          .handleDesktopShareTaskCanceled(
            desktopShareTaskCanceledToJson('unknown-share'),
            9,
          );
      final unknownResult = await harness.coordinator
          .handleDesktopShareTaskResult(
            DesktopShareTaskResult(
              requestId: 'unknown-share',
              request: const ShareComposeRequest(
                text: 'ignored',
                selectionOffset: 7,
              ),
            ).toJson(),
            9,
          );

      expect(unknownCanceled, isFalse);
      expect(unknownResult, isFalse);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);
      expect(releasedSources, isEmpty);
    });

    testWidgets(
      'share-flow release lets a changed clipboard URL become promptable without resume',
      (tester) async {
        final tracker = ClipboardSharePromptTracker();
        final promptableClipboardUrls = <String>[];
        final releasedSources = <String>[];
        const firstPayload = SharePayload(
          type: SharePayloadType.text,
          text: 'URL A https://example.com/articles/1',
          title: 'URL A',
        );
        const nextClipboardPayload = SharePayload(
          type: SharePayloadType.text,
          text: 'URL B https://example.com/articles/2',
          title: 'URL B',
        );
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
          desktopShareTaskRequestIdFactory: () => 'retry-share',
          desktopShareTaskWindowOpenerOverride:
              ({required requestId, required payloadJson}) async {
                return const DesktopShareTaskWindowOpenResult.opened(
                  windowId: 11,
                );
              },
          desktopMainWindowForegrounderOverride: () async {},
          onShareFlowReleased: (source) {
            releasedSources.add(source);
            if (tracker.wasPrompted(nextClipboardPayload)) return;
            final url = tracker.markPrompted(nextClipboardPayload);
            if (url != null) {
              promptableClipboardUrls.add(url);
            }
          },
        );

        expect(
          tracker.markPrompted(firstPayload),
          'https://example.com/articles/1',
        );
        await harness.coordinator.handleShareLaunch(firstPayload);
        await tester.pumpAndSettle();

        expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);
        expect(tracker.wasPrompted(nextClipboardPayload), isFalse);
        expect(promptableClipboardUrls, isEmpty);

        final accepted = await harness.coordinator.handleDesktopShareTaskResult(
          DesktopShareTaskResult(
            requestId: 'retry-share',
            request: const ShareComposeRequest(
              text: 'first-result',
              selectionOffset: 12,
            ),
          ).toJson(),
          11,
        );

        expect(accepted, isTrue);
        expect(releasedSources, <String>['share_task_result']);
        expect(promptableClipboardUrls, <String>[
          'https://example.com/articles/2',
        ]);
      },
    );

    testWidgets('preview sheet can be dismissed without clipping', (
      tester,
    ) async {
      final releasedSources = <String>[];
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
        onShareFlowReleased: releasedSources.add,
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
      expect(releasedSources, <String>['share_flow_completed']);
    });

    testWidgets('quick clip link-only success shows local-save toast', (
      tester,
    ) async {
      ShareQuickClipSubmission? submitted;
      String? toastMessage;
      final releasedSources = <String>[];
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
        onShareFlowReleased: releasedSources.add,
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
      expect(releasedSources, <String>['share_flow_completed']);
    });

    testWidgets(
      'direct text share opens composer with local-save toast enabled',
      (tester) async {
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
      },
    );

    testWidgets(
      'quick record URL share opens composer without quick clip formatting',
      (tester) async {
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
            handlingMode: SharePayloadHandlingMode.quickRecord,
            text: 'Read https://example.com/article',
            title: 'Read',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clip now'), findsNothing);
        expect(presented, isNotNull);
        expect(presented!.text, 'Read https://example.com/article');
        expect(presented!.selectionOffset, presented!.text.length);
        expect(presented!.showLocalSaveSuccessToast, isTrue);
        expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
      },
    );

    testWidgets('standard URL share still opens quick clip sheet', (
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
        shareComposeRequestPresenterOverride: (context, request) {
          presented = request;
        },
      );

      await harness.coordinator.handleShareLaunch(
        const SharePayload(
          type: SharePayloadType.text,
          text: 'Read https://example.com/article',
          title: 'Read',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clip now'), findsOneWidget);
      expect(presented, isNull);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isTrue);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
    });

    testWidgets('quick record respects disabled third-party share preference', (
      tester,
    ) async {
      ShareComposeRequest? presented;
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
        shareComposeRequestPresenterOverride: (context, request) {
          presented = request;
        },
      );

      await harness.coordinator.handleShareLaunch(
        const SharePayload(
          type: SharePayloadType.text,
          handlingMode: SharePayloadHandlingMode.quickRecord,
          text: 'Read https://example.com/article',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(presented, isNull);
      expect(find.text('Clip now'), findsNothing);
      expect(harness.coordinator.startupSharePreviewPayload, isNull);
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

    testWidgets('quick record media opens composer with attachment paths', (
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
          handlingMode: SharePayloadHandlingMode.quickRecord,
          paths: <String>['/tmp/shared-image.png', '/tmp/shared-video.mp4'],
        ),
      );
      await tester.pumpAndSettle();

      expect(presented, isNotNull);
      expect(presented!.text, isEmpty);
      expect(presented!.attachmentPaths, <String>[
        '/tmp/shared-image.png',
        '/tmp/shared-video.mp4',
      ]);
      expect(presented!.showLocalSaveSuccessToast, isTrue);
      expect(harness.coordinator.shouldDeferHeavyStartupWork, isFalse);
    });
  });
}
