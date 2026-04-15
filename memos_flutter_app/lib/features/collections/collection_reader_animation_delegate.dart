import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import 'collection_reader_no_anim_delegate.dart';
import 'collection_reader_simulation_delegate.dart';
import 'collection_reader_slide_delegate.dart';

enum ReaderPageTurnDirection { previous, next, none }

enum CollectionReaderTapRegion { left, center, right }

enum CollectionReaderTapCell {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleCenter,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class CollectionReaderDragPreview {
  const CollectionReaderDragPreview({
    required this.direction,
    required this.progress,
  });

  final ReaderPageTurnDirection direction;
  final double progress;
}

enum CollectionReaderDragEndAction { none, cancel, previous, next }

class CollectionReaderDragEndDecision {
  const CollectionReaderDragEndDecision({
    required this.action,
    this.targetProgress = 0,
  });

  const CollectionReaderDragEndDecision.none()
    : action = CollectionReaderDragEndAction.none,
      targetProgress = 0;

  final CollectionReaderDragEndAction action;
  final double targetProgress;
}

abstract class CollectionReaderAnimationDelegate {
  const CollectionReaderAnimationDelegate();

  Duration get duration;
  bool get supportsInteractivePreview => false;

  CollectionReaderTapRegion resolveTapRegion({
    required TapUpDetails details,
    required Size size,
  }) {
    final left = size.width / 3;
    final right = size.width * 2 / 3;
    final dx = details.localPosition.dx;
    if (dx < left) {
      return CollectionReaderTapRegion.left;
    }
    if (dx > right) {
      return CollectionReaderTapRegion.right;
    }
    return CollectionReaderTapRegion.center;
  }

  CollectionReaderTapCell resolveTapCell({
    required TapUpDetails details,
    required Size size,
  }) {
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;
    final column = details.localPosition.dx < thirdWidth
        ? 0
        : details.localPosition.dx > thirdWidth * 2
        ? 2
        : 1;
    final row = details.localPosition.dy < thirdHeight
        ? 0
        : details.localPosition.dy > thirdHeight * 2
        ? 2
        : 1;
    return switch ((row, column)) {
      (0, 0) => CollectionReaderTapCell.topLeft,
      (0, 1) => CollectionReaderTapCell.topCenter,
      (0, 2) => CollectionReaderTapCell.topRight,
      (1, 0) => CollectionReaderTapCell.middleLeft,
      (1, 1) => CollectionReaderTapCell.middleCenter,
      (1, 2) => CollectionReaderTapCell.middleRight,
      (2, 0) => CollectionReaderTapCell.bottomLeft,
      (2, 1) => CollectionReaderTapCell.bottomCenter,
      (2, 2) => CollectionReaderTapCell.bottomRight,
      _ => CollectionReaderTapCell.middleCenter,
    };
  }

  CollectionReaderTapAction resolveTapAction({
    required TapUpDetails details,
    required Size size,
    required CollectionReaderTapRegionConfig tapRegionConfig,
  }) {
    return switch (resolveTapCell(details: details, size: size)) {
      CollectionReaderTapCell.topLeft => tapRegionConfig.topLeft,
      CollectionReaderTapCell.topCenter => tapRegionConfig.topCenter,
      CollectionReaderTapCell.topRight => tapRegionConfig.topRight,
      CollectionReaderTapCell.middleLeft => tapRegionConfig.middleLeft,
      CollectionReaderTapCell.middleCenter => tapRegionConfig.middleCenter,
      CollectionReaderTapCell.middleRight => tapRegionConfig.middleRight,
      CollectionReaderTapCell.bottomLeft => tapRegionConfig.bottomLeft,
      CollectionReaderTapCell.bottomCenter => tapRegionConfig.bottomCenter,
      CollectionReaderTapCell.bottomRight => tapRegionConfig.bottomRight,
    };
  }

  void onTapRegion({
    required TapUpDetails details,
    required Size size,
    required CollectionReaderTapRegionConfig tapRegionConfig,
    required VoidCallback onCenterTap,
    required VoidCallback goPrevPage,
    required VoidCallback goNextPage,
    required VoidCallback goPrevChapter,
    required VoidCallback goNextChapter,
    required VoidCallback showToc,
    required VoidCallback showSearch,
  }) {
    switch (
      resolveTapAction(
        details: details,
        size: size,
        tapRegionConfig: tapRegionConfig,
      )
    ) {
      case CollectionReaderTapAction.none:
        return;
      case CollectionReaderTapAction.menu:
        onCenterTap();
      case CollectionReaderTapAction.nextPage:
        this.goNextPage(goNextPage);
      case CollectionReaderTapAction.prevPage:
        this.goPrevPage(goPrevPage);
      case CollectionReaderTapAction.nextChapter:
        goNextChapter();
      case CollectionReaderTapAction.prevChapter:
        goPrevChapter();
      case CollectionReaderTapAction.toc:
        showToc();
      case CollectionReaderTapAction.search:
        showSearch();
    }
  }

  void onDragStart({
    required DragStartDetails details,
    required VoidCallback onUserInteraction,
  }) {
    onUserInteraction();
  }

  void onDragUpdate({
    required DragUpdateDetails details,
    required VoidCallback onUserInteraction,
  }) {}

  void onDragEnd({
    required DragEndDetails details,
    required VoidCallback onUserInteraction,
    required VoidCallback goPrevPage,
    required VoidCallback goNextPage,
  }) {
    onUserInteraction();
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) {
      return;
    }
    if (velocity > 0) {
      this.goPrevPage(goPrevPage);
      return;
    }
    this.goNextPage(goNextPage);
  }

  void goPrevPage(VoidCallback action) => action();

  void goNextPage(VoidCallback action) => action();

  CollectionReaderDragPreview? resolveInteractivePreview({
    required Offset startPosition,
    required Offset currentPosition,
    required Size size,
    required bool canGoPrevious,
    required bool canGoNext,
  }) {
    return null;
  }

  CollectionReaderDragEndDecision resolveInteractivePreviewEnd({
    required CollectionReaderDragPreview? preview,
    required Velocity velocity,
    required Size size,
    required bool canGoPrevious,
    required bool canGoNext,
  }) {
    return const CollectionReaderDragEndDecision.none();
  }

  Widget paintTransition({
    required Animation<double> animation,
    required Widget child,
    required ReaderPageTurnDirection direction,
  });

  Widget? paintOverlayTransition({
    required Animation<double> animation,
    required ui.Image? snapshot,
    required ReaderPageTurnDirection direction,
  }) {
    return null;
  }
}

bool isCollectionReaderSimulationSupported({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  final effectivePlatform = platform ?? defaultTargetPlatform;
  return !isWeb &&
      (effectivePlatform == TargetPlatform.android ||
          effectivePlatform == TargetPlatform.iOS);
}

CollectionReaderPageAnimation resolveEffectiveCollectionReaderPageAnimation(
  CollectionReaderPageAnimation animation, {
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  if (animation != CollectionReaderPageAnimation.simulation) {
    return animation;
  }
  return isCollectionReaderSimulationSupported(isWeb: isWeb, platform: platform)
      ? CollectionReaderPageAnimation.simulation
      : CollectionReaderPageAnimation.slide;
}

CollectionReaderAnimationDelegate resolveCollectionReaderAnimationDelegate(
  CollectionReaderPageAnimation animation, {
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  return switch (resolveEffectiveCollectionReaderPageAnimation(
    animation,
    isWeb: isWeb,
    platform: platform,
  )) {
    CollectionReaderPageAnimation.none => const NoAnimDelegate(),
    CollectionReaderPageAnimation.slide => const SlideDelegate(),
    CollectionReaderPageAnimation.simulation => const SimulationDelegate(),
  };
}
