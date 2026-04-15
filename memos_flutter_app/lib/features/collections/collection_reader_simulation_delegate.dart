import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'collection_reader_animation_delegate.dart';

class SimulationDelegate extends CollectionReaderAnimationDelegate {
  const SimulationDelegate();

  @override
  Duration get duration => const Duration(milliseconds: 420);

  @override
  bool get supportsInteractivePreview => true;

  @override
  CollectionReaderDragPreview? resolveInteractivePreview({
    required Offset startPosition,
    required Offset currentPosition,
    required Size size,
    required bool canGoPrevious,
    required bool canGoNext,
  }) {
    if (size.width <= 0) {
      return null;
    }
    final deltaX = currentPosition.dx - startPosition.dx;
    if (deltaX.abs() < 6) {
      return null;
    }
    if (deltaX > 0) {
      if (!canGoPrevious) {
        return null;
      }
      return CollectionReaderDragPreview(
        direction: ReaderPageTurnDirection.previous,
        progress: (deltaX / size.width).clamp(0.0, 1.0).toDouble(),
      );
    }
    if (!canGoNext) {
      return null;
    }
    return CollectionReaderDragPreview(
      direction: ReaderPageTurnDirection.next,
      progress: ((-deltaX) / size.width).clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  CollectionReaderDragEndDecision resolveInteractivePreviewEnd({
    required CollectionReaderDragPreview? preview,
    required Velocity velocity,
    required Size size,
    required bool canGoPrevious,
    required bool canGoNext,
  }) {
    if (preview == null || preview.direction == ReaderPageTurnDirection.none) {
      return const CollectionReaderDragEndDecision.none();
    }
    final velocityX = velocity.pixelsPerSecond.dx;
    final commitByVelocity = switch (preview.direction) {
      ReaderPageTurnDirection.previous => velocityX > 420,
      ReaderPageTurnDirection.next => velocityX < -420,
      ReaderPageTurnDirection.none => false,
    };
    final commitByProgress = preview.progress >= 0.22;
    final canCommit = switch (preview.direction) {
      ReaderPageTurnDirection.previous => canGoPrevious,
      ReaderPageTurnDirection.next => canGoNext,
      ReaderPageTurnDirection.none => false,
    };
    if (canCommit && (commitByVelocity || commitByProgress)) {
      return CollectionReaderDragEndDecision(
        action: preview.direction == ReaderPageTurnDirection.previous
            ? CollectionReaderDragEndAction.previous
            : CollectionReaderDragEndAction.next,
        targetProgress: 1,
      );
    }
    return const CollectionReaderDragEndDecision(
      action: CollectionReaderDragEndAction.cancel,
      targetProgress: 0,
    );
  }

  @override
  Widget paintTransition({
    required Animation<double> animation,
    required Widget child,
    required ReaderPageTurnDirection direction,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: child,
    );
  }

  @override
  Widget? paintOverlayTransition({
    required Animation<double> animation,
    required ui.Image? snapshot,
    required ReaderPageTurnDirection direction,
  }) {
    if (snapshot == null || direction == ReaderPageTurnDirection.none) {
      return null;
    }
    return CustomPaint(
      painter: _SimulationSnapshotPainter(
        progress: animation.value,
        snapshot: snapshot,
        direction: direction,
      ),
      size: Size.infinite,
    );
  }
}

class _SimulationSnapshotPainter extends CustomPainter {
  const _SimulationSnapshotPainter({
    required this.progress,
    required this.snapshot,
    required this.direction,
  });

  final double progress;
  final ui.Image snapshot;
  final ReaderPageTurnDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || direction == ReaderPageTurnDirection.none) {
      return;
    }
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final destination = Offset.zero & size;
    final source = Rect.fromLTWH(
      0,
      0,
      snapshot.width.toDouble(),
      snapshot.height.toDouble(),
    );
    final imagePaint = Paint()..isAntiAlias = true;
    final foldWidth = math.min(size.width * 0.22, 72.0);

    if (direction == ReaderPageTurnDirection.next) {
      final leadingWidth =
          (size.width * (1 - eased)).clamp(0.0, size.width).toDouble();
      if (leadingWidth > 0) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, leadingWidth, size.height));
        canvas.drawImageRect(snapshot, source, destination, imagePaint);
        canvas.restore();
      }

      if (leadingWidth < size.width) {
        final sheetWidth =
            math.min(foldWidth, size.width - leadingWidth).toDouble();
        final stripSourceWidth =
            snapshot.width * (sheetWidth / math.max(size.width, 1));
        final stripSourceLeft = (snapshot.width - stripSourceWidth)
            .clamp(0, snapshot.width.toDouble())
            .toDouble();
        final stripSource = Rect.fromLTWH(
          stripSourceLeft,
          0,
          math.max(1.0, stripSourceWidth),
          snapshot.height.toDouble(),
        );
        final sheetRect = Rect.fromLTWH(
          leadingWidth,
          0,
          math.max(1.0, sheetWidth),
          size.height,
        );
        _drawFoldedSheet(
          canvas,
          source: stripSource,
          target: sheetRect,
          snapshot: snapshot,
          shadowTowardsLeft: false,
        );
      }
    } else {
      final trailingStart =
          (size.width * eased).clamp(0.0, size.width).toDouble();
      if (trailingStart < size.width) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(trailingStart, 0, size.width - trailingStart, size.height),
        );
        canvas.drawImageRect(snapshot, source, destination, imagePaint);
        canvas.restore();
      }

      if (trailingStart > 0) {
        final sheetWidth = math.min(foldWidth, trailingStart).toDouble();
        final stripSourceWidth =
            snapshot.width * (sheetWidth / math.max(size.width, 1));
        final stripSource = Rect.fromLTWH(
          0,
          0,
          math.max(1.0, stripSourceWidth),
          snapshot.height.toDouble(),
        );
        final sheetRect = Rect.fromLTWH(
          trailingStart - sheetWidth,
          0,
          math.max(1.0, sheetWidth),
          size.height,
        );
        _drawFoldedSheet(
          canvas,
          source: stripSource,
          target: sheetRect,
          snapshot: snapshot,
          shadowTowardsLeft: true,
        );
      }
    }
  }

  void _drawFoldedSheet(
    Canvas canvas, {
    required Rect source,
    required Rect target,
    required ui.Image snapshot,
    required bool shadowTowardsLeft,
  }) {
    final foldPaint = Paint()..isAntiAlias = true;
    final gradient = LinearGradient(
      begin: shadowTowardsLeft ? Alignment.centerRight : Alignment.centerLeft,
      end: shadowTowardsLeft ? Alignment.centerLeft : Alignment.centerRight,
      colors: <Color>[
        Colors.white.withValues(alpha: 0.08),
        Colors.black.withValues(alpha: 0.18),
      ],
    );
    final shadowPaint = Paint()
      ..shader = gradient.createShader(target)
      ..blendMode = BlendMode.srcOver;

    canvas.save();
    if (shadowTowardsLeft) {
      canvas.translate(target.right, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(
        snapshot,
        source,
        Rect.fromLTWH(0, 0, target.width, target.height),
        foldPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, target.width, target.height),
        shadowPaint,
      );
    } else {
      canvas.translate(target.left + target.width, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(
        snapshot,
        source,
        Rect.fromLTWH(0, 0, target.width, target.height),
        foldPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, target.width, target.height),
        shadowPaint,
      );
    }
    canvas.restore();

    final edgeRect = shadowTowardsLeft
        ? Rect.fromLTWH(target.right - 10, 0, 10, target.height)
        : Rect.fromLTWH(target.left, 0, 10, target.height);
    final edgeGradient = LinearGradient(
      begin: shadowTowardsLeft ? Alignment.centerRight : Alignment.centerLeft,
      end: shadowTowardsLeft ? Alignment.centerLeft : Alignment.centerRight,
      colors: <Color>[
        Colors.black.withValues(alpha: 0.24),
        Colors.transparent,
      ],
    );
    canvas.drawRect(
      edgeRect,
      Paint()..shader = edgeGradient.createShader(edgeRect),
    );
  }

  @override
  bool shouldRepaint(covariant _SimulationSnapshotPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.snapshot != snapshot ||
        oldDelegate.direction != direction;
  }
}
