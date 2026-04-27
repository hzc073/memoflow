import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum DesktopResizeHandle {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

@immutable
class DesktopResizablePanelRect {
  const DesktopResizablePanelRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  DesktopResizablePanelRect copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return DesktopResizablePanelRect(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class DesktopResizablePanelShell extends StatefulWidget {
  const DesktopResizablePanelShell({
    super.key,
    required this.viewportSize,
    required this.rect,
    required this.minWidth,
    required this.maxWidth,
    required this.minHeight,
    required this.maxHeight,
    required this.hitZoneExtent,
    this.boundaryInsets = EdgeInsets.zero,
    this.enabledHandles,
    required this.onChanged,
    required this.onChangeEnd,
    required this.child,
  });

  final Size viewportSize;
  final DesktopResizablePanelRect rect;
  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
  final double hitZoneExtent;
  final EdgeInsets boundaryInsets;
  final Set<DesktopResizeHandle>? enabledHandles;
  final ValueChanged<DesktopResizablePanelRect> onChanged;
  final ValueChanged<DesktopResizablePanelRect> onChangeEnd;
  final Widget child;

  @override
  State<DesktopResizablePanelShell> createState() =>
      _DesktopResizablePanelShellState();
}

class _DesktopResizablePanelShellState
    extends State<DesktopResizablePanelShell> {
  DesktopResizeHandle? _activeHandle;
  int? _activePointer;
  Offset? _dragStartGlobalPosition;
  DesktopResizablePanelRect? _dragStartRect;
  DesktopResizablePanelRect? _lastDispatchedRect;

  @override
  Widget build(BuildContext context) {
    final rect = widget.rect;
    final hitZoneExtent = widget.hitZoneExtent;
    final cornerExtent = hitZoneExtent * 2;

    return SizedBox.fromSize(
      size: widget.viewportSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: widget.child,
          ),
          _buildHandle(
            handle: DesktopResizeHandle.left,
            cursor: SystemMouseCursors.resizeLeftRight,
            left: rect.left - hitZoneExtent,
            top: rect.top + cornerExtent,
            width: hitZoneExtent * 2,
            height: (rect.height - cornerExtent * 2).clamp(0, double.infinity),
          ),
          _buildHandle(
            handle: DesktopResizeHandle.right,
            cursor: SystemMouseCursors.resizeLeftRight,
            left: rect.right - hitZoneExtent,
            top: rect.top + cornerExtent,
            width: hitZoneExtent * 2,
            height: (rect.height - cornerExtent * 2).clamp(0, double.infinity),
          ),
          _buildHandle(
            handle: DesktopResizeHandle.top,
            cursor: SystemMouseCursors.resizeUpDown,
            left: rect.left + cornerExtent,
            top: rect.top - hitZoneExtent,
            width: (rect.width - cornerExtent * 2).clamp(0, double.infinity),
            height: hitZoneExtent * 2,
          ),
          _buildHandle(
            handle: DesktopResizeHandle.bottom,
            cursor: SystemMouseCursors.resizeUpDown,
            left: rect.left + cornerExtent,
            top: rect.bottom - hitZoneExtent,
            width: (rect.width - cornerExtent * 2).clamp(0, double.infinity),
            height: hitZoneExtent * 2,
          ),
          _buildHandle(
            handle: DesktopResizeHandle.topLeft,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            left: rect.left - hitZoneExtent,
            top: rect.top - hitZoneExtent,
            width: cornerExtent,
            height: cornerExtent,
          ),
          _buildHandle(
            handle: DesktopResizeHandle.topRight,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            left: rect.right - hitZoneExtent,
            top: rect.top - hitZoneExtent,
            width: cornerExtent,
            height: cornerExtent,
          ),
          _buildHandle(
            handle: DesktopResizeHandle.bottomLeft,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            left: rect.left - hitZoneExtent,
            top: rect.bottom - hitZoneExtent,
            width: cornerExtent,
            height: cornerExtent,
          ),
          _buildHandle(
            handle: DesktopResizeHandle.bottomRight,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            left: rect.right - hitZoneExtent,
            top: rect.bottom - hitZoneExtent,
            width: cornerExtent,
            height: cornerExtent,
          ),
        ],
      ),
    );
  }

  Widget _buildHandle({
    required DesktopResizeHandle handle,
    required MouseCursor cursor,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final enabledHandles = widget.enabledHandles;
    if (enabledHandles != null && !enabledHandles.contains(handle)) {
      return const SizedBox.shrink();
    }
    if (width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        opaque: false,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (recognizer) {},
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _handlePointerDown(handle, event),
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: SizedBox(
              key: ValueKey<String>('desktop-resizable-panel-${handle.name}'),
              width: width,
              height: height,
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(DesktopResizeHandle handle, PointerDownEvent event) {
    _activeHandle = handle;
    _activePointer = event.pointer;
    _dragStartGlobalPosition = event.position;
    _dragStartRect = widget.rect;
    _lastDispatchedRect = widget.rect;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final activeHandle = _activeHandle;
    final activePointer = _activePointer;
    final dragStartGlobalPosition = _dragStartGlobalPosition;
    final dragStartRect = _dragStartRect;
    if (activeHandle == null ||
        activePointer != event.pointer ||
        dragStartGlobalPosition == null ||
        dragStartRect == null) {
      return;
    }
    final delta = event.position - dragStartGlobalPosition;
    final next = _resizeRect(dragStartRect, delta, activeHandle);
    _lastDispatchedRect = next;
    widget.onChanged(next);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _finishInteraction();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _finishInteraction();
  }

  void _finishInteraction() {
    final lastRect = _lastDispatchedRect ?? widget.rect;
    _activeHandle = null;
    _activePointer = null;
    _dragStartGlobalPosition = null;
    _dragStartRect = null;
    _lastDispatchedRect = null;
    widget.onChangeEnd(lastRect);
  }

  DesktopResizablePanelRect _resizeRect(
    DesktopResizablePanelRect startRect,
    Offset delta,
    DesktopResizeHandle handle,
  ) {
    final boundsLeft = widget.hitZoneExtent + widget.boundaryInsets.left;
    final boundsTop = widget.hitZoneExtent + widget.boundaryInsets.top;
    final boundsRight =
        widget.viewportSize.width -
        widget.hitZoneExtent -
        widget.boundaryInsets.right;
    var left = startRect.left;
    var right = startRect.right;
    var top = startRect.top;
    var bottom = startRect.bottom;

    final canMoveLeft =
        handle == DesktopResizeHandle.left ||
        handle == DesktopResizeHandle.topLeft ||
        handle == DesktopResizeHandle.bottomLeft;
    final canMoveRight =
        handle == DesktopResizeHandle.right ||
        handle == DesktopResizeHandle.topRight ||
        handle == DesktopResizeHandle.bottomRight;
    final canMoveTop =
        handle == DesktopResizeHandle.top ||
        handle == DesktopResizeHandle.topLeft ||
        handle == DesktopResizeHandle.topRight;
    final canMoveBottom =
        handle == DesktopResizeHandle.bottom ||
        handle == DesktopResizeHandle.bottomLeft ||
        handle == DesktopResizeHandle.bottomRight;

    if (canMoveLeft) {
      final minLeft = (right - widget.maxWidth).clamp(boundsLeft, right);
      final maxLeft = (right - widget.minWidth).clamp(boundsLeft, right);
      left = (startRect.left + delta.dx).clamp(minLeft, maxLeft);
    }
    if (canMoveRight) {
      final minRight = (left + widget.minWidth).clamp(left, boundsRight);
      final maxRight = (left + widget.maxWidth).clamp(left, boundsRight);
      right = (startRect.right + delta.dx).clamp(minRight, maxRight);
    }
    if (canMoveTop) {
      final minTop = (bottom - widget.maxHeight).clamp(boundsTop, bottom);
      final maxTop = (bottom - widget.minHeight).clamp(boundsTop, bottom);
      top = (startRect.top + delta.dy).clamp(minTop, maxTop);
    }
    if (canMoveBottom) {
      final minBottom = top + widget.minHeight;
      final maxBottom = top + widget.maxHeight;
      bottom = (startRect.bottom + delta.dy).clamp(minBottom, maxBottom);
    }

    return DesktopResizablePanelRect(
      left: left.toDouble(),
      top: top.toDouble(),
      width: (right - left).toDouble(),
      height: (bottom - top).toDouble(),
    );
  }
}
