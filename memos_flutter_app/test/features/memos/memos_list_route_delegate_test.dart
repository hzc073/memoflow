import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/desktop/desktop_settings_window.dart';
import 'package:memos_flutter_app/core/platform_layout.dart';
import 'package:memos_flutter_app/features/memos/memos_list_desktop_presentation.dart';
import 'package:memos_flutter_app/features/memos/memos_list_route_delegate.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';

void main() {
  testWidgets('openSettings uses desktop settings window when supported', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(tester);
    final desktopAdapter = _FakeRouteDesktopAdapter(
      openSettingsWindowResult: const DesktopSettingsWindowOpenResult.opened(),
    );
    var fallbackOpenCount = 0;
    final delegate = harness.buildDelegate(
      desktopAdapter: desktopAdapter,
      openSettingsFallback: (_) async {
        fallbackOpenCount++;
      },
    );

    await delegate.openSettings();

    expect(desktopAdapter.openSettingsWindowCount, 1);
    expect(fallbackOpenCount, 0);
  });

  testWidgets(
    'openSettings falls back when desktop settings window unsupported',
    (tester) async {
      final harness = await _pumpRouteDelegateHarness(tester);
      final desktopAdapter = _FakeRouteDesktopAdapter(
        openSettingsWindowResult:
            const DesktopSettingsWindowOpenResult.unsupported(),
      );
      var fallbackOpenCount = 0;
      final delegate = harness.buildDelegate(
        desktopAdapter: desktopAdapter,
        openSettingsFallback: (_) async {
          fallbackOpenCount++;
        },
      );

      await delegate.openSettings();

      expect(desktopAdapter.openSettingsWindowCount, 1);
      expect(fallbackOpenCount, 1);
    },
  );

  testWidgets('openSettings falls back when desktop settings window fails', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(tester);
    final desktopAdapter = _FakeRouteDesktopAdapter(
      openSettingsWindowResult: DesktopSettingsWindowOpenResult.failed(
        StateError('settings window failed'),
      ),
    );
    var fallbackOpenCount = 0;
    final delegate = harness.buildDelegate(
      desktopAdapter: desktopAdapter,
      openSettingsFallback: (_) async {
        fallbackOpenCount++;
      },
    );

    await delegate.openSettings();

    expect(desktopAdapter.openSettingsWindowCount, 1);
    expect(fallbackOpenCount, 1);
  });

  testWidgets('openSettings falls back on macOS', (tester) async {
    final previousPlatformOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    try {
      final harness = await _pumpRouteDelegateHarness(
        tester,
        platform: TargetPlatform.macOS,
      );
      final desktopAdapter = _FakeRouteDesktopAdapter(
        openSettingsWindowResult: DesktopSettingsWindowOpenResult.failed(
          StateError('macOS settings window unavailable in test'),
        ),
      );
      var fallbackOpenCount = 0;
      final delegate = harness.buildDelegate(
        desktopAdapter: desktopAdapter,
        openSettingsFallback: (_) async {
          fallbackOpenCount++;
        },
      );

      await delegate.openSettings();

      expect(desktopAdapter.openSettingsWindowCount, 1);
      expect(fallbackOpenCount, 1);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatformOverride;
    }
  });

  testWidgets('toggleMemoFlowVisibility uses tray branch when supported', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(tester);
    final desktopAdapter = _FakeRouteDesktopAdapter(
      desktopShortcutsEnabled: true,
      traySupported: true,
      isWindowVisibleResult: true,
    );
    final delegate = harness.buildDelegate(desktopAdapter: desktopAdapter);

    await delegate.toggleMemoFlowVisibilityFromShortcut();

    expect(desktopAdapter.hideToTrayCount, 1);
    expect(desktopAdapter.showFromTrayCount, 0);
    expect(desktopAdapter.hideWindowCount, 0);
  });

  testWidgets(
    'toggleMemoFlowVisibility uses window branch when tray unsupported',
    (tester) async {
      final harness = await _pumpRouteDelegateHarness(tester);
      final desktopAdapter = _FakeRouteDesktopAdapter(
        desktopShortcutsEnabled: true,
        traySupported: false,
        supportsTaskbarVisibilityToggle: true,
        isWindowVisibleResult: false,
      );
      final delegate = harness.buildDelegate(desktopAdapter: desktopAdapter);

      await delegate.toggleMemoFlowVisibilityFromShortcut();

      expect(desktopAdapter.setSkipTaskbarValues, <bool>[false]);
      expect(desktopAdapter.showWindowCount, 1);
      expect(desktopAdapter.focusWindowCount, 1);
    },
  );

  testWidgets('syncDesktopWindowState updates maximized flag through adapter', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(tester);
    final desktopAdapter = _FakeRouteDesktopAdapter(
      supportsWindowControls: true,
      isWindowMaximizedResult: true,
    );
    final delegate = harness.buildDelegate(desktopAdapter: desktopAdapter);
    var notifyCount = 0;
    delegate.addListener(() {
      notifyCount++;
    });

    await delegate.syncDesktopWindowState();
    await delegate.syncDesktopWindowState();

    expect(delegate.desktopWindowMaximized, isTrue);
    expect(notifyCount, 1);
  });

  testWidgets('openNoteInput uses desktop presenter from desktop policy', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(
      tester,
      platform: TargetPlatform.windows,
    );
    var sheetOpenCount = 0;
    var desktopOpenCount = 0;
    final delegate = harness.buildDelegate(
      showNoteInputSheet:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            sheetOpenCount++;
          },
      showDesktopComposeSurface:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            desktopOpenCount++;
          },
    );

    await delegate.openNoteInput();

    expect(desktopOpenCount, 1);
    expect(sheetOpenCount, 0);
  });

  testWidgets('openNoteInput follows desktop compose policy, not platform', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(
      tester,
      platform: TargetPlatform.macOS,
    );
    var sheetOpenCount = 0;
    var desktopOpenCount = 0;
    final delegate = harness.buildDelegate(
      desktopPresentationResolver: (_) => _desktopPresentation(
        composePresentation: MemosListDesktopComposePresentation.desktopSurface,
        platform: TargetPlatform.macOS,
      ),
      showNoteInputSheet:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            sheetOpenCount++;
          },
      showDesktopComposeSurface:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            desktopOpenCount++;
          },
    );

    await delegate.openNoteInput();

    expect(desktopOpenCount, 1);
    expect(sheetOpenCount, 0);
  });

  testWidgets('openVoiceNoteInput uses desktop presenter on Windows platform', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(
      tester,
      platform: TargetPlatform.windows,
    );
    String? capturedInitialText;
    List<String> capturedAttachmentPaths = const <String>[];
    bool? capturedIgnoreDraft;
    var sheetOpenCount = 0;
    final delegate = harness.buildDelegate(
      showVoiceRecordOverlay:
          (
            context, {
            bool autoStart = true,
            VoiceRecordOverlayDragSession? dragSession,
            VoiceRecordMode mode = VoiceRecordMode.standard,
          }) async {
            return Future<VoiceRecordResult?>.value(
              const VoiceRecordResult(
                filePath: '/tmp/voice.m4a',
                fileName: 'voice.m4a',
                size: 12,
                duration: Duration(seconds: 3),
                suggestedContent: 'Voice memo',
              ),
            );
          },
      showNoteInputSheet:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            sheetOpenCount++;
          },
      showDesktopComposeSurface:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            capturedInitialText = initialText;
            capturedAttachmentPaths = initialAttachmentPaths;
            capturedIgnoreDraft = ignoreDraft;
          },
    );

    await delegate.openVoiceNoteInput();

    expect(capturedInitialText, isNull);
    expect(capturedAttachmentPaths, <String>['/tmp/voice.m4a']);
    expect(capturedIgnoreDraft, isTrue);
    expect(sheetOpenCount, 0);
  });

  testWidgets('openVoiceNoteInput uses quick fab mode and forwards result', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(
      tester,
      platform: TargetPlatform.android,
    );
    final dragSession = VoiceRecordOverlayDragSession();
    VoiceRecordMode? capturedMode;
    bool? capturedAutoStart;
    VoiceRecordOverlayDragSession? capturedSession;
    String? capturedInitialText;
    List<String> capturedAttachmentPaths = const <String>[];
    bool? capturedIgnoreDraft;
    final delegate = harness.buildDelegate(
      showVoiceRecordOverlay:
          (
            context, {
            bool autoStart = true,
            VoiceRecordOverlayDragSession? dragSession,
            VoiceRecordMode mode = VoiceRecordMode.standard,
          }) async {
            capturedAutoStart = autoStart;
            capturedMode = mode;
            capturedSession = dragSession;
            return Future<VoiceRecordResult?>.value(
              const VoiceRecordResult(
                filePath: '/tmp/voice.m4a',
                fileName: 'voice.m4a',
                size: 12,
                duration: Duration(seconds: 3),
                suggestedContent: 'Voice memo',
              ),
            );
          },
      showNoteInputSheet:
          (
            context, {
            String? initialText,
            List<String> initialAttachmentPaths = const <String>[],
            bool ignoreDraft = false,
          }) async {
            capturedInitialText = initialText;
            capturedAttachmentPaths = initialAttachmentPaths;
            capturedIgnoreDraft = ignoreDraft;
          },
    );

    await delegate.openVoiceNoteInput(origin: dragSession);

    expect(capturedMode, VoiceRecordMode.quickFabCompose);
    expect(capturedAutoStart, isTrue);
    expect(capturedSession, same(dragSession));
    expect(capturedInitialText, isNull);
    expect(capturedAttachmentPaths, <String>['/tmp/voice.m4a']);
    expect(capturedIgnoreDraft, isTrue);
  });
}

Future<_RouteDelegateHarness> _pumpRouteDelegateHarness(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  late BuildContext capturedContext;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        key: scaffoldKey,
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return _RouteDelegateHarness(
    contextResolver: () => capturedContext,
    scaffoldKey: scaffoldKey,
  );
}

class _RouteDelegateHarness {
  const _RouteDelegateHarness({
    required this.contextResolver,
    required this.scaffoldKey,
  });

  final BuildContext Function() contextResolver;
  final GlobalKey<ScaffoldState> scaffoldKey;

  MemosListRouteDelegate buildDelegate({
    MemosListRouteDesktopAdapter? desktopAdapter,
    MemosListRouteSettingsFallbackOpener? openSettingsFallback,
    MemosListRouteDesktopPresentationResolver? desktopPresentationResolver,
    MemosListRouteNoteInputPresenter? showNoteInputSheet,
    MemosListRouteNoteInputPresenter? showDesktopComposeSurface,
    MemosListRouteVoiceRecordOverlayPresenter? showVoiceRecordOverlay,
  }) {
    return MemosListRouteDelegate(
      contextResolver: contextResolver,
      read: _unusedRead,
      scaffoldKey: scaffoldKey,
      buildHomeScreen: ({toastMessage}) => const SizedBox(),
      invalidateShortcuts: () {},
      submitDesktopQuickInput: (_) async {},
      scrollToTop: () async {},
      focusInlineCompose: () {},
      shouldUseInlineComposeForCurrentWindow: () => false,
      enableCompose: () => true,
      searching: () => false,
      desktopHeaderSearchExpanded: () => false,
      closeSearch: () {},
      closeDesktopHeaderSearch: () {},
      maybeScanLocalLibrary: () async {},
      isAllMemos: () => true,
      showDrawer: () => false,
      dayFilter: () => null,
      selectedShortcutIdResolver: () => null,
      selectShortcutId: (_) {},
      markSceneGuideSeen: (_) {},
      desktopAdapter: desktopAdapter,
      openSettingsFallback: openSettingsFallback,
      desktopPresentationResolver: desktopPresentationResolver,
      showNoteInputSheet: showNoteInputSheet,
      showDesktopComposeSurface: showDesktopComposeSurface,
      showVoiceRecordOverlay: showVoiceRecordOverlay,
    );
  }
}

MemosListDesktopPresentation _desktopPresentation({
  required MemosListDesktopComposePresentation composePresentation,
  TargetPlatform platform = TargetPlatform.windows,
}) {
  return MemosListDesktopPresentation(
    platform: platform,
    layoutTier: DesktopLayoutTier.wide,
    navigationMode: DesktopNavigationMode.expanded,
    supportsSidePane: true,
    titlebarStrategy: platform == TargetPlatform.windows
        ? MemosListDesktopTitlebarStrategy.windowsCommandBar
        : MemosListDesktopTitlebarStrategy.macosToolbar,
    previewPanePolicy: const MemosListDesktopPreviewPanePolicy(
      activation: MemosListDesktopPreviewPaneActivation.automatic,
      supportsPane: true,
    ),
    searchPresentation: platform == TargetPlatform.windows
        ? MemosListDesktopSearchPresentation.header
        : MemosListDesktopSearchPresentation.standard,
    composePresentation: composePresentation,
    inlineComposeCapability: const MemosListInlineComposeCapability(
      supported: true,
      supportsResize: true,
    ),
  );
}

T _unusedRead<T>(ProviderListenable<T> provider) {
  throw UnimplementedError('read should not be used in this test');
}

class _FakeRouteDesktopAdapter implements MemosListRouteDesktopAdapter {
  _FakeRouteDesktopAdapter({
    this.desktopShortcutsEnabled = false,
    this.traySupported = false,
    this.supportsWindowControls = false,
    this.supportsTaskbarVisibilityToggle = false,
    this.openSettingsWindowResult =
        const DesktopSettingsWindowOpenResult.unsupported(),
    this.isWindowVisibleResult = false,
    this.isWindowMaximizedResult = false,
  });

  @override
  final bool desktopShortcutsEnabled;

  @override
  final bool traySupported;

  @override
  final bool supportsWindowControls;

  @override
  final bool supportsTaskbarVisibilityToggle;

  final DesktopSettingsWindowOpenResult openSettingsWindowResult;
  bool isWindowVisibleResult;
  bool isWindowMaximizedResult;

  int openSettingsWindowCount = 0;
  int hideToTrayCount = 0;
  int showFromTrayCount = 0;
  final List<bool> setSkipTaskbarValues = <bool>[];
  int hideWindowCount = 0;
  int showWindowCount = 0;
  int focusWindowCount = 0;
  int minimizeWindowCount = 0;
  int maximizeWindowCount = 0;
  int unmaximizeWindowCount = 0;
  int requestCloseWindowCount = 0;

  @override
  Future<DesktopSettingsWindowOpenResult> openSettingsWindow({
    required BuildContext feedbackContext,
  }) async {
    openSettingsWindowCount++;
    return openSettingsWindowResult;
  }

  @override
  Future<bool> isWindowVisible() async => isWindowVisibleResult;

  @override
  Future<void> hideToTray() async {
    hideToTrayCount++;
  }

  @override
  Future<void> showFromTray() async {
    showFromTrayCount++;
  }

  @override
  Future<void> setSkipTaskbar(bool skip) async {
    setSkipTaskbarValues.add(skip);
  }

  @override
  Future<void> hideWindow() async {
    hideWindowCount++;
  }

  @override
  Future<void> showWindow() async {
    showWindowCount++;
  }

  @override
  Future<void> focusWindow() async {
    focusWindowCount++;
  }

  @override
  Future<bool> isWindowMaximized() async => isWindowMaximizedResult;

  @override
  Future<void> minimizeWindow() async {
    minimizeWindowCount++;
  }

  @override
  Future<void> maximizeWindow() async {
    maximizeWindowCount++;
    isWindowMaximizedResult = true;
  }

  @override
  Future<void> unmaximizeWindow() async {
    unmaximizeWindowCount++;
    isWindowMaximizedResult = false;
  }

  @override
  Future<void> requestCloseWindow() async {
    requestCloseWindowCount++;
  }
}
