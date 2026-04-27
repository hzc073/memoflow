import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowResizeFrame extends StatefulWidget {
  const DesktopWindowResizeFrame({
    super.key,
    required this.child,
    this.enableResizeEdges,
  });

  final Widget child;
  final List<ResizeEdge>? enableResizeEdges;

  @override
  State<DesktopWindowResizeFrame> createState() =>
      _DesktopWindowResizeFrameState();
}

class _DesktopWindowResizeFrameState extends State<DesktopWindowResizeFrame>
    with WindowListener {
  bool _isMaximized = false;
  bool _isFullScreen = false;

  static const List<ResizeEdge> _allResizeEdges = <ResizeEdge>[
    ResizeEdge.topLeft,
    ResizeEdge.top,
    ResizeEdge.topRight,
    ResizeEdge.left,
    ResizeEdge.right,
    ResizeEdge.bottomLeft,
    ResizeEdge.bottom,
    ResizeEdge.bottomRight,
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncWindowState());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncWindowState() async {
    if (kIsWeb) return;
    try {
      final maximized = await windowManager.isMaximized();
      final fullScreen = await windowManager.isFullScreen();
      if (!mounted) return;
      setState(() {
        _isMaximized = maximized;
        _isFullScreen = fullScreen;
      });
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (!mounted) return;
    setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) return;
    setState(() => _isFullScreen = false);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedResizeEdges = widget.enableResizeEdges ?? _allResizeEdges;
    final enableResizeEdges = (_isMaximized || _isFullScreen)
        ? const <ResizeEdge>[]
        : resolvedResizeEdges;
    return DragToResizeArea(
      enableResizeEdges: enableResizeEdges,
      child: widget.child,
    );
  }
}
