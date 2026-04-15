import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/image_error_logger.dart';
import '../../core/image_formats.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import '../../state/system/session_provider.dart';
import '../memos/attachment_gallery_screen.dart';
import '../memos/attachment_video_screen.dart';
import '../memos/memo_image_grid.dart';
import '../memos/memo_video_grid.dart';
import 'collection_reader_animation_delegate.dart';
import 'collection_reader_page_models.dart';
import 'collection_reader_simulation_delegate.dart';
import 'reader_tip_builder.dart';

class CollectionReaderPagedView extends StatefulWidget {
  const CollectionReaderPagedView({
    super.key,
    required this.currentPage,
    required this.previousPage,
    required this.nextPage,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.preferences,
    required this.turnDirection,
    required this.highlightQuery,
    required this.highlightMemoUid,
    required this.collectionTitle,
    required this.currentGlobalPageIndex,
    required this.totalPages,
    required this.previewImageOnTap,
    required this.onShowSearch,
    required this.onShowToc,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onCenterTap,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onUserInteraction,
  });

  final ReaderPage? currentPage;
  final ReaderPage? previousPage;
  final ReaderPage? nextPage;
  final bool canGoPrevious;
  final bool canGoNext;
  final CollectionReaderPreferences preferences;
  final ReaderPageTurnDirection turnDirection;
  final String? highlightQuery;
  final String? highlightMemoUid;
  final String collectionTitle;
  final int currentGlobalPageIndex;
  final int totalPages;
  final bool previewImageOnTap;
  final VoidCallback onShowSearch;
  final VoidCallback onShowToc;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onCenterTap;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onUserInteraction;

  @override
  State<CollectionReaderPagedView> createState() =>
      _CollectionReaderPagedViewState();
}

class _CollectionReaderPagedViewState extends State<CollectionReaderPagedView>
    with TickerProviderStateMixin {
  final GlobalKey _currentBoundaryKey = GlobalKey(
    debugLabel: 'collectionReaderPagedCurrentBoundary',
  );
  final GlobalKey _previousBoundaryKey = GlobalKey(
    debugLabel: 'collectionReaderPagedPreviousBoundary',
  );
  final GlobalKey _nextBoundaryKey = GlobalKey(
    debugLabel: 'collectionReaderPagedNextBoundary',
  );

  late final AnimationController _simulationController;
  late final AnimationController _previewController;
  ui.Image? _currentSnapshot;
  ui.Image? _previousSnapshot;
  ui.Image? _nextSnapshot;
  ui.Image? _transitionSnapshot;
  String? _currentSnapshotKey;
  String? _previousSnapshotKey;
  String? _nextSnapshotKey;
  bool _captureQueued = false;
  ReaderPageTurnDirection _simulationDirection = ReaderPageTurnDirection.none;
  Offset? _dragStartPosition;
  ReaderPageTurnDirection _previewDirection = ReaderPageTurnDirection.none;
  bool _previewDragInProgress = false;
  bool _commitPreviewOnComplete = false;
  bool _skipNextTurnAnimation = false;

  @override
  void initState() {
    super.initState();
    _previewController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addStatusListener((status) {
          if (!mounted) {
            return;
          }
          if (status == AnimationStatus.completed && _commitPreviewOnComplete) {
            final direction = _previewDirection;
            _commitPreviewOnComplete = false;
            _skipNextTurnAnimation = true;
            _previewDragInProgress = false;
            _dragStartPosition = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              if (direction == ReaderPageTurnDirection.previous) {
                widget.onPrevPage();
              } else if (direction == ReaderPageTurnDirection.next) {
                widget.onNextPage();
              }
            });
            return;
          }
          if (status == AnimationStatus.dismissed &&
              !_previewDragInProgress &&
              !_commitPreviewOnComplete &&
              _previewDirection != ReaderPageTurnDirection.none) {
            _resetPreview();
          }
        });
    _simulationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed ||
              status == AnimationStatus.dismissed) {
            _disposeImage(_transitionSnapshot);
            _transitionSnapshot = null;
            if (mounted) {
              setState(() {});
            }
          }
        });
  }

  @override
  void didUpdateWidget(covariant CollectionReaderPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPage = _resolvePage(oldWidget);
    final newPage = _resolvePage(widget);
    if (oldWidget.preferences != widget.preferences ||
        oldWidget.highlightMemoUid != widget.highlightMemoUid ||
        oldWidget.highlightQuery != widget.highlightQuery) {
      _resetPreview(notify: false);
      _clearNeighborSnapshots();
    }
    if (oldPage?.cacheKey != newPage?.cacheKey) {
      final delegate = resolveCollectionReaderAnimationDelegate(
        widget.preferences.pageAnimation,
      );
      _inheritNeighborSnapshot(newPage);
      if (_skipNextTurnAnimation) {
        _skipNextTurnAnimation = false;
        _resetPreview(notify: false);
        _disposeImage(_transitionSnapshot);
        _transitionSnapshot = null;
        _simulationDirection = ReaderPageTurnDirection.none;
        _simulationController.stop();
      } else if (delegate is SimulationDelegate &&
          widget.turnDirection != ReaderPageTurnDirection.none &&
          _currentSnapshot != null) {
        _disposeImage(_transitionSnapshot);
        _transitionSnapshot = _currentSnapshot;
        _currentSnapshot = null;
        _simulationDirection = widget.turnDirection;
        _simulationController.forward(from: 0);
      } else {
        _disposeImage(_transitionSnapshot);
        _transitionSnapshot = null;
        _simulationDirection = ReaderPageTurnDirection.none;
        _simulationController.stop();
      }
    }
    _queueSnapshotCapture();
  }

  @override
  void dispose() {
    _previewController.dispose();
    _simulationController.dispose();
    _disposeImage(_currentSnapshot);
    _disposeImage(_previousSnapshot);
    _disposeImage(_nextSnapshot);
    _disposeImage(_transitionSnapshot);
    super.dispose();
  }

  ReaderPage? _resolvePage(CollectionReaderPagedView source) {
    return source.currentPage;
  }

  void _inheritNeighborSnapshot(ReaderPage? newPage) {
    if (newPage == null) {
      _disposeImage(_currentSnapshot);
      _currentSnapshot = null;
      _currentSnapshotKey = null;
      return;
    }
    if (_nextSnapshotKey == newPage.cacheKey) {
      _disposeImage(_currentSnapshot);
      _currentSnapshot = _nextSnapshot;
      _currentSnapshotKey = _nextSnapshotKey;
      _nextSnapshot = null;
      _nextSnapshotKey = null;
      return;
    }
    if (_previousSnapshotKey == newPage.cacheKey) {
      _disposeImage(_currentSnapshot);
      _currentSnapshot = _previousSnapshot;
      _currentSnapshotKey = _previousSnapshotKey;
      _previousSnapshot = null;
      _previousSnapshotKey = null;
      return;
    }
    if (_currentSnapshotKey != newPage.cacheKey) {
      _disposeImage(_currentSnapshot);
      _currentSnapshot = null;
      _currentSnapshotKey = null;
    }
  }

  void _clearNeighborSnapshots() {
    _disposeImage(_currentSnapshot);
    _disposeImage(_previousSnapshot);
    _disposeImage(_nextSnapshot);
    _currentSnapshot = null;
    _previousSnapshot = null;
    _nextSnapshot = null;
    _currentSnapshotKey = null;
    _previousSnapshotKey = null;
    _nextSnapshotKey = null;
  }

  bool get _canGoPrevious => widget.canGoPrevious;

  bool get _canGoNext => widget.canGoNext;

  bool get _isPreviewActive =>
      _previewDirection != ReaderPageTurnDirection.none &&
      (_previewDragInProgress ||
          _previewController.isAnimating ||
          _previewController.value > 0);

  void _resetPreview({bool notify = true}) {
    _previewDragInProgress = false;
    _commitPreviewOnComplete = false;
    _dragStartPosition = null;
    _previewDirection = ReaderPageTurnDirection.none;
    if (_previewController.isAnimating) {
      _previewController.stop();
    }
    if (_previewController.value != 0) {
      _previewController.value = 0;
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _queueSnapshotCapture() {
    if (_captureQueued) {
      return;
    }
    _captureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _captureQueued = false;
      if (!mounted) {
        return;
      }
      final page = _resolvePage(widget);
      if (page == null) {
        return;
      }
      final previousPage = widget.previousPage;
      final nextPage = widget.nextPage;
      final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 1.5);
      final currentCaptured = await _captureSnapshotFor(
        boundaryKey: _currentBoundaryKey,
        page: page,
        pixelRatio: pixelRatio,
      );
      final previousCaptured = await _captureSnapshotFor(
        boundaryKey: _previousBoundaryKey,
        page: previousPage,
        pixelRatio: pixelRatio,
      );
      final nextCaptured = await _captureSnapshotFor(
        boundaryKey: _nextBoundaryKey,
        page: nextPage,
        pixelRatio: pixelRatio,
      );
      if (!mounted) {
        _disposeImage(currentCaptured);
        _disposeImage(previousCaptured);
        _disposeImage(nextCaptured);
        return;
      }
      _replaceSnapshot(
        currentCaptured,
        page.cacheKey,
        assign: (image, key) {
          _currentSnapshot = image;
          _currentSnapshotKey = key;
        },
        current: _currentSnapshot,
        currentKey: _currentSnapshotKey,
      );
      _replaceSnapshot(
        previousCaptured,
        previousPage?.cacheKey,
        assign: (image, key) {
          _previousSnapshot = image;
          _previousSnapshotKey = key;
        },
        current: _previousSnapshot,
        currentKey: _previousSnapshotKey,
      );
      _replaceSnapshot(
        nextCaptured,
        nextPage?.cacheKey,
        assign: (image, key) {
          _nextSnapshot = image;
          _nextSnapshotKey = key;
        },
        current: _nextSnapshot,
        currentKey: _nextSnapshotKey,
      );
    });
  }

  Future<ui.Image?> _captureSnapshotFor({
    required GlobalKey boundaryKey,
    required ReaderPage? page,
    required double pixelRatio,
  }) async {
    if (page == null) {
      return null;
    }
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) {
      _queueSnapshotCapture();
      return null;
    }
    try {
      return await boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      return null;
    }
  }

  void _replaceSnapshot(
    ui.Image? image,
    String? key, {
    required void Function(ui.Image image, String key) assign,
    required ui.Image? current,
    required String? currentKey,
  }) {
    if (key == null) {
      _disposeImage(image);
      return;
    }
    if (image == null) {
      return;
    }
    if (currentKey == key) {
      _disposeImage(current);
      assign(image, key);
      return;
    }
    _disposeImage(current);
    assign(image, key);
  }

  void _disposeImage(ui.Image? image) {
    if (image == null) {
      return;
    }
    try {
      image.dispose();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final delegate = resolveCollectionReaderAnimationDelegate(
      widget.preferences.pageAnimation,
    );
    final viewportSize = MediaQuery.sizeOf(context);
    final page = widget.currentPage;
    final previousGlobalPageIndex = math.max(
      0,
      widget.currentGlobalPageIndex - 1,
    );
    final nextGlobalPageIndex = math.max(
      0,
      math.min(widget.totalPages - 1, widget.currentGlobalPageIndex + 1),
    );
    final livePage = RepaintBoundary(
      key: _currentBoundaryKey,
      child: page == null
          ? const SizedBox.expand(key: ValueKey<String>('empty'))
          : _ReaderPageSurface(
              key: ValueKey<String>(page.cacheKey),
              page: page,
              highlightQuery: widget.highlightMemoUid == page.memoUid
                  ? widget.highlightQuery
                  : null,
              preferences: widget.preferences,
              collectionTitle: widget.collectionTitle,
              globalPageIndex: widget.currentGlobalPageIndex,
              totalPages: widget.totalPages,
              previewImageOnTap: widget.previewImageOnTap,
            ),
    );
    _queueSnapshotCapture();
    final previewActive =
        delegate.supportsInteractivePreview && _isPreviewActive;
    final previewSnapshot = previewActive ? _currentSnapshot : null;
    final previewTargetPage = previewActive
        ? switch (_previewDirection) {
            ReaderPageTurnDirection.previous => widget.previousPage,
            ReaderPageTurnDirection.next => widget.nextPage,
            ReaderPageTurnDirection.none => null,
          }
        : null;
    final previewTargetGlobalPageIndex = switch (_previewDirection) {
      ReaderPageTurnDirection.previous => previousGlobalPageIndex,
      ReaderPageTurnDirection.next => nextGlobalPageIndex,
      ReaderPageTurnDirection.none => widget.currentGlobalPageIndex,
    };
    final pageBody = delegate is SimulationDelegate
        ? Stack(
            fit: StackFit.expand,
            children: [
              if (previewActive && previewTargetPage != null)
                _ReaderPageSurface(
                  key: ValueKey<String>(
                    'preview-${previewTargetPage.cacheKey}',
                  ),
                  page: previewTargetPage,
                  highlightQuery:
                      widget.highlightMemoUid == previewTargetPage.memoUid
                      ? widget.highlightQuery
                      : null,
                  preferences: widget.preferences,
                  collectionTitle: widget.collectionTitle,
                  globalPageIndex: previewTargetGlobalPageIndex,
                  totalPages: widget.totalPages,
                  previewImageOnTap: widget.previewImageOnTap,
                )
              else
                livePage,
              _OffstageSnapshotSurface(
                boundaryKey: _previousBoundaryKey,
                page: widget.previousPage,
                highlightQuery: null,
                preferences: widget.preferences,
                collectionTitle: widget.collectionTitle,
                globalPageIndex: previousGlobalPageIndex,
                totalPages: widget.totalPages,
              ),
              _OffstageSnapshotSurface(
                boundaryKey: _nextBoundaryKey,
                page: widget.nextPage,
                highlightQuery: null,
                preferences: widget.preferences,
                collectionTitle: widget.collectionTitle,
                globalPageIndex: nextGlobalPageIndex,
                totalPages: widget.totalPages,
              ),
              if (previewActive && previewSnapshot != null)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _previewController,
                    builder: (context, _) {
                      return delegate.paintOverlayTransition(
                        animation: _previewController,
                        snapshot: previewSnapshot,
                        direction: _previewDirection,
                      )!;
                    },
                  ),
                )
              else if (_transitionSnapshot != null)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _simulationController,
                    builder: (context, _) {
                      return delegate.paintOverlayTransition(
                        animation: _simulationController,
                        snapshot: _transitionSnapshot!,
                        direction: _simulationDirection,
                      )!;
                    },
                  ),
                ),
            ],
          )
        : AnimatedSwitcher(
            duration: delegate.duration,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) => delegate.paintTransition(
              animation: animation,
              child: child,
              direction: widget.turnDirection,
            ),
            child: KeyedSubtree(
              key: ValueKey<String>(page?.cacheKey ?? 'empty'),
              child: livePage,
            ),
          );
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent &&
            !(widget.preferences.inputConfig.longPressKeyPageTurn &&
                event is KeyRepeatEvent)) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final allowVolumeKeys =
            widget.preferences.inputConfig.volumeKeyPageTurn;
        if (allowVolumeKeys &&
            (key == LogicalKeyboardKey.audioVolumeDown ||
                key == LogicalKeyboardKey.audioVolumeUp)) {
          widget.onUserInteraction();
          if (key == LogicalKeyboardKey.audioVolumeUp) {
            widget.onPrevPage();
          } else {
            widget.onNextPage();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.pageUp ||
            key == LogicalKeyboardKey.arrowLeft) {
          widget.onUserInteraction();
          widget.onPrevPage();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.pageDown ||
            key == LogicalKeyboardKey.arrowRight) {
          widget.onUserInteraction();
          widget.onNextPage();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: (event) {
          if (!widget.preferences.inputConfig.mouseWheelPageTurn ||
              event is! PointerScrollEvent) {
            return;
          }
          widget.onUserInteraction();
          if (event.scrollDelta.dy > 0) {
            widget.onNextPage();
          } else if (event.scrollDelta.dy < 0) {
            widget.onPrevPage();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            delegate.onTapRegion(
              details: details,
              size: viewportSize,
              tapRegionConfig: widget.preferences.tapRegionConfig,
              onCenterTap: widget.onCenterTap,
              goPrevPage: widget.onPrevPage,
              goNextPage: widget.onNextPage,
              goPrevChapter: widget.onPrevChapter,
              goNextChapter: widget.onNextChapter,
              showToc: widget.onShowToc,
              showSearch: widget.onShowSearch,
            );
          },
          onHorizontalDragStart: (details) {
            if (delegate.supportsInteractivePreview) {
              widget.onUserInteraction();
              _simulationController.stop();
              _disposeImage(_transitionSnapshot);
              _transitionSnapshot = null;
              _simulationDirection = ReaderPageTurnDirection.none;
              _previewDragInProgress = true;
              _commitPreviewOnComplete = false;
              _dragStartPosition = details.localPosition;
              if (_previewController.isAnimating) {
                _previewController.stop();
              }
              if (_previewController.value != 0) {
                _previewController.value = 0;
              }
              if (_previewDirection != ReaderPageTurnDirection.none) {
                setState(
                  () => _previewDirection = ReaderPageTurnDirection.none,
                );
              }
              return;
            }
            delegate.onDragStart(
              details: details,
              onUserInteraction: widget.onUserInteraction,
            );
          },
          onHorizontalDragUpdate: (details) {
            if (delegate.supportsInteractivePreview) {
              final startPosition = _dragStartPosition;
              if (startPosition == null) {
                return;
              }
              if ((details.localPosition.dx - startPosition.dx).abs() <
                  widget.preferences.inputConfig.pageTouchSlop) {
                return;
              }
              final preview = delegate.resolveInteractivePreview(
                startPosition: startPosition,
                currentPosition: details.localPosition,
                size: viewportSize,
                canGoPrevious: _canGoPrevious,
                canGoNext: _canGoNext,
              );
              if (preview == null ||
                  preview.direction == ReaderPageTurnDirection.none ||
                  preview.progress <= 0) {
                if (_previewDirection != ReaderPageTurnDirection.none ||
                    _previewController.value != 0) {
                  _previewDirection = ReaderPageTurnDirection.none;
                  _previewController.value = 0;
                  setState(() {});
                }
                return;
              }
              final clampedProgress = preview.progress
                  .clamp(0.0, 1.0)
                  .toDouble();
              final changed =
                  _previewDirection != preview.direction ||
                  (_previewController.value - clampedProgress).abs() > 0.001;
              _previewDirection = preview.direction;
              _previewController.value = clampedProgress;
              if (changed) {
                setState(() {});
              }
              return;
            }
            delegate.onDragUpdate(
              details: details,
              onUserInteraction: widget.onUserInteraction,
            );
          },
          onHorizontalDragEnd: (details) {
            if (delegate.supportsInteractivePreview) {
              _previewDragInProgress = false;
              final preview = _previewDirection == ReaderPageTurnDirection.none
                  ? null
                  : CollectionReaderDragPreview(
                      direction: _previewDirection,
                      progress: _previewController.value,
                    );
              final decision = delegate.resolveInteractivePreviewEnd(
                preview: preview,
                velocity: details.velocity,
                size: viewportSize,
                canGoPrevious: _canGoPrevious,
                canGoNext: _canGoNext,
              );
              switch (decision.action) {
                case CollectionReaderDragEndAction.previous:
                case CollectionReaderDragEndAction.next:
                  _commitPreviewOnComplete = true;
                  _previewController.duration = Duration(
                    milliseconds: math.max(
                      110,
                      (180 *
                              (decision.targetProgress -
                                      _previewController.value)
                                  .abs())
                          .round(),
                    ),
                  );
                  _previewController.animateTo(
                    decision.targetProgress,
                    curve: Curves.easeOutCubic,
                  );
                  break;
                case CollectionReaderDragEndAction.cancel:
                  _commitPreviewOnComplete = false;
                  _previewController.duration = Duration(
                    milliseconds: math.max(
                      90,
                      (160 * _previewController.value.abs()).round(),
                    ),
                  );
                  _previewController.animateBack(0, curve: Curves.easeOutCubic);
                  break;
                case CollectionReaderDragEndAction.none:
                  _resetPreview();
                  break;
              }
              return;
            }
            delegate.onDragEnd(
              details: details,
              onUserInteraction: widget.onUserInteraction,
              goPrevPage: widget.onPrevPage,
              goNextPage: widget.onNextPage,
            );
          },
          child: pageBody,
        ),
      ),
    );
  }
}

class _ReaderPageSurface extends StatelessWidget {
  const _ReaderPageSurface({
    super.key,
    required this.page,
    required this.highlightQuery,
    required this.preferences,
    required this.collectionTitle,
    required this.globalPageIndex,
    required this.totalPages,
    required this.previewImageOnTap,
  });

  final ReaderPage page;
  final String? highlightQuery;
  final CollectionReaderPreferences preferences;
  final String collectionTitle;
  final int globalPageIndex;
  final int totalPages;
  final bool previewImageOnTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 18 * preferences.textScale,
      height: preferences.lineSpacing,
      color: textColor,
      fontFamily: preferences.readerFontFamily,
      fontWeight: _readerFontWeight(preferences.fontWeightMode),
      letterSpacing: preferences.letterSpacing,
    );
    final headingStyle = bodyStyle?.copyWith(
      fontSize: 22 * preferences.textScale,
      height: 1.35,
      fontWeight: _readerHeadingWeight(preferences.fontWeightMode),
    );
    final quoteStyle = bodyStyle?.copyWith(
      fontSize: 17 * preferences.textScale,
      height: preferences.lineSpacing * 1.02,
      fontStyle: FontStyle.italic,
      color: textColor.withValues(alpha: 0.82),
    );
    final codeStyle = bodyStyle?.copyWith(
      fontSize: 15 * preferences.textScale,
      height: 1.5,
      fontFamily: 'monospace',
      color: textColor.withValues(alpha: 0.92),
    );
    final tableStyle = bodyStyle?.copyWith(
      fontSize: 14 * preferences.textScale,
      height: 1.5,
      fontFamily: 'monospace',
      color: textColor.withValues(alpha: 0.92),
    );
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13 * preferences.textScale,
      height: 1.4,
      color: textColor.withValues(alpha: 0.7),
      fontFamily: preferences.readerFontFamily,
      letterSpacing: preferences.letterSpacing,
    );
    final titlePrimaryStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: 20 * preferences.textScale * preferences.titleScale,
      height: 1.28,
      fontWeight: _readerHeadingWeight(preferences.fontWeightMode),
      color: textColor.withValues(alpha: 0.96),
      fontFamily: preferences.readerFontFamily,
      letterSpacing: preferences.letterSpacing,
    );
    final titleSecondaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13 * preferences.textScale,
      height: 1.35,
      color: textColor.withValues(alpha: 0.72),
      fontFamily: preferences.readerFontFamily,
      letterSpacing: preferences.letterSpacing,
    );
    final chapterTitle = page.title == null
        ? ''
        : (page.title!.subtitle.trim().isNotEmpty
              ? page.title!.subtitle
              : page.title!.title);
    final headerStrings = page.headerTip == null
        ? null
        : buildReaderTipStrings(
            page: page,
            tipLayout: preferences.tipLayout,
            collectionTitle: collectionTitle,
            chapterTitle: chapterTitle,
            globalPageIndex: globalPageIndex,
            totalPages: totalPages,
          );
    final footerStrings = page.footerTip == null
        ? null
        : buildReaderFooterTipStrings(
            page: page,
            tipLayout: preferences.tipLayout,
            collectionTitle: collectionTitle,
            chapterTitle: chapterTitle,
            globalPageIndex: globalPageIndex,
            totalPages: totalPages,
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.headerTip?.mode == CollectionReaderTipDisplayMode.inline &&
            headerStrings != null)
          _ReaderTipBar(
            strings: headerStrings,
            padding: preferences.headerPadding,
            textColor:
                preferences.tipLayout.tipColorOverride ??
                textColor.withValues(alpha: 0.72),
            dividerColor:
                preferences.tipLayout.tipDividerColorOverride ??
                textColor.withValues(alpha: 0.16),
            showDivider: preferences.showHeaderLine,
            textScale: preferences.textScale,
          ),
        if (page.isFirstPage &&
            page.title != null &&
            page.title!.mode != CollectionReaderTitleMode.hidden)
          Padding(
            padding: EdgeInsets.only(
              top: preferences.titleTopSpacing,
              bottom: preferences.titleBottomSpacing + 8,
            ),
            child: Column(
              crossAxisAlignment:
                  page.title!.mode == CollectionReaderTitleMode.center
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  page.title!.title,
                  textAlign:
                      page.title!.mode == CollectionReaderTitleMode.center
                      ? TextAlign.center
                      : TextAlign.start,
                  style: titlePrimaryStyle,
                ),
                if (page.title!.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    page.title!.subtitle,
                    textAlign:
                        page.title!.mode == CollectionReaderTitleMode.center
                        ? TextAlign.center
                        : TextAlign.start,
                    style: titleSecondaryStyle,
                  ),
                ],
              ],
            ),
          ),
        ...page.blocks.map(
          (block) => _buildBlock(
            context,
            block: block,
            bodyStyle: bodyStyle,
            headingStyle: headingStyle,
            quoteStyle: quoteStyle,
            codeStyle: codeStyle,
            tableStyle: tableStyle,
            metaStyle: metaStyle,
          ),
        ),
        if (page.footerTip?.mode == CollectionReaderTipDisplayMode.inline &&
            footerStrings != null)
          _ReaderTipBar(
            strings: footerStrings,
            padding: preferences.footerPadding,
            textColor:
                preferences.tipLayout.tipColorOverride ??
                textColor.withValues(alpha: 0.72),
            dividerColor:
                preferences.tipLayout.tipDividerColorOverride ??
                textColor.withValues(alpha: 0.16),
            showDivider: preferences.showFooterLine,
            textScale: preferences.textScale,
          ),
      ],
    );
    return ColoredBox(
      color: pageBackground,
      child: SizedBox.expand(
        child: Stack(
          children: [
            if (page.headerTip?.mode ==
                    CollectionReaderTipDisplayMode.reserved &&
                headerStrings != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ReaderTipBar(
                  strings: headerStrings,
                  padding: preferences.headerPadding,
                  textColor:
                      preferences.tipLayout.tipColorOverride ??
                      textColor.withValues(alpha: 0.72),
                  dividerColor:
                      preferences.tipLayout.tipDividerColorOverride ??
                      textColor.withValues(alpha: 0.16),
                  showDivider: preferences.showHeaderLine,
                  textScale: preferences.textScale,
                ),
              ),
            if (page.footerTip?.mode ==
                    CollectionReaderTipDisplayMode.reserved &&
                footerStrings != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ReaderTipBar(
                  strings: footerStrings,
                  padding: preferences.footerPadding,
                  textColor:
                      preferences.tipLayout.tipColorOverride ??
                      textColor.withValues(alpha: 0.72),
                  dividerColor:
                      preferences.tipLayout.tipDividerColorOverride ??
                      textColor.withValues(alpha: 0.16),
                  showDivider: preferences.showFooterLine,
                  textScale: preferences.textScale,
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  preferences.pagePadding.left,
                  preferences.pagePadding.top + page.reservedInsets.top,
                  preferences.pagePadding.right,
                  preferences.pagePadding.bottom + page.reservedInsets.bottom,
                ),
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: preferences.displayConfig.allowTextSelection
                        ? SelectionArea(child: content)
                        : content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(
    BuildContext context, {
    required ReaderPageBlock block,
    required TextStyle? bodyStyle,
    required TextStyle? headingStyle,
    required TextStyle? quoteStyle,
    required TextStyle? codeStyle,
    required TextStyle? tableStyle,
    required TextStyle? metaStyle,
  }) {
    return switch (block.kind) {
      ReaderBlockKind.metaHeader => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(block.text ?? '', style: metaStyle),
      ),
      ReaderBlockKind.location => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14 * preferences.textScale,
              color: metaStyle?.color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                block.locationLabel ?? block.text ?? '',
                style: metaStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      ReaderBlockKind.markdownText => Padding(
        padding: EdgeInsets.only(
          bottom: _readerBlockSpacing(preferences, block.textRole),
        ),
        child: DecoratedBox(
          decoration: switch (block.textRole) {
            ReaderTextRole.quote => BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.45),
                  width: 3,
                ),
              ),
            ),
            ReaderTextRole.code => BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(12),
            ),
            ReaderTextRole.tableRow => BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(10),
            ),
            ReaderTextRole.body ||
            ReaderTextRole.heading ||
            ReaderTextRole.listItem => const BoxDecoration(),
          },
          child: Padding(
            padding: switch (block.textRole) {
              ReaderTextRole.quote => const EdgeInsets.fromLTRB(12, 10, 12, 10),
              ReaderTextRole.code => const EdgeInsets.fromLTRB(12, 10, 12, 10),
              ReaderTextRole.tableRow => const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                8,
              ),
              ReaderTextRole.body ||
              ReaderTextRole.heading ||
              ReaderTextRole.listItem => EdgeInsets.only(
                left: block.textRole == ReaderTextRole.listItem ? 4 : 0,
              ),
            },
            child: Text.rich(
              _buildHighlightedSpan(
                text: block.text ?? '',
                query: highlightQuery,
                style: switch (block.textRole) {
                  ReaderTextRole.heading =>
                    headingStyle ?? bodyStyle ?? const TextStyle(),
                  ReaderTextRole.quote =>
                    quoteStyle ?? bodyStyle ?? const TextStyle(),
                  ReaderTextRole.code =>
                    codeStyle ?? bodyStyle ?? const TextStyle(),
                  ReaderTextRole.tableRow =>
                    tableStyle ?? bodyStyle ?? const TextStyle(),
                  ReaderTextRole.listItem ||
                  ReaderTextRole.body => bodyStyle ?? const TextStyle(),
                },
                highlightColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
      ),
      ReaderBlockKind.image => _ReaderMediaCard(
        attachment: block.attachments.isEmpty ? null : block.attachments.first,
        title: block.text,
        isVideo: false,
        height: block.height ?? 180,
        enablePreviewOnTap: previewImageOnTap,
      ),
      ReaderBlockKind.video => _ReaderMediaCard(
        attachment: block.attachments.isEmpty ? null : block.attachments.first,
        title: block.text,
        isVideo: true,
        height: block.height ?? 160,
        enablePreviewOnTap: previewImageOnTap,
      ),
      ReaderBlockKind.attachmentList => _ReaderAttachmentPanel(
        attachments: block.attachments,
      ),
      ReaderBlockKind.spacer => SizedBox(height: block.height ?? 12),
    };
  }
}

class _ReaderTipBar extends StatelessWidget {
  const _ReaderTipBar({
    required this.strings,
    required this.padding,
    required this.textColor,
    required this.dividerColor,
    required this.showDivider,
    required this.textScale,
  });

  final ReaderTipStrings strings;
  final EdgeInsets padding;
  final Color textColor;
  final Color dividerColor;
  final bool showDivider;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 12 * textScale,
      height: 1.35,
      color: textColor,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: dividerColor, width: 1))
            : null,
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                strings.left,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                strings.center,
                style: style,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                strings.right,
                style: style,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffstageSnapshotSurface extends StatelessWidget {
  const _OffstageSnapshotSurface({
    required this.boundaryKey,
    required this.page,
    required this.highlightQuery,
    required this.preferences,
    required this.collectionTitle,
    required this.globalPageIndex,
    required this.totalPages,
  });

  final GlobalKey boundaryKey;
  final ReaderPage? page;
  final String? highlightQuery;
  final CollectionReaderPreferences preferences;
  final String collectionTitle;
  final int globalPageIndex;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    if (page == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(100000, 0),
        child: SizedBox.expand(
          child: RepaintBoundary(
            key: boundaryKey,
            child: _ReaderPageSurface(
              page: page!,
              highlightQuery: highlightQuery,
              preferences: preferences,
              collectionTitle: collectionTitle,
              globalPageIndex: globalPageIndex,
              totalPages: totalPages,
              previewImageOnTap: false,
            ),
          ),
        ),
      ),
    );
  }
}

double _readerBlockSpacing(
  CollectionReaderPreferences preferences,
  ReaderTextRole role,
) {
  return switch (role) {
    ReaderTextRole.body => preferences.paragraphSpacing,
    ReaderTextRole.listItem => math.max(4, preferences.paragraphSpacing * 0.75),
    ReaderTextRole.heading => 10 + preferences.paragraphSpacing * 0.4,
    ReaderTextRole.quote => 10 + preferences.paragraphSpacing * 0.35,
    ReaderTextRole.code => 10,
    ReaderTextRole.tableRow => 4,
  };
}

FontWeight _readerFontWeight(CollectionReaderFontWeightMode mode) {
  return switch (mode) {
    CollectionReaderFontWeightMode.normal => FontWeight.w400,
    CollectionReaderFontWeightMode.medium => FontWeight.w500,
    CollectionReaderFontWeightMode.bold => FontWeight.w700,
  };
}

FontWeight _readerHeadingWeight(CollectionReaderFontWeightMode mode) {
  return switch (mode) {
    CollectionReaderFontWeightMode.normal => FontWeight.w700,
    CollectionReaderFontWeightMode.medium => FontWeight.w700,
    CollectionReaderFontWeightMode.bold => FontWeight.w800,
  };
}

class _ReaderMediaCard extends ConsumerWidget {
  const _ReaderMediaCard({
    required this.attachment,
    required this.title,
    required this.isVideo,
    required this.height,
    required this.enablePreviewOnTap,
  });

  final Attachment? attachment;
  final String? title;
  final bool isVideo;
  final double height;
  final bool enablePreviewOnTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final baseUrl = account?.baseUrl;
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final icon = isVideo
        ? Icons.play_circle_outline_rounded
        : Icons.photo_outlined;
    final resolvedTitle = attachment?.displayName.trim().isNotEmpty == true
        ? attachment!.displayName.trim()
        : title?.trim().isNotEmpty == true
        ? title!.trim()
        : isVideo
        ? 'Video'
        : 'Image';
    final videoEntry = !isVideo || attachment == null
        ? null
        : memoVideoEntryFromAttachment(
            attachment!,
            baseUrl,
            authHeader,
            rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
            attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          );
    final imageEntry = isVideo || attachment == null
        ? null
        : memoImageEntryFromAttachment(
            attachment!,
            baseUrl,
            authHeader,
            rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
            attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          );
    Future<void> openPreview() async {
      if (!enablePreviewOnTap || attachment == null) {
        return;
      }
      if (isVideo) {
        final entry = videoEntry;
        if (entry == null) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AttachmentVideoScreen(
              title: entry.title,
              localFile: entry.localFile,
              videoUrl: entry.videoUrl,
              thumbnailUrl: entry.thumbnailUrl,
              headers: entry.headers,
              cacheId: entry.id,
              cacheSize: entry.size,
            ),
          ),
        );
        return;
      }
      final image = imageEntry;
      if (image == null) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentGalleryScreen(
            images: const [],
            items: <AttachmentGalleryItem>[
              AttachmentGalleryItem.image(image.toGallerySource()),
            ],
            initialIndex: 0,
          ),
        ),
      );
    }

    Widget fallbackContent() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                resolvedTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    Widget imageThumbnail(MemoImageEntry entry) {
      Widget placeholder(IconData iconData) {
        return Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            iconData,
            size: 28,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
        );
      }

      final file = entry.localFile;
      final url = (entry.previewUrl ?? entry.fullUrl ?? '').trim();
      if (file != null) {
        final isSvg = shouldUseSvgRenderer(
          url: file.path,
          mimeType: entry.mimeType,
        );
        if (isSvg) {
          return SvgPicture.file(
            file,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => placeholder(Icons.image_outlined),
            errorBuilder: (context, error, stackTrace) {
              logImageLoadError(
                scope: 'collection_reader_paged_local_svg',
                source: file.path,
                error: error,
                stackTrace: stackTrace,
                extraContext: <String, Object?>{
                  'entryId': entry.id,
                  'mimeType': entry.mimeType,
                },
              );
              return fallbackContent();
            },
          );
        }
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'collection_reader_paged_local',
              source: file.path,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'entryId': entry.id,
                'mimeType': entry.mimeType,
              },
            );
            return fallbackContent();
          },
        );
      }
      if (url.isNotEmpty) {
        final isSvg = shouldUseSvgRenderer(url: url, mimeType: entry.mimeType);
        if (isSvg) {
          return SvgPicture.network(
            url,
            headers: entry.headers,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => placeholder(Icons.image_outlined),
            errorBuilder: (context, error, stackTrace) {
              logImageLoadError(
                scope: 'collection_reader_paged_network_svg',
                source: url,
                error: error,
                stackTrace: stackTrace,
                extraContext: <String, Object?>{
                  'entryId': entry.id,
                  'mimeType': entry.mimeType,
                  'hasAuthHeader':
                      entry.headers?['Authorization']?.trim().isNotEmpty ??
                      false,
                },
              );
              return fallbackContent();
            },
          );
        }
        return CachedNetworkImage(
          imageUrl: url,
          httpHeaders: entry.headers,
          fit: BoxFit.cover,
          placeholder: (context, _) => placeholder(Icons.image_outlined),
          errorWidget: (context, _, error) {
            logImageLoadError(
              scope: 'collection_reader_paged_network',
              source: url,
              error: error,
              extraContext: <String, Object?>{
                'entryId': entry.id,
                'mimeType': entry.mimeType,
                'hasAuthHeader':
                    entry.headers?['Authorization']?.trim().isNotEmpty ?? false,
              },
            );
            return fallbackContent();
          },
        );
      }
      return fallbackContent();
    }

    Widget previewContent() {
      if (isVideo && videoEntry != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AttachmentVideoThumbnail(
              key: ValueKey<String>(memoVideoThumbnailWidgetKey(videoEntry)),
              entry: videoEntry,
              borderRadius: 18,
              fit: BoxFit.cover,
              showPlayIcon: false,
            ),
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        );
      }
      if (!isVideo && imageEntry != null) {
        return imageThumbnail(imageEntry);
      }
      return fallbackContent();
    }

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: surface.withValues(alpha: isDark ? 0.26 : 0.38),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enablePreviewOnTap && attachment != null ? openPreview : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              previewContent(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
                    child: Text(
                      resolvedTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderAttachmentPanel extends StatelessWidget {
  const _ReaderAttachmentPanel({required this.attachments});

  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.22 : 0.34,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.strings.legacy.msg_attachments,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...attachments.map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      attachment.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InlineSpan _buildHighlightedSpan({
  required String text,
  required String? query,
  required TextStyle style,
  required Color highlightColor,
}) {
  final normalizedQuery = query?.trim() ?? '';
  if (normalizedQuery.isEmpty) {
    return TextSpan(text: text, style: style);
  }
  final lowerText = text.toLowerCase();
  final lowerQuery = normalizedQuery.toLowerCase();
  final children = <InlineSpan>[];
  var start = 0;
  while (true) {
    final matchIndex = lowerText.indexOf(lowerQuery, start);
    if (matchIndex < 0) {
      break;
    }
    if (matchIndex > start) {
      children.add(
        TextSpan(text: text.substring(start, matchIndex), style: style),
      );
    }
    children.add(
      TextSpan(
        text: text.substring(matchIndex, matchIndex + normalizedQuery.length),
        style: style.copyWith(
          backgroundColor: highlightColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    start = matchIndex + normalizedQuery.length;
  }
  if (start < text.length) {
    children.add(TextSpan(text: text.substring(start), style: style));
  }
  return TextSpan(style: style, children: children);
}
