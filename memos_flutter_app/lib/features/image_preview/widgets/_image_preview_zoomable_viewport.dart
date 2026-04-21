import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum ImagePreviewPageDirection { previous, next }

class ImagePreviewZoomableViewport extends StatefulWidget {
  const ImagePreviewZoomableViewport({
    super.key,
    required this.child,
    required this.minScale,
    required this.maxScale,
    required this.enableWheelZoom,
    this.onZoomChanged,
    this.onEdgePageRequest,
    this.onReset,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final bool enableWheelZoom;
  final ValueChanged<bool>? onZoomChanged;
  final ValueChanged<ImagePreviewPageDirection>? onEdgePageRequest;
  final VoidCallback? onReset;

  @override
  State<ImagePreviewZoomableViewport> createState() =>
      _ImagePreviewZoomableViewportState();
}

class _ImagePreviewZoomableViewportState
    extends State<ImagePreviewZoomableViewport> {
  static const double _zoomEpsilon = 0.001;
  static const double _edgeEpsilon = 1;
  static const double _edgeSwipeThreshold = 32;

  late final TransformationController _transformationController;
  Size _viewportSize = Size.zero;
  bool _isZoomed = false;
  double _edgeSwipeProgress = 0;
  ImagePreviewPageDirection? _edgeSwipeDirection;
  bool _edgePageTriggered = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    final wasZoomed = _isZoomed;
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    if (wasZoomed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onZoomChanged?.call(false);
      });
    }
    super.dispose();
  }

  void _handleTransformChanged() {
    final isZoomed =
        _transformationController.value.getMaxScaleOnAxis() >
        widget.minScale + _zoomEpsilon;
    if (_isZoomed == isZoomed) {
      return;
    }
    _isZoomed = isZoomed;
    if (!_isZoomed) {
      _resetEdgeSwipeTracking();
    }
    widget.onZoomChanged?.call(isZoomed);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.enableWheelZoom || event is! PointerScrollEvent) {
      return;
    }

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final scaleDelta = math.exp(-event.scrollDelta.dy / 240);
    final nextScale = (currentScale * scaleDelta).clamp(
      widget.minScale,
      widget.maxScale,
    );
    if ((nextScale - currentScale).abs() < 0.001) {
      return;
    }

    final scenePoint = _transformationController.toScene(event.localPosition);
    _transformationController.value =
        Matrix4.translationValues(
            event.localPosition.dx,
            event.localPosition.dy,
            0,
          )
          ..multiply(Matrix4.diagonal3Values(nextScale, nextScale, 1))
          ..multiply(
            Matrix4.translationValues(-scenePoint.dx, -scenePoint.dy, 0),
          );
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _resetEdgeSwipeTracking();
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    if (widget.enableWheelZoom ||
        widget.onEdgePageRequest == null ||
        !_isZoomed) {
      _resetEdgeSwipeTracking();
      return;
    }
    if (details.pointerCount != 1 || details.scale != 1) {
      _resetEdgeSwipeTracking();
      return;
    }

    final dragDelta = details.focalPointDelta;
    if (dragDelta.dx == 0 || dragDelta.dx.abs() <= dragDelta.dy.abs()) {
      _resetEdgeSwipeTracking();
      return;
    }

    final direction = dragDelta.dx > 0
        ? ImagePreviewPageDirection.previous
        : ImagePreviewPageDirection.next;
    if (!_isAtHorizontalBoundary(direction)) {
      _resetEdgeSwipeTracking();
      return;
    }

    if (_edgeSwipeDirection != direction) {
      _edgeSwipeDirection = direction;
      _edgeSwipeProgress = 0;
    }

    _edgeSwipeProgress += dragDelta.dx;
    if (_edgePageTriggered) {
      return;
    }

    final thresholdReached = switch (direction) {
      ImagePreviewPageDirection.previous =>
        _edgeSwipeProgress >= _edgeSwipeThreshold,
      ImagePreviewPageDirection.next =>
        _edgeSwipeProgress <= -_edgeSwipeThreshold,
    };
    if (!thresholdReached) {
      return;
    }

    _edgePageTriggered = true;
    widget.onEdgePageRequest?.call(direction);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    _resetEdgeSwipeTracking();
  }

  bool _isAtHorizontalBoundary(ImagePreviewPageDirection direction) {
    if (_viewportSize.width <= 0) {
      return false;
    }
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale <= widget.minScale + _zoomEpsilon) {
      return false;
    }

    final translationX = _transformationController.value.storage[12];
    final minTranslationX = _viewportSize.width - (_viewportSize.width * scale);
    return switch (direction) {
      ImagePreviewPageDirection.previous => translationX >= -_edgeEpsilon,
      ImagePreviewPageDirection.next =>
        translationX <= minTranslationX + _edgeEpsilon,
    };
  }

  void _resetEdgeSwipeTracking() {
    _edgeSwipeProgress = 0;
    _edgeSwipeDirection = null;
    _edgePageTriggered = false;
  }

  void _resetTransform() {
    _transformationController.value = Matrix4.identity();
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        _viewportSize = Size(
          constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : mediaSize.width,
          constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : mediaSize.height,
        );

        final viewer = InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          onInteractionStart: _handleInteractionStart,
          onInteractionUpdate: _handleInteractionUpdate,
          onInteractionEnd: _handleInteractionEnd,
          trackpadScrollCausesScale: widget.enableWheelZoom,
          child: widget.child,
        );

        final resettableViewer = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: _resetTransform,
          child: viewer,
        );

        if (!widget.enableWheelZoom) {
          return resettableViewer;
        }
        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: resettableViewer,
        );
      },
    );
  }
}
