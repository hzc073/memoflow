import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memos_list_route_delegate.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';

void main() {
  testWidgets('openSettings uses desktop settings window when supported', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(tester);
    final desktopAdapter = _FakeRouteDesktopAdapter(
      openSettingsWindowIfSupportedResult: true,
    );
    var fallbackOpenCount = 0;
    final delegate = harness.buildDelegate(
      desktopAdapter: desktopAdapter,
      openSettingsFallback: (_) async {
        fallbackOpenCount++;
      },
    );

    await delegate.openSettings();

    expect(desktopAdapter.openSettingsWindowIfSupportedCount, 1);
    expect(fallbackOpenCount, 0);
  });

  testWidgets(
    'openSettings falls back when desktop settings window unsupported',
    (tester) async {
      final harness = await _pumpRouteDelegateHarness(tester);
      final desktopAdapter = _FakeRouteDesktopAdapter(
        openSettingsWindowIfSupportedResult: false,
      );
      var fallbackOpenCount = 0;
      final delegate = harness.buildDelegate(
        desktopAdapter: desktopAdapter,
        openSettingsFallback: (_) async {
          fallbackOpenCount++;
        },
      );

      await delegate.openSettings();

      expect(desktopAdapter.openSettingsWindowIfSupportedCount, 1);
      expect(fallbackOpenCount, 1);
    },
  );

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

  testWidgets('openVoiceNoteInput uses quick fab mode and forwards result', (
    tester,
  ) async {
    final harness = await _pumpRouteDelegateHarness(tester);
    final dragSession = VoiceRecordOverlayDragSession();
    VoiceRecordMode? capturedMode;
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
    expect(capturedSession, same(dragSession));
    expect(capturedInitialText, isNull);
    expect(capturedAttachmentPaths, <String>['/tmp/voice.m4a']);
    expect(capturedIgnoreDraft, isTrue);
  });
}

Future<_RouteDelegateHarness> _pumpRouteDelegateHarness(
  WidgetTester tester,
) async {
  late BuildContext capturedContext;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  await tester.pumpWidget(
    MaterialApp(
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
    MemosListRouteNoteInputPresenter? showNoteInputSheet,
    MemosListRouteVoiceRecordOverlayPresenter? showVoiceRecordOverlay,
  }) {
    return MemosListRouteDelegate(
      contextResolver: contextResolver,
      read: _unusedRead,
      scaffoldKey: scaffoldKey,
      buildHomeScreen: ({toastMessage}) => const SizedBox(),
      buildArchivedScreen: () => const SizedBox(),
      invalidateShortcuts: () {},
      submitDesktopQuickInput: (_) async {},
      scrollToTop: () async {},
      focusInlineCompose: () {},
      shouldUseInlineComposeForCurrentWindow: () => false,
      enableCompose: () => true,
      searching: () => false,
      windowsHeaderSearchExpanded: () => false,
      closeSearch: () {},
      closeWindowsHeaderSearch: () {},
      maybeScanLocalLibrary: () async {},
      isAllMemos: () => true,
      showDrawer: () => false,
      dayFilter: () => null,
      selectedShortcutIdResolver: () => null,
      selectShortcutId: (_) {},
      markSceneGuideSeen: (_) {},
      desktopAdapter: desktopAdapter,
      openSettingsFallback: openSettingsFallback,
      showNoteInputSheet: showNoteInputSheet,
      showVoiceRecordOverlay: showVoiceRecordOverlay,
    );
  }
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
    this.openSettingsWindowIfSupportedResult = false,
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

  final bool openSettingsWindowIfSupportedResult;
  bool isWindowVisibleResult;
  bool isWindowMaximizedResult;

  int openSettingsWindowIfSupportedCount = 0;
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
  bool openSettingsWindowIfSupported({required BuildContext feedbackContext}) {
    openSettingsWindowIfSupportedCount++;
    return openSettingsWindowIfSupportedResult;
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
