import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:memos_flutter_app/application/desktop/desktop_quick_input_controller.dart';
import 'package:memos_flutter_app/application/desktop/desktop_quick_record_hotkey_state.dart';
import 'package:memos_flutter_app/application/quick_input/quick_input_service.dart';
import 'package:memos_flutter_app/data/logs/log_manager.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/state/memos/app_bootstrap_adapter_provider.dart';

class _FakeBootstrapAdapter extends AppBootstrapAdapter {
  const _FakeBootstrapAdapter();

  @override
  LogManager readLogManager(WidgetRef ref) => LogManager.instance;
}

class _ControllerHarness extends ConsumerStatefulWidget {
  const _ControllerHarness({required this.spy, required this.onReady});

  final _HotKeySpy spy;
  final void Function(DesktopQuickInputController controller) onReady;

  @override
  ConsumerState<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends ConsumerState<_ControllerHarness> {
  late final GlobalKey<NavigatorState> _navigatorKey;
  late final DesktopQuickInputController _controller;

  @override
  void initState() {
    super.initState();
    const adapter = _FakeBootstrapAdapter();
    _navigatorKey = GlobalKey<NavigatorState>();
    _controller = DesktopQuickInputController(
      bootstrapAdapter: adapter,
      quickInputService: QuickInputService(bootstrapAdapter: adapter),
      ref: ref,
      navigatorKey: _navigatorKey,
      ensureMethodHandlerBound: () {},
      onSubWindowVisibilityChanged:
          ({required int windowId, required bool visible}) {},
      onWindowIdChanged: (_) {},
      onQuickInputRequested: (_) {},
      isMounted: () => mounted,
      registerDesktopHotKey: widget.spy.register,
      unregisterDesktopHotKey: widget.spy.unregister,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady(_controller);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: const SizedBox.shrink(),
    );
  }
}

class _HotKeySpy {
  bool failRegister = false;
  int registerCalls = 0;
  int unregisterCalls = 0;
  final registeredHotKeys = <HotKey>[];
  final unregisteredHotKeys = <HotKey>[];

  Future<void> register(HotKey hotKey, {HotKeyHandler? keyDownHandler}) async {
    registerCalls += 1;
    if (failRegister) {
      throw StateError('register failed');
    }
    registeredHotKeys.add(hotKey);
  }

  Future<void> unregister(HotKey hotKey) async {
    unregisterCalls += 1;
    unregisteredHotKeys.add(hotKey);
  }
}

Future<DesktopQuickInputController> _pumpController(
  WidgetTester tester,
  _HotKeySpy spy,
) async {
  final completer = Completer<DesktopQuickInputController>();
  await tester.pumpWidget(
    ProviderScope(
      child: _ControllerHarness(spy: spy, onReady: completer.complete),
    ),
  );
  await tester.pump();
  return completer.future;
}

Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('successful registration marks quick record hotkey active', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.windows, () async {
      final spy = _HotKeySpy();
      final controller = await _pumpController(tester, spy);

      await controller.registerHotKey(DevicePreferences.defaults);

      expect(spy.registerCalls, 1);
      expect(
        controller.quickRecordHotKeyRegistrationStatus,
        DesktopQuickRecordHotKeyRegistrationStatus.registered,
      );
      expect(controller.quickRecordSystemHotKeyActive, isTrue);
    });
  });

  testWidgets('failed re-registration clears stale active state', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.windows, () async {
      final spy = _HotKeySpy();
      final controller = await _pumpController(tester, spy);

      await controller.registerHotKey(DevicePreferences.defaults);
      expect(controller.quickRecordSystemHotKeyActive, isTrue);

      spy.failRegister = true;
      await controller.registerHotKey(DevicePreferences.defaults);

      expect(spy.unregisterCalls, 1);
      expect(spy.registerCalls, 2);
      expect(
        controller.quickRecordHotKeyRegistrationStatus,
        DesktopQuickRecordHotKeyRegistrationStatus.failed,
      );
      expect(controller.quickRecordSystemHotKeyActive, isFalse);
    });
  });

  testWidgets('unsupported platform leaves registration unavailable', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.linux, () async {
      final spy = _HotKeySpy();
      final controller = await _pumpController(tester, spy);

      await controller.registerHotKey(DevicePreferences.defaults);

      expect(spy.registerCalls, 0);
      expect(
        controller.quickRecordHotKeyRegistrationStatus,
        DesktopQuickRecordHotKeyRegistrationStatus.unavailable,
      );
      expect(controller.quickRecordSystemHotKeyActive, isFalse);
    });
  });

  testWidgets('unregister clears quick record active state', (tester) async {
    await _withTargetPlatform(TargetPlatform.windows, () async {
      final spy = _HotKeySpy();
      final controller = await _pumpController(tester, spy);

      await controller.registerHotKey(DevicePreferences.defaults);
      await controller.unregisterHotKey();

      expect(spy.unregisterCalls, 1);
      expect(
        controller.quickRecordHotKeyRegistrationStatus,
        DesktopQuickRecordHotKeyRegistrationStatus.unavailable,
      );
      expect(controller.quickRecordSystemHotKeyActive, isFalse);
    });
  });
}
