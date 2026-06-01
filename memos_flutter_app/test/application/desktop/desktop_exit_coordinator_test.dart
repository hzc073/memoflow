import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/desktop/desktop_exit_coordinator.dart';
import 'package:memos_flutter_app/core/desktop_runtime_role.dart';
import 'package:memos_flutter_app/features/desktop/quick_input/desktop_quick_input_capabilities.dart';

void main() {
  test('desktop exit closes databases before main window termination', () {
    final steps = DesktopExitCoordinator.debugExitStepOrder();

    expect(steps, <String>[
      'prepare_for_exit',
      'close_sub_windows',
      'unregister_hotkey',
      'dispose_tray',
      'close_databases',
      'disable_prevent_close',
      'close_main_window',
      'await_main_window_teardown',
    ]);

    expect(
      steps.indexOf('close_databases'),
      lessThan(steps.indexOf('close_main_window')),
    );
    expect(
      steps.indexOf('disable_prevent_close'),
      lessThan(steps.indexOf('close_main_window')),
    );
  });

  test(
    'desktop exit uses graceful close semantics for main-window termination',
    () {
      expect(
        DesktopExitCoordinator.debugMainWindowTerminationAction(),
        'close',
      );
    },
  );

  test('desktop close request preserves close-to-tray split', () {
    expect(
      DesktopExitCoordinator.debugCloseRequestAction(
        isWindows: true,
        closeToTray: true,
        traySupported: true,
      ),
      'hideToTray',
    );
    expect(
      DesktopExitCoordinator.debugCloseRequestAction(
        isWindows: true,
        closeToTray: false,
        traySupported: true,
      ),
      'fullExit',
    );
    expect(
      DesktopExitCoordinator.debugCloseRequestAction(
        isWindows: true,
        closeToTray: true,
        traySupported: false,
      ),
      'fullExit',
    );
    expect(
      DesktopExitCoordinator.debugCloseRequestAction(
        isWindows: false,
        closeToTray: true,
        traySupported: true,
      ),
      'nativeClose',
    );
  });

  test('macOS close request preserves route and menu-bar split', () {
    expect(
      DesktopExitCoordinator.debugMacosCloseRequestAction(
        hasSecondaryRoute: true,
        closeToMenuBar: true,
        statusIconSupported: true,
      ),
      'popSecondaryRoute',
    );
    expect(
      DesktopExitCoordinator.debugMacosCloseRequestAction(
        hasSecondaryRoute: false,
        closeToMenuBar: true,
        statusIconSupported: true,
      ),
      'hideToMenuBar',
    );
    expect(
      DesktopExitCoordinator.debugMacosCloseRequestAction(
        hasSecondaryRoute: false,
        closeToMenuBar: false,
        statusIconSupported: true,
      ),
      'fullExit',
    );
    expect(
      DesktopExitCoordinator.debugMacosCloseRequestAction(
        hasSecondaryRoute: false,
        closeToMenuBar: true,
        statusIconSupported: false,
      ),
      'fullExit',
    );
  });

  test('secondary route close callback keeps guarded routes open', () async {
    var attempted = false;

    final handled =
        await DesktopExitCoordinator.debugInvokeSecondaryRouteCloseCallback(
          () async {
            attempted = true;
            return true;
          },
        );

    expect(attempted, isTrue);
    expect(handled, isTrue);
    expect(
      await DesktopExitCoordinator.debugInvokeSecondaryRouteCloseCallback(null),
      isFalse,
    );
  });

  test('desktop sub-window plugin registration excludes WebView plugins', () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
    final functionMatch = RegExp(
      r'void RegisterSubWindowPlugins\(flutter::PluginRegistry\* registry\) \{([\s\S]*?)\n\}',
    ).firstMatch(runner);

    expect(functionMatch, isNotNull);
    final body = functionMatch!.group(1)!;

    expect(body, isNot(contains('FlutterInappwebviewWindowsPlugin')));
    expect(body, isNot(contains('WebviewWindowsPlugin')));
  });

  test(
    'tray fallback exit destroys macOS app instead of closing main window',
    () {
      final controller = File(
        'lib/application/desktop/desktop_tray_controller.dart',
      ).readAsStringSync();
      final fallbackExitMatch = RegExp(
        r'Future<void> _exitFromTray\(\) async \{([\s\S]*?)\n  \}',
      ).firstMatch(controller);

      expect(fallbackExitMatch, isNotNull);
      final body = fallbackExitMatch!.group(1)!;

      expect(body, contains('Platform.isMacOS'));
      expect(body, contains('windowManager.destroy()'));
    },
  );

  test('Windows quick input sub-window does not expose location picker', () {
    expect(
      desktopQuickInputCanUseLocationPicker(
        runtimeRole: DesktopRuntimeRole.desktopQuickInput,
        isWindows: true,
      ),
      isFalse,
    );
    expect(
      desktopQuickInputCanUseLocationPicker(
        runtimeRole: DesktopRuntimeRole.mainApp,
        isWindows: true,
      ),
      isTrue,
    );
    expect(
      desktopQuickInputCanUseLocationPicker(
        runtimeRole: DesktopRuntimeRole.desktopQuickInput,
        isWindows: false,
      ),
      isTrue,
    );
  });
}
