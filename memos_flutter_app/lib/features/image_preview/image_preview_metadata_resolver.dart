import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../../core/image_formats.dart';
import 'image_preview_item.dart';

typedef ImagePreviewRasterSize = ({int width, int height});

const double _imagePreviewDecodeOverscan = 1.5;
const double _imagePreviewPreviewDecodeFactor = 0.5;
const int _imagePreviewMobileMaxDecodePx = 1920;
const int _imagePreviewDesktopMaxDecodePx = 3072;
const int _imagePreviewMobilePreviewMaxDecodePx = 960;
const int _imagePreviewDesktopPreviewMaxDecodePx = 1440;
const double _imagePreviewDirectRenderAspectThreshold = 3.0;

ImagePreviewRasterSize? resolveImagePreviewDecodeSize(
  Size intrinsicSize,
  Size viewportSize,
  double devicePixelRatio, {
  required bool isDesktop,
}) {
  if (!intrinsicSize.width.isFinite ||
      !intrinsicSize.height.isFinite ||
      intrinsicSize.width <= 0 ||
      intrinsicSize.height <= 0 ||
      !viewportSize.width.isFinite ||
      !viewportSize.height.isFinite ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      devicePixelRatio <= 0) {
    return null;
  }
  final fittedSize = applyBoxFit(
    BoxFit.contain,
    intrinsicSize,
    viewportSize,
  ).destination;
  return _scaleImagePreviewSize(
    fittedSize,
    scale: devicePixelRatio * _imagePreviewDecodeOverscan,
    maxDimension: isDesktop
        ? _imagePreviewDesktopMaxDecodePx
        : _imagePreviewMobileMaxDecodePx,
  );
}

ImagePreviewRasterSize? resolveImagePreviewPreviewSize(
  ImagePreviewRasterSize? fullSize, {
  required bool isDesktop,
}) {
  if (fullSize == null) {
    return null;
  }
  return _scaleImagePreviewSize(
    Size(fullSize.width.toDouble(), fullSize.height.toDouble()),
    scale: _imagePreviewPreviewDecodeFactor,
    maxDimension: isDesktop
        ? _imagePreviewDesktopPreviewMaxDecodePx
        : _imagePreviewMobilePreviewMaxDecodePx,
  );
}

bool shouldUseDirectImagePreviewRender(ImagePreviewRasterSize? intrinsicSize) {
  if (intrinsicSize == null ||
      intrinsicSize.width <= 0 ||
      intrinsicSize.height <= 0) {
    return false;
  }
  final longest = math.max(intrinsicSize.width, intrinsicSize.height);
  final shortest = math.min(intrinsicSize.width, intrinsicSize.height);
  if (shortest <= 0) {
    return false;
  }
  return longest / shortest >= _imagePreviewDirectRenderAspectThreshold;
}

ImagePreviewRasterSize? _scaleImagePreviewSize(
  Size size, {
  required double scale,
  required int maxDimension,
}) {
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0 ||
      !scale.isFinite ||
      scale <= 0 ||
      maxDimension <= 0) {
    return null;
  }

  var scaledWidth = size.width * scale;
  var scaledHeight = size.height * scale;
  final largestDimension = math.max(scaledWidth, scaledHeight);
  if (!largestDimension.isFinite || largestDimension <= 0) {
    return null;
  }
  if (largestDimension > maxDimension) {
    final downscale = maxDimension / largestDimension;
    scaledWidth *= downscale;
    scaledHeight *= downscale;
  }
  return (
    width: math.max(1, scaledWidth.round()),
    height: math.max(1, scaledHeight.round()),
  );
}

ImagePreviewRasterSize resolveImagePreviewDecodeHint(
  ImagePreviewRasterSize targetSize,
) {
  if (targetSize.width >= targetSize.height) {
    return (width: targetSize.width, height: 0);
  }
  return (width: 0, height: targetSize.height);
}

ImagePreviewRasterSize? resolveImagePreviewDisplaySizeFromBytes(
  Uint8List bytes,
) {
  try {
    final decoder = img.findDecoderForData(bytes);
    final decoded = decoder?.decode(bytes);
    if (decoded == null) {
      return null;
    }
    final orientation = decoded.exif.imageIfd.orientation ?? 1;
    final swapsAxes = switch (orientation) {
      5 || 6 || 7 || 8 => true,
      _ => false,
    };
    if (decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }
    return swapsAxes
        ? (width: decoded.height, height: decoded.width)
        : (width: decoded.width, height: decoded.height);
  } catch (_) {
    return null;
  }
}

ImagePreviewRasterSize? resolveImagePreviewKnownIntrinsicSize(
  ImagePreviewItem item,
) {
  final resolvedWidth = item.width;
  final resolvedHeight = item.height;
  if (resolvedWidth == null ||
      resolvedHeight == null ||
      resolvedWidth <= 0 ||
      resolvedHeight <= 0) {
    return null;
  }
  return (width: resolvedWidth, height: resolvedHeight);
}

ImagePreviewRasterSize? chooseImagePreviewResolvedIntrinsicSize({
  ImagePreviewRasterSize? fileResolved,
  ImagePreviewRasterSize? providerResolved,
}) {
  return providerResolved ?? fileResolved;
}

bool isSvgImagePreviewItem(ImagePreviewItem item) => shouldUseSvgRenderer(
  url:
      item.localFile?.path ??
      item.resolvedGalleryUrl ??
      item.resolvedTileUrl ??
      '',
  mimeType: item.mimeType,
);

ImageProvider<Object>? imagePreviewOriginalRasterProvider(
  ImagePreviewItem item,
) {
  final file = item.localFile;
  if (file != null && file.existsSync()) {
    return FileImage(file);
  }
  final url =
      item.resolvedGalleryUrl?.trim() ?? item.resolvedTileUrl?.trim() ?? '';
  if (url.isNotEmpty) {
    return CachedNetworkImageProvider(url, headers: item.headers);
  }
  return null;
}

Future<ImagePreviewRasterSize?> resolveImagePreviewIntrinsicSize(
  ImagePreviewItem item,
) async {
  final knownSize = resolveImagePreviewKnownIntrinsicSize(item);
  if (knownSize != null) {
    return knownSize;
  }
  if (isSvgImagePreviewItem(item)) {
    return null;
  }

  final provider = imagePreviewOriginalRasterProvider(item);
  if (provider == null) {
    return null;
  }

  final completer = Completer<ImagePreviewRasterSize?>();
  final stream = provider.resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, _) {
      if (!completer.isCompleted) {
        final width = image.image.width;
        final height = image.image.height;
        final resolved = width > 0 && height > 0
            ? (width: width, height: height)
            : null;
        completer.complete(resolved);
      }
      stream.removeListener(listener);
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      stream.removeListener(listener);
      return null;
    },
  );
}
