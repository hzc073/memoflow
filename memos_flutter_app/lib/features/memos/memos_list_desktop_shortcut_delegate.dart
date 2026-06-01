import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/desktop/shortcuts.dart';

enum MemosListDesktopShortcutDispatchStage {
  ignored,
  noMatch,
  matched,
  delegated,
}

@immutable
class MemosListDesktopShortcutDispatch {
  const MemosListDesktopShortcutDispatch({
    required this.stage,
    this.action,
    this.reason,
    this.extra = const <String, Object?>{},
  });

  final MemosListDesktopShortcutDispatchStage stage;
  final DesktopShortcutAction? action;
  final String? reason;
  final Map<String, Object?> extra;

  bool get handled =>
      stage == MemosListDesktopShortcutDispatchStage.matched ||
      stage == MemosListDesktopShortcutDispatchStage.delegated;

  bool get shouldLog =>
      stage != MemosListDesktopShortcutDispatchStage.noMatch ||
      action != null ||
      reason != null ||
      extra.isNotEmpty;
}

@immutable
class MemosListDesktopShortcutCallbacks {
  const MemosListDesktopShortcutCallbacks({
    required this.onMarkDesktopShortcutGuideSeen,
    required this.onOpenShortcutOverview,
    required this.onFocusSearch,
    required this.onOpenQuickInput,
    required this.onOpenQuickRecord,
    required this.onSubmitInlineCompose,
    required this.onToggleBold,
    required this.onToggleUnderline,
    required this.onToggleHighlight,
    required this.onToggleUnorderedList,
    required this.onToggleOrderedList,
    required this.onUndo,
    required this.onRedo,
    required this.onPageNavigation,
    required this.onOpenPasswordLock,
    required this.onToggleSidebar,
    required this.onRefresh,
    required this.onBackHome,
    required this.onOpenSettings,
    required this.onToggleMemoFlowVisibility,
  });

  final VoidCallback onMarkDesktopShortcutGuideSeen;
  final VoidCallback onOpenShortcutOverview;
  final VoidCallback onFocusSearch;
  final VoidCallback onOpenQuickInput;
  final VoidCallback onOpenQuickRecord;
  final VoidCallback onSubmitInlineCompose;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleUnderline;
  final VoidCallback onToggleHighlight;
  final VoidCallback onToggleUnorderedList;
  final VoidCallback onToggleOrderedList;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool Function({required bool down, required String source})
  onPageNavigation;
  final VoidCallback onOpenPasswordLock;
  final String Function() onToggleSidebar;
  final VoidCallback onRefresh;
  final VoidCallback onBackHome;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleMemoFlowVisibility;
}

class MemosListDesktopShortcutDelegate {
  const MemosListDesktopShortcutDelegate({
    required this.bindingsResolver,
    required this.routeActive,
    required this.inlineEditorActive,
    required this.quickRecordSystemHotKeyActive,
    required this.callbacks,
  });

  final Map<DesktopShortcutAction, DesktopShortcutBinding> Function()
  bindingsResolver;
  final bool Function() routeActive;
  final bool Function() inlineEditorActive;
  final bool Function() quickRecordSystemHotKeyActive;
  final MemosListDesktopShortcutCallbacks callbacks;

  MemosListDesktopShortcutDispatch handle(
    KeyEvent event,
    Set<LogicalKeyboardKey> pressedKeys,
  ) {
    if (event is! KeyDownEvent) {
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.noMatch,
      );
    }

    final traceThisKey = _shouldTraceDesktopShortcut(event, pressedKeys);
    if (!routeActive()) {
      if (!traceThisKey) {
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.noMatch,
        );
      }
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.ignored,
        reason: 'route_inactive_or_locked',
      );
    }

    final bindings = bindingsResolver();
    bool matches(DesktopShortcutAction action) {
      return matchesDesktopShortcut(
        event: event,
        pressedKeys: pressedKeys,
        binding: bindings[action]!,
      );
    }

    final key = event.logicalKey;
    final isInlineEditorActive = inlineEditorActive();

    if (matches(DesktopShortcutAction.shortcutOverview) ||
        key == LogicalKeyboardKey.f1) {
      callbacks.onMarkDesktopShortcutGuideSeen();
      callbacks.onOpenShortcutOverview();
      return MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.shortcutOverview,
        reason: key == LogicalKeyboardKey.f1 ? 'f1_fallback' : null,
      );
    }

    if (matches(DesktopShortcutAction.search)) {
      callbacks.onMarkDesktopShortcutGuideSeen();
      callbacks.onFocusSearch();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.search,
      );
    }

    if (matches(DesktopShortcutAction.quickInput)) {
      callbacks.onOpenQuickInput();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.quickInput,
      );
    }

    if (matches(DesktopShortcutAction.quickRecord)) {
      callbacks.onMarkDesktopShortcutGuideSeen();
      if (quickRecordSystemHotKeyActive()) {
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.delegated,
          action: DesktopShortcutAction.quickRecord,
          reason: 'handled_by_app_hotkey_manager',
        );
      }
      callbacks.onOpenQuickRecord();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.quickRecord,
        reason: 'system_hotkey_unavailable_fallback',
      );
    }

    if (isInlineEditorActive) {
      final publishMatched = matches(DesktopShortcutAction.publishMemo);
      if (publishMatched ||
          (!isPrimaryShortcutModifierPressed(pressedKeys) &&
              isShiftModifierPressed(pressedKeys) &&
              !isAltModifierPressed(pressedKeys) &&
              key == LogicalKeyboardKey.enter)) {
        callbacks.onSubmitInlineCompose();
        return MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.publishMemo,
          reason: publishMatched ? 'binding' : 'shift_enter_fallback',
        );
      }

      if (matches(DesktopShortcutAction.bold)) {
        callbacks.onToggleBold();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.bold,
        );
      }

      if (matches(DesktopShortcutAction.underline)) {
        callbacks.onToggleUnderline();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.underline,
        );
      }

      if (matches(DesktopShortcutAction.highlight)) {
        callbacks.onToggleHighlight();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.highlight,
        );
      }

      if (matches(DesktopShortcutAction.unorderedList)) {
        callbacks.onToggleUnorderedList();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.unorderedList,
        );
      }

      if (matches(DesktopShortcutAction.orderedList)) {
        callbacks.onToggleOrderedList();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.orderedList,
        );
      }

      if (matches(DesktopShortcutAction.undo)) {
        callbacks.onUndo();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.undo,
        );
      }

      if (matches(DesktopShortcutAction.redo)) {
        callbacks.onRedo();
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.redo,
        );
      }
    }

    if (!isInlineEditorActive && matches(DesktopShortcutAction.previousPage)) {
      final handled = callbacks.onPageNavigation(
        down: false,
        source: 'shortcut_previous_page',
      );
      if (handled) {
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.previousPage,
        );
      }
    }

    if (!isInlineEditorActive && matches(DesktopShortcutAction.nextPage)) {
      final handled = callbacks.onPageNavigation(
        down: true,
        source: 'shortcut_next_page',
      );
      if (handled) {
        return const MemosListDesktopShortcutDispatch(
          stage: MemosListDesktopShortcutDispatchStage.matched,
          action: DesktopShortcutAction.nextPage,
        );
      }
    }

    if (matches(DesktopShortcutAction.enableAppLock)) {
      callbacks.onOpenPasswordLock();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.enableAppLock,
      );
    }

    if (matches(DesktopShortcutAction.toggleSidebar)) {
      final drawerResult = callbacks.onToggleSidebar();
      return MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.toggleSidebar,
        extra: <String, Object?>{'drawerResult': drawerResult},
      );
    }

    if (matches(DesktopShortcutAction.refresh)) {
      callbacks.onRefresh();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.refresh,
      );
    }

    if (matches(DesktopShortcutAction.backHome)) {
      callbacks.onBackHome();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.backHome,
      );
    }

    if (matches(DesktopShortcutAction.openSettings)) {
      callbacks.onOpenSettings();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.openSettings,
      );
    }

    if (matches(DesktopShortcutAction.toggleFlomo)) {
      callbacks.onToggleMemoFlowVisibility();
      return const MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.matched,
        action: DesktopShortcutAction.toggleFlomo,
      );
    }

    if (traceThisKey) {
      return MemosListDesktopShortcutDispatch(
        stage: MemosListDesktopShortcutDispatchStage.noMatch,
        extra: <String, Object?>{'inlineEditorActive': isInlineEditorActive},
      );
    }

    return const MemosListDesktopShortcutDispatch(
      stage: MemosListDesktopShortcutDispatchStage.noMatch,
    );
  }

  bool _shouldTraceDesktopShortcut(
    KeyEvent event,
    Set<LogicalKeyboardKey> pressedKeys,
  ) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f1) return true;
    return isPrimaryShortcutModifierPressed(pressedKeys) ||
        isShiftModifierPressed(pressedKeys) ||
        isAltModifierPressed(pressedKeys);
  }
}
