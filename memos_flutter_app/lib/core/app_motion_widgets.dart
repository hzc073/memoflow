import 'package:flutter/material.dart';

import 'app_motion.dart';

class AppSharedAxisSwitcher extends StatelessWidget {
  const AppSharedAxisSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.desktopContent,
    this.reverseDuration,
    this.axis = Axis.vertical,
    this.offset = 0.02,
    this.scaleBegin = AppMotion.entryScaleBegin,
    this.switchInCurve = AppMotion.emphasizedEnterCurve,
    this.switchOutCurve = AppMotion.emphasizedExitCurve,
    this.layoutBuilder,
    this.animateSize = false,
    this.sizeAlignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Axis axis;
  final double offset;
  final double scaleBegin;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final AnimatedSwitcherLayoutBuilder? layoutBuilder;
  final bool animateSize;
  final AlignmentGeometry sizeAlignment;

  @override
  Widget build(BuildContext context) {
    final resolvedDuration = AppMotion.effectiveDuration(context, duration);
    final resolvedReverseDuration = AppMotion.effectiveDuration(
      context,
      reverseDuration ?? duration,
    );

    Widget switcher = AnimatedSwitcher(
      duration: resolvedDuration,
      reverseDuration: resolvedReverseDuration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: layoutBuilder ?? AnimatedSwitcher.defaultLayoutBuilder,
      transitionBuilder: (child, animation) {
        if (resolvedDuration == Duration.zero &&
            resolvedReverseDuration == Duration.zero) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: switchInCurve,
          reverseCurve: switchOutCurve,
        );
        final beginOffset = axis == Axis.horizontal
            ? Offset(offset, 0)
            : Offset(0, offset);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: scaleBegin, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );

    if (!animateSize) {
      return switcher;
    }

    return AnimatedSize(
      duration: resolvedDuration,
      reverseDuration: resolvedReverseDuration,
      curve: switchInCurve,
      alignment: sizeAlignment,
      child: switcher,
    );
  }
}

class AppPressScale extends StatefulWidget {
  const AppPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scaleDown = 0.97,
    this.alignment = Alignment.center,
    this.pressedDuration = AppMotion.desktopPressDown,
    this.releasedDuration = AppMotion.desktopPressUp,
  });

  final Widget child;
  final bool enabled;
  final double scaleDown;
  final Alignment alignment;
  final Duration pressedDuration;
  final Duration releasedDuration;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.effectiveDuration(
      context,
      _pressed ? widget.pressedDuration : widget.releasedDuration,
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1,
        duration: duration,
        alignment: widget.alignment,
        curve: _pressed
            ? AppMotion.standardCurve
            : AppMotion.emphasizedEnterCurve,
        child: widget.child,
      ),
    );
  }
}
