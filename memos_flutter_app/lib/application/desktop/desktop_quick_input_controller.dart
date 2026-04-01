import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../core/desktop_quick_input_channel.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/tags.dart';
import 'desktop_tray_controller.dart';
import '../../core/top_toast.dart';
import '../../data/models/app_preferences.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../features/memos/link_memo_sheet.dart';
import '../../i18n/strings.g.dart';
import '../quick_input/quick_input_service.dart';

typedef DesktopSubWindowVisibilityUpdater =
    void Function({required int windowId, required bool visible});

typedef DesktopQuickInputWindowIdListener = void Function(int? windowId);

class DesktopQuickInputController {
  DesktopQuickInputController({
    required AppBootstrapAdapter bootstrapAdapter,
    required QuickInputService quickInputService,
    required WidgetRef ref,
    required GlobalKey<NavigatorState> navigatorKey,
    required VoidCallback ensureMethodHandlerBound,
    required DesktopSubWindowVisibilityUpdater onSubWindowVisibilityChanged,
    required DesktopQuickInputWindowIdListener onWindowIdChanged,
    required bool Function() isMounted,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _quickInputService = quickInputService,
       _ref = ref,
       _navigatorKey = navigatorKey,
       _ensureMethodHandlerBound = ensureMethodHandlerBound,
       _onSubWindowVisibilityChanged = onSubWindowVisibilityChanged,
       _onWindowIdChanged = onWindowIdChanged,
       _isMounted = isMounted;

  final AppBootstrapAdapter _bootstrapAdapter;
  final QuickInputService _quickInputService;
  final WidgetRef _ref;
  final GlobalKey<NavigatorState> _navigatorKey;
  final VoidCallback _ensureMethodHandlerBound;
  final DesktopSubWindowVisibilityUpdater _onSubWindowVisibilityChanged;
  final DesktopQuickInputWindowIdListener _onWindowIdChanged;
  final bool Function() _isMounted;

  HotKey? _desktopQuickInputHotKey;
  WindowController? _desktopQuickInputWindow;
  int? _desktopQuickInputWindowId;
  bool _desktopQuickInputWindowOpening = false;
  Future<void>? _desktopQuickInputWindowPrepareTask;

  Future<void> registerHotKey(AppPreferences prefs) async {
    if (!isDesktopShortcutEnabled()) return;
    final bindings = normalizeDesktopShortcutBindings(
      prefs.desktopShortcutBindings,
    );
    final binding = bindings[DesktopShortcutAction.quickRecord];
    if (binding == null) return;

    final nextHotKey = HotKey(
      key: binding.logicalKey,
      modifiers: <HotKeyModifier>[
        if (binding.primary)
          defaultTargetPlatform == TargetPlatform.macOS
              ? HotKeyModifier.meta
              : HotKeyModifier.control,
        if (binding.shift) HotKeyModifier.shift,
        if (binding.alt) HotKeyModifier.alt,
      ],
      scope: HotKeyScope.system,
    );

    final previous = _desktopQuickInputHotKey;
    if (previous != null) {
      try {
        await hotKeyManager.unregister(previous);
      } catch (_) {}
    }

    try {
      await hotKeyManager.register(
        nextHotKey,
        keyDownHandler: (_) {
          _bootstrapAdapter
              .readLogManager(_ref)
              .info(
                'Desktop shortcut matched',
                context: const <String, Object?>{
                  'action': 'quickRecord',
                  'source': 'system_hotkey',
                },
              );
          unawaited(handleHotKey());
        },
      );
      _desktopQuickInputHotKey = nextHotKey;
    } catch (error, stackTrace) {
      _bootstrapAdapter
          .readLogManager(_ref)
          .error(
            'Register desktop quick input hotkey failed',
            error: error,
            stackTrace: stackTrace,
          );
    }
  }

  Future<void> unregisterHotKey() async {
    final hotKey = _desktopQuickInputHotKey;
    if (hotKey == null) return;
    try {
      await hotKeyManager.unregister(hotKey);
    } catch (_) {}
    _desktopQuickInputHotKey = null;
  }

  Future<void> prewarm() async {
    await _ensureDesktopQuickInputWindowReady();
  }

  Future<void> handleHotKey() async {
    if (!_isMounted() || !isDesktopShortcutEnabled()) return;
    if (_desktopQuickInputWindowOpening) return;
    _ensureMethodHandlerBound();

    final session = _bootstrapAdapter.readSession(_ref);
    final localLibrary = _bootstrapAdapter.readCurrentLocalLibrary(_ref);
    if (session?.currentAccount == null && localLibrary == null) {
      await DesktopTrayController.instance.showFromTray();
      return;
    }

    _desktopQuickInputWindowOpening = true;
    try {
      var window = await _ensureDesktopQuickInputWindowReady();
      try {
        await window.show();
        _onSubWindowVisibilityChanged(windowId: window.windowId, visible: true);
        await _focusDesktopQuickInputWindow(window.windowId);
      } catch (_) {
        // The cached controller can be stale after user closed sub-window.
        _desktopQuickInputWindow = null;
        _desktopQuickInputWindowId = null;
        _onWindowIdChanged(null);
        window = await _ensureDesktopQuickInputWindowReady();
        await window.show();
        _onSubWindowVisibilityChanged(windowId: window.windowId, visible: true);
        await _focusDesktopQuickInputWindow(window.windowId);
      }
    } catch (error, stackTrace) {
      _bootstrapAdapter
          .readLogManager(_ref)
          .error(
            'Desktop quick input hotkey action failed',
            error: error,
            stackTrace: stackTrace,
          );
      if (!_isMounted()) return;
      final context = _resolveDesktopUiContext();
      if (context?.mounted == true) {
        showTopToast(
          context!,
          context.t.strings.legacy.msg_quick_input_failed_with_error(
            error: error,
          ),
        );
      }
    } finally {
      _desktopQuickInputWindowOpening = false;
    }
  }

  Future<dynamic> handleMethodCall(MethodCall call, int fromWindowId) async {
    if (!_isMounted()) return null;
    switch (call.method) {
      case desktopQuickInputSubmitMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final contentRaw = map == null ? null : map['content'];
        final content = (contentRaw as String? ?? '').trimRight();
        final attachmentPayloads = _quickInputService.parsePayloadMapList(
          map == null ? null : map['attachments'],
        );
        final relations = _quickInputService.parsePayloadMapList(
          map == null ? null : map['relations'],
        );
        final location = _quickInputService.parseLocation(
          map == null ? null : map['location'],
        );
        if (content.trim().isEmpty && attachmentPayloads.isEmpty) return false;
        try {
          await _quickInputService.submitDesktopQuickInput(
            _ref,
            content,
            attachmentPayloads: attachmentPayloads,
            location: location,
            relations: relations,
          );
          if (!_isMounted()) return true;
          final context = _resolveDesktopUiContext();
          if (context?.mounted == true) {
            showTopToast(
              context!,
              context.t.strings.legacy.msg_saved_to_memoflow,
            );
          }
          return true;
        } catch (error, stackTrace) {
          _bootstrapAdapter
              .readLogManager(_ref)
              .error(
                'Desktop quick input submit from sub-window failed',
                error: error,
                stackTrace: stackTrace,
              );
          if (!_isMounted()) return false;
          final context = _resolveDesktopUiContext();
          if (context?.mounted == true) {
            showTopToast(
              context!,
              context.t.strings.legacy.msg_quick_input_failed_with_error(
                error: error,
              ),
            );
          }
          return false;
        }
      case desktopQuickInputPlaceholderMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final labelRaw = map == null ? null : map['label'];
        final context = _resolveDesktopUiContext();
        final defaultLabel = context?.t.strings.legacy.msg_feature ?? 'Feature';
        final label = (labelRaw as String? ?? defaultLabel).trim();
        if (context != null) {
          showTopToast(
            context,
            context.t.strings.legacy
                .msg_feature_not_implemented_placeholder_with_label(
                  label: label,
                ),
          );
        }
        return true;
      case desktopQuickInputPickLinkMemoMethod:
        if (_resolveDesktopUiContext() == null) {
          await DesktopTrayController.instance.showFromTray();
          await Future<void>.delayed(const Duration(milliseconds: 160));
        }
        final context = _resolveDesktopUiContext();
        if (context == null) {
          return {'error_message': 'main_window_not_ready'};
        }
        if (!context.mounted) {
          return {'error_message': 'main_window_not_ready'};
        }
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final rawNames = map == null ? null : map['existingNames'];
        final existingNames = <String>{};
        if (rawNames is List) {
          for (final item in rawNames) {
            final value = (item as String? ?? '').trim();
            if (value.isNotEmpty) existingNames.add(value);
          }
        }
        final selection = await LinkMemoSheet.show(
          context,
          existingNames: existingNames,
        );
        if (!_isMounted() || selection == null) return null;
        final name = selection.name.trim();
        if (name.isEmpty) return null;
        final raw = selection.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        final fallback = name.startsWith('memos/')
            ? name.substring('memos/'.length)
            : name;
        final label = _truncateDesktopQuickInputLabel(
          raw.isNotEmpty ? raw : fallback,
        );
        return {'name': name, 'label': label};
      case desktopQuickInputListTagsMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final rawExisting = map == null ? null : map['existingTags'];
        final existing = <String>{};
        if (rawExisting is List) {
          for (final item in rawExisting) {
            final normalized = normalizeTagPath((item as String? ?? ''));
            if (normalized.isNotEmpty) {
              existing.add(normalized);
            }
          }
        }
        try {
          final stats = await _bootstrapAdapter.readTagStats(_ref);
          final tags = <String>[];
          for (final stat in stats) {
            final tag = normalizeTagPath(stat.tag);
            if (tag.isEmpty) continue;
            if (existing.contains(tag)) continue;
            tags.add(stat.tag.trim());
          }
          return tags;
        } catch (_) {
          return const <String>[];
        }
      case desktopQuickInputPingMethod:
        return true;
      case desktopQuickInputClosedMethod:
        _onSubWindowVisibilityChanged(windowId: fromWindowId, visible: false);
        if (_desktopQuickInputWindowId == fromWindowId) {
          _desktopQuickInputWindow = null;
          _desktopQuickInputWindowId = null;
          _onWindowIdChanged(null);
        }
        return true;
      default:
        return null;
    }
  }

  BuildContext? _resolveDesktopUiContext() {
    final direct = _navigatorKey.currentContext;
    if (direct != null && direct.mounted) return direct;
    final overlay = _navigatorKey.currentState?.overlay?.context;
    if (overlay != null && overlay.mounted) return overlay;
    return null;
  }

  Future<WindowController> _ensureDesktopQuickInputWindowReady() async {
    await _refreshDesktopQuickInputWindowReference();
    final existing = _desktopQuickInputWindow;
    if (existing != null) return existing;

    final pending = _desktopQuickInputWindowPrepareTask;
    if (pending != null) {
      await pending;
      await _refreshDesktopQuickInputWindowReference();
      final prepared = _desktopQuickInputWindow;
      if (prepared != null) return prepared;
    }

    final completer = Completer<void>();
    _desktopQuickInputWindowPrepareTask = completer.future;
    try {
      await _refreshDesktopQuickInputWindowReference();
      final refreshed = _desktopQuickInputWindow;
      if (refreshed != null) return refreshed;

      final window = await DesktopMultiWindow.createWindow(
        jsonEncode(<String, dynamic>{
          desktopWindowTypeKey: desktopWindowTypeQuickInput,
        }),
      );
      _desktopQuickInputWindow = window;
      _desktopQuickInputWindowId = window.windowId;
      _onWindowIdChanged(window.windowId);
      await window.setTitle('MemoFlow');
      await window.setFrame(const Offset(0, 0) & Size(420, 760));
      await window.center();
      return window;
    } finally {
      completer.complete();
      if (identical(_desktopQuickInputWindowPrepareTask, completer.future)) {
        _desktopQuickInputWindowPrepareTask = null;
      }
    }
  }

  Future<void> _refreshDesktopQuickInputWindowReference() async {
    final trackedId = _desktopQuickInputWindowId;
    if (trackedId == null) {
      _desktopQuickInputWindow = null;
      return;
    }
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (!ids.contains(trackedId)) {
        _onSubWindowVisibilityChanged(windowId: trackedId, visible: false);
        _desktopQuickInputWindow = null;
        _desktopQuickInputWindowId = null;
        _onWindowIdChanged(null);
        return;
      }
      _desktopQuickInputWindow ??= WindowController.fromWindowId(trackedId);
    } catch (_) {
      _onSubWindowVisibilityChanged(windowId: trackedId, visible: false);
      _desktopQuickInputWindow = null;
      _desktopQuickInputWindowId = null;
      _onWindowIdChanged(null);
    }
  }

  Future<void> _focusDesktopQuickInputWindow(int windowId) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputFocusMethod,
        null,
      );
    } catch (_) {}
  }

  String _truncateDesktopQuickInputLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
