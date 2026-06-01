import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/shortcuts.dart';
import 'package:memos_flutter_app/features/memos/memos_list_desktop_shortcut_delegate.dart';

void main() {
  test('route inactive returns ignored for trace-worthy key', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(recorder: recorder, routeActive: false);

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyK,
        physicalKey: PhysicalKeyboardKey.keyK,
      ),
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyK,
      },
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.ignored);
    expect(dispatch.handled, isFalse);
    expect(dispatch.reason, 'route_inactive_or_locked');
    expect(recorder.totalCalls, 0);
  });

  test('F1 fallback opens shortcut overview and marks guide seen', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(recorder: recorder);

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.f1,
        physicalKey: PhysicalKeyboardKey.f1,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.f1},
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.matched);
    expect(dispatch.action, DesktopShortcutAction.shortcutOverview);
    expect(dispatch.reason, 'f1_fallback');
    expect(recorder.markGuideSeenCount, 1);
    expect(recorder.openShortcutOverviewCount, 1);
  });

  test('quick record delegates when system hotkey is active', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(
      recorder: recorder,
      quickRecordSystemHotKeyActive: true,
      bindings: <DesktopShortcutAction, DesktopShortcutBinding>{
        DesktopShortcutAction.quickRecord: _plainBinding(
          LogicalKeyboardKey.keyR,
        ),
      },
    );

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyR,
        physicalKey: PhysicalKeyboardKey.keyR,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyR},
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.delegated);
    expect(dispatch.action, DesktopShortcutAction.quickRecord);
    expect(dispatch.reason, 'handled_by_app_hotkey_manager');
    expect(recorder.markGuideSeenCount, 1);
    expect(recorder.openQuickRecordCount, 0);
  });

  test('quick record falls back in-window when system hotkey is inactive', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(
      recorder: recorder,
      quickRecordSystemHotKeyActive: false,
      bindings: <DesktopShortcutAction, DesktopShortcutBinding>{
        DesktopShortcutAction.quickRecord: _plainBinding(
          LogicalKeyboardKey.keyR,
        ),
      },
    );

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyR,
        physicalKey: PhysicalKeyboardKey.keyR,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyR},
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.matched);
    expect(dispatch.action, DesktopShortcutAction.quickRecord);
    expect(dispatch.reason, 'system_hotkey_unavailable_fallback');
    expect(recorder.markGuideSeenCount, 1);
    expect(recorder.openQuickRecordCount, 1);
  });

  test('quick record does not fallback when route inactive', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(
      recorder: recorder,
      routeActive: false,
      quickRecordSystemHotKeyActive: false,
      bindings: <DesktopShortcutAction, DesktopShortcutBinding>{
        DesktopShortcutAction.quickRecord: _plainBinding(
          LogicalKeyboardKey.keyR,
        ),
      },
    );

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyR,
        physicalKey: PhysicalKeyboardKey.keyR,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyR},
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.noMatch);
    expect(dispatch.handled, isFalse);
    expect(recorder.totalCalls, 0);
  });

  test('shift+enter fallback publishes memo in inline editor', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(
      recorder: recorder,
      inlineEditorActive: true,
    );

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.enter,
        physicalKey: PhysicalKeyboardKey.enter,
      ),
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.enter,
      },
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.matched);
    expect(dispatch.action, DesktopShortcutAction.publishMemo);
    expect(dispatch.reason, 'shift_enter_fallback');
    expect(recorder.submitInlineComposeCount, 1);
  });

  test('inline formatting callbacks are forwarded', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(
      recorder: recorder,
      inlineEditorActive: true,
      bindings: <DesktopShortcutAction, DesktopShortcutBinding>{
        DesktopShortcutAction.bold: _plainBinding(LogicalKeyboardKey.keyB),
        DesktopShortcutAction.underline: _plainBinding(LogicalKeyboardKey.keyU),
        DesktopShortcutAction.undo: _plainBinding(LogicalKeyboardKey.keyZ),
      },
    );

    final boldDispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyB,
        physicalKey: PhysicalKeyboardKey.keyB,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyB},
    );
    final underlineDispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyU,
        physicalKey: PhysicalKeyboardKey.keyU,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyU},
    );
    final undoDispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyZ,
        physicalKey: PhysicalKeyboardKey.keyZ,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyZ},
    );

    expect(boldDispatch.action, DesktopShortcutAction.bold);
    expect(underlineDispatch.action, DesktopShortcutAction.underline);
    expect(undoDispatch.action, DesktopShortcutAction.undo);
    expect(recorder.toggleBoldCount, 1);
    expect(recorder.toggleUnderlineCount, 1);
    expect(recorder.undoCount, 1);
  });

  test('next page only matches when page navigation callback handles it', () {
    final recorder = _CallbackRecorder()..pageNavigationResult = true;
    final delegate = _buildDelegate(recorder: recorder);

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.pageDown,
        physicalKey: PhysicalKeyboardKey.pageDown,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.pageDown},
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.matched);
    expect(dispatch.action, DesktopShortcutAction.nextPage);
    expect(recorder.lastPageNavigationDown, isTrue);
    expect(recorder.lastPageNavigationSource, 'shortcut_next_page');
  });

  test(
    'next page falls through to noMatch when navigation callback declines',
    () {
      final recorder = _CallbackRecorder()..pageNavigationResult = false;
      final delegate = _buildDelegate(recorder: recorder);

      final dispatch = delegate.handle(
        _keyDown(
          logicalKey: LogicalKeyboardKey.pageDown,
          physicalKey: PhysicalKeyboardKey.pageDown,
        ),
        <LogicalKeyboardKey>{LogicalKeyboardKey.pageDown},
      );

      expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.noMatch);
      expect(dispatch.handled, isFalse);
    },
  );

  test('toggle sidebar includes drawer result in extra payload', () {
    final recorder = _CallbackRecorder()..drawerResult = 'drawer_opened';
    final delegate = _buildDelegate(
      recorder: recorder,
      bindings: <DesktopShortcutAction, DesktopShortcutBinding>{
        DesktopShortcutAction.toggleSidebar: _plainBinding(
          LogicalKeyboardKey.keyS,
        ),
      },
    );

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyS,
        physicalKey: PhysicalKeyboardKey.keyS,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyS},
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.matched);
    expect(dispatch.action, DesktopShortcutAction.toggleSidebar);
    expect(dispatch.extra['drawerResult'], 'drawer_opened');
    expect(recorder.toggleSidebarCount, 1);
  });

  test('trace-worthy unmatched key returns noMatch without handling', () {
    final recorder = _CallbackRecorder();
    final delegate = _buildDelegate(recorder: recorder);

    final dispatch = delegate.handle(
      _keyDown(
        logicalKey: LogicalKeyboardKey.keyX,
        physicalKey: PhysicalKeyboardKey.keyX,
      ),
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyX,
      },
    );

    expect(dispatch.stage, MemosListDesktopShortcutDispatchStage.noMatch);
    expect(dispatch.handled, isFalse);
    expect(dispatch.extra['inlineEditorActive'], isFalse);
    expect(recorder.totalCalls, 0);
  });
}

MemosListDesktopShortcutDelegate _buildDelegate({
  required _CallbackRecorder recorder,
  bool routeActive = true,
  bool inlineEditorActive = false,
  bool quickRecordSystemHotKeyActive = false,
  Map<DesktopShortcutAction, DesktopShortcutBinding> bindings =
      const <DesktopShortcutAction, DesktopShortcutBinding>{},
}) {
  return MemosListDesktopShortcutDelegate(
    bindingsResolver: () => normalizeDesktopShortcutBindings(bindings),
    routeActive: () => routeActive,
    inlineEditorActive: () => inlineEditorActive,
    quickRecordSystemHotKeyActive: () => quickRecordSystemHotKeyActive,
    callbacks: MemosListDesktopShortcutCallbacks(
      onMarkDesktopShortcutGuideSeen: () => recorder.markGuideSeenCount++,
      onOpenShortcutOverview: () => recorder.openShortcutOverviewCount++,
      onFocusSearch: () => recorder.focusSearchCount++,
      onOpenQuickInput: () => recorder.openQuickInputCount++,
      onOpenQuickRecord: () => recorder.openQuickRecordCount++,
      onSubmitInlineCompose: () => recorder.submitInlineComposeCount++,
      onToggleBold: () => recorder.toggleBoldCount++,
      onToggleUnderline: () => recorder.toggleUnderlineCount++,
      onToggleHighlight: () => recorder.toggleHighlightCount++,
      onToggleUnorderedList: () => recorder.toggleUnorderedListCount++,
      onToggleOrderedList: () => recorder.toggleOrderedListCount++,
      onUndo: () => recorder.undoCount++,
      onRedo: () => recorder.redoCount++,
      onPageNavigation: ({required down, required source}) {
        recorder.lastPageNavigationDown = down;
        recorder.lastPageNavigationSource = source;
        return recorder.pageNavigationResult;
      },
      onOpenPasswordLock: () => recorder.openPasswordLockCount++,
      onToggleSidebar: () {
        recorder.toggleSidebarCount++;
        return recorder.drawerResult;
      },
      onRefresh: () => recorder.refreshCount++,
      onBackHome: () => recorder.backHomeCount++,
      onOpenSettings: () => recorder.openSettingsCount++,
      onToggleMemoFlowVisibility: () =>
          recorder.toggleMemoFlowVisibilityCount++,
    ),
  );
}

DesktopShortcutBinding _plainBinding(LogicalKeyboardKey key) {
  return DesktopShortcutBinding(
    keyId: key.keyId,
    primary: false,
    shift: false,
    alt: false,
  );
}

KeyDownEvent _keyDown({
  required LogicalKeyboardKey logicalKey,
  required PhysicalKeyboardKey physicalKey,
}) {
  return KeyDownEvent(
    timeStamp: Duration.zero,
    logicalKey: logicalKey,
    physicalKey: physicalKey,
  );
}

class _CallbackRecorder {
  int markGuideSeenCount = 0;
  int openShortcutOverviewCount = 0;
  int focusSearchCount = 0;
  int openQuickInputCount = 0;
  int openQuickRecordCount = 0;
  int submitInlineComposeCount = 0;
  int toggleBoldCount = 0;
  int toggleUnderlineCount = 0;
  int toggleHighlightCount = 0;
  int toggleUnorderedListCount = 0;
  int toggleOrderedListCount = 0;
  int undoCount = 0;
  int redoCount = 0;
  bool pageNavigationResult = false;
  bool? lastPageNavigationDown;
  String? lastPageNavigationSource;
  int openPasswordLockCount = 0;
  int toggleSidebarCount = 0;
  String drawerResult = 'drawer_closed';
  int refreshCount = 0;
  int backHomeCount = 0;
  int openSettingsCount = 0;
  int toggleMemoFlowVisibilityCount = 0;

  int get totalCalls =>
      markGuideSeenCount +
      openShortcutOverviewCount +
      focusSearchCount +
      openQuickInputCount +
      openQuickRecordCount +
      submitInlineComposeCount +
      toggleBoldCount +
      toggleUnderlineCount +
      toggleHighlightCount +
      toggleUnorderedListCount +
      toggleOrderedListCount +
      undoCount +
      redoCount +
      openPasswordLockCount +
      toggleSidebarCount +
      refreshCount +
      backHomeCount +
      openSettingsCount +
      toggleMemoFlowVisibilityCount;
}
