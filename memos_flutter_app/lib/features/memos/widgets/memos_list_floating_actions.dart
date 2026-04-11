import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/memoflow_palette.dart';
import '../../../i18n/strings.g.dart';

class MemoFlowFab extends StatefulWidget {
  const MemoFlowFab({
    super.key,
    required this.onPressed,
    required this.hapticsEnabled,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.size = 64,
    this.iconSize = 32,
    this.borderWidth = 4,
  });

  final VoidCallback? onPressed;
  final Future<void> Function(LongPressStartDetails details)? onLongPressStart;
  final void Function(LongPressMoveUpdateDetails details)?
  onLongPressMoveUpdate;
  final void Function(LongPressEndDetails details)? onLongPressEnd;
  final bool hapticsEnabled;
  final double size;
  final double iconSize;
  final double borderWidth;

  @override
  State<MemoFlowFab> createState() => _MemoFlowFabState();
}

class _MemoFlowFabState extends State<MemoFlowFab> {
  var _pressed = false;
  var _suppressTapForCurrentGesture = false;
  int? _trackedPointer;
  Offset? _pointerOriginGlobal;
  Offset? _pointerOriginLocal;
  var _trackingLongPressPointer = false;

  @override
  void dispose() {
    _detachTrackedPointerRoute();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _detachTrackedPointerRoute();
    _trackedPointer = event.pointer;
    _pointerOriginGlobal = event.position;
    _pointerOriginLocal = event.localPosition;
    _suppressTapForCurrentGesture = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_trackedPointer != event.pointer) return;
    _detachTrackedPointerRoute();
    _clearTrackedPointer();
    if (mounted) {
      setState(() => _pressed = false);
    }
  }

  void _attachTrackedPointerRoute() {
    final pointer = _trackedPointer;
    if (pointer == null || _trackingLongPressPointer) return;
    GestureBinding.instance.pointerRouter.addRoute(
      pointer,
      _handleTrackedPointerEvent,
    );
    _trackingLongPressPointer = true;
  }

  void _detachTrackedPointerRoute() {
    final pointer = _trackedPointer;
    if (pointer == null || !_trackingLongPressPointer) return;
    GestureBinding.instance.pointerRouter.removeRoute(
      pointer,
      _handleTrackedPointerEvent,
    );
    _trackingLongPressPointer = false;
  }

  void _clearTrackedPointer() {
    _trackedPointer = null;
    _pointerOriginGlobal = null;
    _pointerOriginLocal = null;
  }

  void _handleTrackedPointerEvent(PointerEvent event) {
    if (event.pointer != _trackedPointer) return;
    if (event is PointerMoveEvent) {
      _forwardLongPressMoveUpdate(event.position);
      return;
    }
    if (event is PointerUpEvent) {
      _forwardLongPressEnd(event.position);
      return;
    }
    if (event is PointerCancelEvent) {
      _forwardLongPressEnd(event.position);
    }
  }

  void _forwardLongPressMoveUpdate(Offset globalPosition) {
    final callback = widget.onLongPressMoveUpdate;
    if (callback == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;
    final localPosition = renderBox.globalToLocal(globalPosition);
    final originGlobal = _pointerOriginGlobal ?? globalPosition;
    final originLocal = _pointerOriginLocal ?? localPosition;
    callback(
      LongPressMoveUpdateDetails(
        globalPosition: globalPosition,
        localPosition: localPosition,
        offsetFromOrigin: globalPosition - originGlobal,
        localOffsetFromOrigin: localPosition - originLocal,
      ),
    );
  }

  void _forwardLongPressEnd(Offset globalPosition) {
    final callback = widget.onLongPressEnd;
    _detachTrackedPointerRoute();
    final renderBox = context.findRenderObject() as RenderBox?;
    final localPosition = renderBox == null || !renderBox.attached
        ? (_pointerOriginLocal ?? Offset.zero)
        : renderBox.globalToLocal(globalPosition);
    _clearTrackedPointer();
    if (mounted) {
      setState(() => _pressed = false);
    }
    if (callback == null) return;
    callback(
      LongPressEndDetails(
        globalPosition: globalPosition,
        localPosition: localPosition,
        velocity: Velocity.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        onTapDown: widget.onPressed == null
            ? null
            : (_) {
                _suppressTapForCurrentGesture = false;
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _pressed = true);
              },
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.onPressed == null
            ? null
            : (_) {
                setState(() => _pressed = false);
                if (_suppressTapForCurrentGesture) {
                  return;
                }
                widget.onPressed?.call();
              },
        onLongPressStart: widget.onLongPressStart == null
            ? null
            : (details) {
                _suppressTapForCurrentGesture = true;
                _pointerOriginGlobal ??= details.globalPosition;
                _pointerOriginLocal ??= details.localPosition;
                _attachTrackedPointerRoute();
                setState(() => _pressed = false);
                if (widget.hapticsEnabled) {
                  HapticFeedback.mediumImpact();
                }
                unawaited(widget.onLongPressStart!.call(details));
              },
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: MemoFlowPalette.primary,
              shape: BoxShape.circle,
              border: Border.all(color: bg, width: widget.borderWidth),
              boxShadow: [
                BoxShadow(
                  blurRadius: widget.size * 0.375,
                  offset: Offset(0, widget.size * 0.15625),
                  color: MemoFlowPalette.primary.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.2
                        : 0.3,
                  ),
                ),
              ],
            ),
            child: Icon(Icons.add, size: widget.iconSize, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class BackToTopButton extends StatefulWidget {
  const BackToTopButton({
    super.key,
    required this.visible,
    required this.hapticsEnabled,
    required this.onPressed,
  });

  final bool visible;
  final bool hapticsEnabled;
  final VoidCallback onPressed;

  @override
  State<BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<BackToTopButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = MemoFlowPalette.primary;
    final iconColor = Colors.white;
    final scale = widget.visible ? (_pressed ? 0.92 : 1.0) : 0.85;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Semantics(
            button: true,
            label: context.t.strings.legacy.msg_back_top,
            child: GestureDetector(
              onTapDown: (_) {
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _pressed = true);
              },
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) {
                setState(() => _pressed = false);
                widget.onPressed();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      color: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.35 : 0.25,
                      ),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 26,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
