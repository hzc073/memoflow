import 'package:flutter/material.dart';

import '../../../data/logs/log_manager.dart';

class ImagePreviewProgressiveRaster extends StatefulWidget {
  const ImagePreviewProgressiveRaster({
    super.key,
    required this.lowResImage,
    required this.highResImage,
    required this.fit,
    required this.loadingBuilder,
    this.debugTag,
    this.onLowResError,
    this.onHighResError,
  });

  final ImageProvider lowResImage;
  final ImageProvider highResImage;
  final BoxFit fit;
  final WidgetBuilder loadingBuilder;
  final String? debugTag;
  final ImageErrorListener? onLowResError;
  final ImageErrorListener? onHighResError;

  @override
  State<ImagePreviewProgressiveRaster> createState() =>
      _ImagePreviewProgressiveRasterState();
}

class _ImagePreviewProgressiveRasterState
    extends State<ImagePreviewProgressiveRaster> {
  bool _lowResReady = false;
  bool _highResReady = false;
  bool _lowResFailed = false;
  bool _highResAttempted = false;
  String? _lastLayoutSignature;

  void _logLayoutIfNeeded(BoxConstraints constraints, bool progressive) {
    final tag = widget.debugTag;
    if (tag == null || tag.isEmpty) {
      return;
    }
    final signature =
        '${constraints.maxWidth.toStringAsFixed(1)}x${constraints.maxHeight.toStringAsFixed(1)}'
        '|progressive=$progressive'
        '|lowReady=$_lowResReady'
        '|highReady=$_highResReady'
        '|lowFailed=$_lowResFailed'
        '|highAttempted=$_highResAttempted';
    if (_lastLayoutSignature == signature) {
      return;
    }
    _lastLayoutSignature = signature;
    LogManager.instance.debug(
      'ImagePreviewProgressiveRaster: layout',
      context: <String, Object?>{
        'tag': tag,
        'maxWidth': constraints.maxWidth,
        'maxHeight': constraints.maxHeight,
        'fit': widget.fit.name,
        'progressive': progressive,
        'lowResReady': _lowResReady,
        'highResReady': _highResReady,
        'lowResFailed': _lowResFailed,
        'highResAttempted': _highResAttempted,
      },
    );
  }

  void _markLowResReady() {
    if (!mounted || _lowResReady) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lowResReady) {
        return;
      }
      setState(() {
        _lowResReady = true;
        _highResAttempted = true;
      });
    });
  }

  void _markHighResReady() {
    if (!mounted || _highResReady) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _highResReady) {
        return;
      }
      setState(() => _highResReady = true);
    });
  }

  void _markLowResFailed() {
    if (!mounted || _lowResFailed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lowResFailed) {
        return;
      }
      setState(() => _lowResFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shouldProgressivelyLoad = widget.lowResImage != widget.highResImage;
    final lowResImage = Image(
      image: widget.lowResImage,
      fit: widget.fit,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          _markLowResReady();
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        widget.onLowResError?.call(error, stackTrace);
        _markLowResFailed();
        return const Icon(Icons.broken_image, color: Colors.white);
      },
    );

    if (!shouldProgressivelyLoad) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _logLayoutIfNeeded(constraints, false);
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (!_lowResReady && !_lowResFailed) widget.loadingBuilder(context),
              lowResImage,
            ],
          );
        },
      );
    }

    final highResImage = Image(
      image: widget.highResImage,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          _markHighResReady();
        }
        return AnimatedOpacity(
          opacity: _highResReady ? 1 : 0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        widget.onHighResError?.call(error, stackTrace);
        return const SizedBox.shrink();
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _logLayoutIfNeeded(constraints, true);
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (!_lowResReady && !_lowResFailed)
              widget.loadingBuilder(context),
            if (!_lowResFailed) lowResImage,
            if (_highResAttempted) highResImage,
          ],
        );
      },
    );
  }
}
