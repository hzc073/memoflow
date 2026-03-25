import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class PointerDoubleTapListener extends StatefulWidget {
  const PointerDoubleTapListener({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.behavior = HitTestBehavior.deferToChild,
    this.timeout = kDoubleTapTimeout,
    this.slop = kDoubleTapSlop,
  });

  final Widget child;
  final VoidCallback? onDoubleTap;
  final HitTestBehavior behavior;
  final Duration timeout;
  final double slop;

  @override
  State<PointerDoubleTapListener> createState() =>
      _PointerDoubleTapListenerState();
}

class _PointerDoubleTapListenerState extends State<PointerDoubleTapListener> {
  Duration? _lastPointerDownTimeStamp;
  Offset? _lastPointerDownPosition;

  void _handlePointerDown(PointerDownEvent event) {
    final onDoubleTap = widget.onDoubleTap;
    if (onDoubleTap == null) return;
    if ((event.buttons & kPrimaryButton) == 0) return;

    final lastTimeStamp = _lastPointerDownTimeStamp;
    final lastPosition = _lastPointerDownPosition;
    final currentTimeStamp = event.timeStamp;
    final currentPosition = event.position;

    if (lastTimeStamp != null && lastPosition != null) {
      final elapsed = currentTimeStamp - lastTimeStamp;
      final distance = (currentPosition - lastPosition).distance;
      if (elapsed <= widget.timeout && distance <= widget.slop) {
        _lastPointerDownTimeStamp = null;
        _lastPointerDownPosition = null;
        onDoubleTap();
        return;
      }
    }

    _lastPointerDownTimeStamp = currentTimeStamp;
    _lastPointerDownPosition = currentPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: widget.onDoubleTap == null ? null : _handlePointerDown,
      child: widget.child,
    );
  }
}
