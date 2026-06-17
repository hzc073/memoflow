import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_editor_plus/options.dart' as editor_options;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/desktop/window_chrome_safe_area.dart';
import '../../core/image_formats.dart';
import '../../core/image_error_logger.dart';
import '../../core/scene_micro_guide_widgets.dart';
import '../../core/top_toast.dart';
import '../../data/logs/log_manager.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../image_preview/image_preview_item.dart';
import '../image_preview/image_preview_open_request.dart';
import '../image_preview/widgets/_image_preview_desktop_frame.dart';
import '../image_preview/widgets/_image_preview_progressive_raster.dart';
import '../image_preview/widgets/_image_preview_zoomable_viewport.dart';
import '../image_preview/widgets/image_preview_gallery_body.dart';
import 'attachment_video_screen.dart';
import 'memo_video_grid.dart';

const double _galleryDecodeOverscan = 1.5;
const int _galleryMobileMaxDecodePx = 1920;
const int _galleryDesktopMaxDecodePx = 1920;
const double _galleryPreviewDecodeFactor = 0.5;
const int _galleryMobilePreviewMaxDecodePx = 960;
const int _galleryDesktopPreviewMaxDecodePx = 1440;
const double _galleryDirectRenderAspectThreshold = 3.0;

typedef AttachmentGalleryRasterSize = ({int width, int height});

@visibleForTesting
int? resolveAttachmentGalleryCacheExtent(
  double logicalExtent,
  double devicePixelRatio, {
  required bool isDesktop,
}) {
  if (!logicalExtent.isFinite || logicalExtent <= 0 || devicePixelRatio <= 0) {
    return null;
  }
  final pixels = (logicalExtent * devicePixelRatio * _galleryDecodeOverscan)
      .round();
  if (pixels <= 0) return null;
  final maxDecodePx = isDesktop
      ? _galleryDesktopMaxDecodePx
      : _galleryMobileMaxDecodePx;
  return pixels > maxDecodePx ? maxDecodePx : pixels;
}

@visibleForTesting
int? resolveAttachmentGalleryPreviewExtent(
  int? fullExtent, {
  required bool isDesktop,
}) {
  if (fullExtent == null || fullExtent <= 0) return null;
  final previewMaxDecodePx = isDesktop
      ? _galleryDesktopPreviewMaxDecodePx
      : _galleryMobilePreviewMaxDecodePx;
  final previewExtent = (fullExtent * _galleryPreviewDecodeFactor).round();
  final normalizedExtent = previewExtent <= 0 ? fullExtent : previewExtent;
  final cappedExtent = normalizedExtent > previewMaxDecodePx
      ? previewMaxDecodePx
      : normalizedExtent;
  return cappedExtent > fullExtent ? fullExtent : cappedExtent;
}

@visibleForTesting
AttachmentGalleryRasterSize? resolveAttachmentGalleryDecodeSize(
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
  return _scaleAttachmentGallerySize(
    fittedSize,
    scale: devicePixelRatio * _galleryDecodeOverscan,
    maxDimension: isDesktop
        ? _galleryDesktopMaxDecodePx
        : _galleryMobileMaxDecodePx,
  );
}

@visibleForTesting
AttachmentGalleryRasterSize? resolveAttachmentGalleryPreviewSize(
  AttachmentGalleryRasterSize? fullSize, {
  required bool isDesktop,
}) {
  if (fullSize == null) return null;
  return _scaleAttachmentGallerySize(
    Size(fullSize.width.toDouble(), fullSize.height.toDouble()),
    scale: _galleryPreviewDecodeFactor,
    maxDimension: isDesktop
        ? _galleryDesktopPreviewMaxDecodePx
        : _galleryMobilePreviewMaxDecodePx,
  );
}

AttachmentGalleryRasterSize? _scaleAttachmentGallerySize(
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

@visibleForTesting
bool shouldUseDirectAttachmentGalleryRender(
  AttachmentGalleryRasterSize? intrinsicSize,
) {
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
  return longest / shortest >= _galleryDirectRenderAspectThreshold;
}

@visibleForTesting
AttachmentGalleryRasterSize? chooseAttachmentGalleryResolvedIntrinsicSize({
  AttachmentGalleryRasterSize? fileResolved,
  AttachmentGalleryRasterSize? providerResolved,
}) {
  return providerResolved ?? fileResolved;
}

@visibleForTesting
AttachmentGalleryRasterSize resolveAttachmentGalleryDecodeHint(
  AttachmentGalleryRasterSize targetSize,
) {
  if (targetSize.width >= targetSize.height) {
    return (width: targetSize.width, height: 0);
  }
  return (width: 0, height: targetSize.height);
}

class AttachmentImageSource {
  const AttachmentImageSource({
    required this.id,
    required this.title,
    required this.mimeType,
    this.localFile,
    this.imageUrl,
    this.headers,
    this.width,
    this.height,
  });

  final String id;
  final String title;
  final String mimeType;
  final File? localFile;
  final String? imageUrl;
  final Map<String, String>? headers;
  final int? width;
  final int? height;

  AttachmentGalleryRasterSize? get intrinsicSize {
    final resolvedWidth = width;
    final resolvedHeight = height;
    if (resolvedWidth == null ||
        resolvedHeight == null ||
        resolvedWidth <= 0 ||
        resolvedHeight <= 0) {
      return null;
    }
    return (width: resolvedWidth, height: resolvedHeight);
  }
}

bool _isSvgAttachmentSource(AttachmentImageSource source) =>
    shouldUseSvgRenderer(
      url: source.localFile?.path ?? source.imageUrl ?? '',
      mimeType: source.mimeType,
    );

ImageProvider<Object>? _attachmentGalleryOriginalRasterProvider(
  AttachmentImageSource source,
) {
  final file = source.localFile;
  if (file != null && file.existsSync()) {
    return FileImage(file);
  }
  final url = source.imageUrl?.trim() ?? '';
  if (url.isNotEmpty) {
    return CachedNetworkImageProvider(url, headers: source.headers);
  }
  return null;
}

@visibleForTesting
AttachmentGalleryRasterSize? resolveAttachmentGalleryDisplaySizeFromBytes(
  Uint8List bytes,
) {
  try {
    final decoder = img.findDecoderForData(bytes);
    final decoded = decoder?.decode(bytes);
    if (decoded == null) return null;
    final orientation = decoded.exif.imageIfd.orientation ?? 1;
    final swapsAxes = switch (orientation) {
      5 || 6 || 7 || 8 => true,
      _ => false,
    };
    if (decoded.width <= 0 || decoded.height <= 0) return null;
    return swapsAxes
        ? (width: decoded.height, height: decoded.width)
        : (width: decoded.width, height: decoded.height);
  } catch (_) {
    return null;
  }
}

Future<AttachmentGalleryRasterSize?> _resolveAttachmentGalleryIntrinsicSize(
  AttachmentImageSource source,
) async {
  final knownSize = source.intrinsicSize;
  if (knownSize != null) return knownSize;
  if (_isSvgAttachmentSource(source)) return null;

  final provider = _attachmentGalleryOriginalRasterProvider(source);
  if (provider == null) return null;

  final completer = Completer<AttachmentGalleryRasterSize?>();
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
        LogManager.instance.debug(
          'AttachmentGallery: intrinsic_size_provider_probe',
          context: <String, Object?>{
            'sourceId': source.id,
            'title': source.title,
            'resolved': resolved != null,
            'providerWidth': resolved?.width,
            'providerHeight': resolved?.height,
          },
        );
        completer.complete(resolved);
      }
      stream.removeListener(listener);
    },
    onError: (error, stackTrace) {
      LogManager.instance.warn(
        'AttachmentGallery: intrinsic_size_provider_probe_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'sourceId': source.id,
          'title': source.title,
        },
      );
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

class AttachmentGalleryItem {
  const AttachmentGalleryItem.image(this.image) : video = null;
  const AttachmentGalleryItem.video(this.video) : image = null;

  final AttachmentImageSource? image;
  final MemoVideoEntry? video;

  bool get isImage => image != null;
  bool get isVideo => video != null;
}

class EditedImageResult {
  const EditedImageResult({
    required this.sourceId,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String sourceId;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

ImagePreviewItem _attachmentImageSourceToImagePreviewItem(
  AttachmentImageSource source,
) {
  return ImagePreviewItem(
    id: source.id,
    title: source.title,
    mimeType: source.mimeType,
    localFile: source.localFile,
    fullUrl: source.imageUrl,
    headers: source.headers,
    width: source.width,
    height: source.height,
  );
}

class AttachmentGalleryScreen extends ConsumerStatefulWidget {
  const AttachmentGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.items,
    this.onReplace,
    this.enableDownload = true,
    this.albumName = 'MemoFlow',
    this.isDesktopOverride,
    this.immersiveDesktopChrome,
    this.showViewerCloseButton = false,
    this.onClose,
  });

  final List<AttachmentImageSource> images;
  final List<AttachmentGalleryItem>? items;
  final int initialIndex;
  final Future<void> Function(EditedImageResult result)? onReplace;
  final bool enableDownload;
  final String albumName;
  final bool? isDesktopOverride;
  final bool? immersiveDesktopChrome;
  final bool showViewerCloseButton;
  final Future<void> Function()? onClose;

  @override
  ConsumerState<AttachmentGalleryScreen> createState() =>
      _AttachmentGalleryScreenState();
}

class _AttachmentGalleryScreenState
    extends ConsumerState<AttachmentGalleryScreen> {
  static const double _minScale = 1;
  static const double _maxScale = 4;
  static const Duration _pageAnimationDuration = Duration(milliseconds: 180);

  late final PageController _controller;
  late final FocusNode _focusNode;
  late final List<AttachmentGalleryItem> _items;
  int _index = 0;
  bool _busy = false;
  final Set<int> _zoomedImageIndexes = <int>{};
  final Map<String, AttachmentGalleryRasterSize> _resolvedImageSizes =
      <String, AttachmentGalleryRasterSize>{};
  final Set<String> _resolvingImageSizes = <String>{};
  final Set<String> _failedImageSizeResolutions = <String>{};
  final Map<String, String> _loggedRenderPlanSignatures = <String, String>{};
  final Map<String, String> _loggedRenderModeSignatures = <String, String>{};

  bool get _isDesktopGallery =>
      widget.isDesktopOverride ??
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _usesImmersiveDesktopChrome =>
      _isDesktopGallery && (widget.immersiveDesktopChrome ?? true);

  bool get _hasPreviousPage => _index > 0;
  bool get _hasNextPage => _index < _items.length - 1;
  bool get _isCurrentImageZoomed => _zoomedImageIndexes.contains(_index);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'attachment_gallery');
    _items =
        widget.items ??
        widget.images.map(AttachmentGalleryItem.image).toList(growable: false);
    final safeIndex = _items.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _items.length - 1);
    _index = safeIndex;
    _controller = PageController(initialPage: safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int targetIndex) {
    if (_items.isEmpty) return;
    final nextIndex = targetIndex.clamp(0, _items.length - 1);
    if (nextIndex == _index) return;
    _focusNode.requestFocus();
    _controller.animateToPage(
      nextIndex,
      duration: _pageAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _showPreviousPage() => _goToPage(_index - 1);

  void _showNextPage() => _goToPage(_index + 1);

  void _handleImageZoomChanged(int index, bool isZoomed) {
    if (!mounted || _items.isEmpty || index < 0 || index >= _items.length) {
      return;
    }
    if (_items[index].isVideo) return;
    final hasChanged = isZoomed
        ? _zoomedImageIndexes.add(index)
        : _zoomedImageIndexes.remove(index);
    if (!hasChanged) return;
    setState(() {});
  }

  void _handleImageEdgePageRequest(
    int index,
    ImagePreviewPageDirection direction,
  ) {
    if (!mounted || index != _index) return;
    _markSceneGuideSeen(SceneMicroGuideId.attachmentGalleryControls);
    switch (direction) {
      case ImagePreviewPageDirection.previous:
        _showPreviousPage();
      case ImagePreviewPageDirection.next:
        _showNextPage();
    }
  }

  void _closeGallery() {
    final close = widget.onClose;
    if (close != null) {
      unawaited(close());
      return;
    }
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.maybePop();
  }

  void _markSceneGuideSeen(SceneMicroGuideId id) {
    unawaited(ref.read(sceneMicroGuideProvider.notifier).markSeen(id));
  }

  Map<String, Object?> _galleryLogContext(
    AttachmentImageSource source, {
    AttachmentGalleryRasterSize? intrinsicSize,
    Map<String, Object?>? extra,
  }) {
    return <String, Object?>{
      'sourceId': source.id,
      'title': source.title,
      'mimeType': source.mimeType,
      'hasLocalFile': source.localFile != null,
      'hasImageUrl': (source.imageUrl?.trim().isNotEmpty ?? false),
      'metadataWidth': source.width,
      'metadataHeight': source.height,
      if (intrinsicSize != null) 'intrinsicWidth': intrinsicSize.width,
      if (intrinsicSize != null) 'intrinsicHeight': intrinsicSize.height,
      ...?extra,
    };
  }

  void _logRenderPlanIfNeeded(
    AttachmentImageSource source, {
    required Size viewportSize,
    required double devicePixelRatio,
    required AttachmentGalleryRasterSize? intrinsicSize,
    required bool shouldWaitForIntrinsicSize,
    required AttachmentGalleryRasterSize? cacheSize,
    required AttachmentGalleryRasterSize? previewSize,
    required AttachmentGalleryRasterSize? cacheHint,
    required AttachmentGalleryRasterSize? previewHint,
    required Size? displaySize,
    required bool preferDirectRender,
  }) {
    final signature =
        '${viewportSize.width.toStringAsFixed(1)}x${viewportSize.height.toStringAsFixed(1)}'
        '|dpr=${devicePixelRatio.toStringAsFixed(2)}'
        '|intrinsic=${intrinsicSize?.width ?? 0}x${intrinsicSize?.height ?? 0}'
        '|wait=$shouldWaitForIntrinsicSize'
        '|cache=${cacheSize?.width ?? 0}x${cacheSize?.height ?? 0}'
        '|preview=${previewSize?.width ?? 0}x${previewSize?.height ?? 0}'
        '|cacheHint=${cacheHint?.width ?? 0}x${cacheHint?.height ?? 0}'
        '|previewHint=${previewHint?.width ?? 0}x${previewHint?.height ?? 0}'
        '|display=${displaySize?.width.toStringAsFixed(1) ?? '0.0'}x${displaySize?.height.toStringAsFixed(1) ?? '0.0'}'
        '|direct=$preferDirectRender';
    final lastSignature = _loggedRenderPlanSignatures[source.id];
    if (lastSignature == signature) return;
    _loggedRenderPlanSignatures[source.id] = signature;
    LogManager.instance.debug(
      'AttachmentGallery: render_plan',
      context: _galleryLogContext(
        source,
        intrinsicSize: intrinsicSize,
        extra: <String, Object?>{
          'viewportWidth': viewportSize.width,
          'viewportHeight': viewportSize.height,
          'devicePixelRatio': devicePixelRatio,
          'waitingForIntrinsicSize': shouldWaitForIntrinsicSize,
          'cacheWidth': cacheSize?.width,
          'cacheHeight': cacheSize?.height,
          'previewWidth': previewSize?.width,
          'previewHeight': previewSize?.height,
          'cacheHintWidth': cacheHint?.width,
          'cacheHintHeight': cacheHint?.height,
          'previewHintWidth': previewHint?.width,
          'previewHintHeight': previewHint?.height,
          'displayWidth': displaySize?.width,
          'displayHeight': displaySize?.height,
          'preferDirectRender': preferDirectRender,
        },
      ),
    );
  }

  void _logRenderModeIfNeeded(
    AttachmentImageSource source, {
    required bool preferDirectRender,
    required int? previewCacheWidth,
    required int? previewCacheHeight,
    required int? cacheWidth,
    required int? cacheHeight,
  }) {
    final hasLocalFile =
        source.localFile != null && source.localFile!.existsSync();
    final mode = preferDirectRender ? 'direct' : 'progressive';
    final signature =
        'mode=$mode'
        '|source=${hasLocalFile ? 'local' : 'remote'}'
        '|preview=${previewCacheWidth ?? 0}x${previewCacheHeight ?? 0}'
        '|cache=${cacheWidth ?? 0}x${cacheHeight ?? 0}';
    final lastSignature = _loggedRenderModeSignatures[source.id];
    if (lastSignature == signature) {
      return;
    }
    _loggedRenderModeSignatures[source.id] = signature;
    LogManager.instance.debug(
      'AttachmentGallery: render_mode',
      context: _galleryLogContext(
        source,
        extra: <String, Object?>{
          'renderMode': mode,
          'sourceType': hasLocalFile ? 'local' : 'remote',
          'previewCacheWidth': previewCacheWidth,
          'previewCacheHeight': previewCacheHeight,
          'cacheWidth': cacheWidth,
          'cacheHeight': cacheHeight,
        },
      ),
    );
  }

  AttachmentGalleryRasterSize? _resolvedIntrinsicSizeFor(
    AttachmentImageSource source,
  ) {
    return source.intrinsicSize ?? _resolvedImageSizes[source.id];
  }

  bool _canResolveIntrinsicSize(AttachmentImageSource source) {
    if (_resolvedIntrinsicSizeFor(source) != null) return false;
    if (_failedImageSizeResolutions.contains(source.id)) return false;
    if (_isSvgAttachmentSource(source)) return false;
    return _attachmentGalleryOriginalRasterProvider(source) != null;
  }

  void _scheduleIntrinsicSizeResolution(AttachmentImageSource source) {
    if (!_canResolveIntrinsicSize(source)) return;
    if (!_resolvingImageSizes.add(source.id)) return;
    LogManager.instance.debug(
      'AttachmentGallery: intrinsic_size_resolve_start',
      context: _galleryLogContext(source),
    );
    unawaited(() async {
      AttachmentGalleryRasterSize? fileResolved;
      final file = source.localFile;
      if (file != null && file.existsSync()) {
        try {
          final bytes = await file.readAsBytes();
          fileResolved = await compute(
            resolveAttachmentGalleryDisplaySizeFromBytes,
            bytes,
          );
          LogManager.instance.debug(
            'AttachmentGallery: intrinsic_size_file_probe',
            context: _galleryLogContext(
              source,
              intrinsicSize: fileResolved,
              extra: <String, Object?>{
                'filePath': file.path,
                'fileBytes': bytes.length,
                'resolvedFromFileBytes': fileResolved != null,
              },
            ),
          );
        } catch (error, stackTrace) {
          LogManager.instance.warn(
            'AttachmentGallery: intrinsic_size_file_probe_failed',
            error: error,
            stackTrace: stackTrace,
            context: _galleryLogContext(
              source,
              extra: <String, Object?>{'filePath': file.path},
            ),
          );
        }
      }
      final providerResolved = await _resolveAttachmentGalleryIntrinsicSize(
        source,
      );
      final resolved = chooseAttachmentGalleryResolvedIntrinsicSize(
        fileResolved: fileResolved,
        providerResolved: providerResolved,
      );
      LogManager.instance.debug(
        'AttachmentGallery: intrinsic_size_resolve_done',
        context: _galleryLogContext(
          source,
          intrinsicSize: resolved,
          extra: <String, Object?>{
            'fileResolvedWidth': fileResolved?.width,
            'fileResolvedHeight': fileResolved?.height,
            'providerResolvedWidth': providerResolved?.width,
            'providerResolvedHeight': providerResolved?.height,
            'preferredProbe': resolved == providerResolved
                ? 'provider'
                : resolved == fileResolved
                ? 'file'
                : 'none',
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _resolvingImageSizes.remove(source.id);
        if (resolved != null) {
          _resolvedImageSizes[source.id] = resolved;
          _failedImageSizeResolutions.remove(source.id);
        } else {
          _failedImageSizeResolutions.add(source.id);
        }
      });
    }());
  }

  KeyEventResult _handleGalleryKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_currentImage != null) {
        _markSceneGuideSeen(SceneMicroGuideId.attachmentGalleryControls);
      }
      _closeGallery();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      if (_currentImage != null) {
        _markSceneGuideSeen(SceneMicroGuideId.attachmentGalleryControls);
      }
      _showPreviousPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      if (_currentImage != null) {
        _markSceneGuideSeen(SceneMicroGuideId.attachmentGalleryControls);
      }
      _showNextPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  AttachmentImageSource? get _currentImage {
    if (_items.isEmpty) return null;
    return _items[_index].image;
  }

  Future<Uint8List?> _loadBytes(AttachmentImageSource source) async {
    final file = source.localFile;
    if (file != null && file.existsSync()) {
      return file.readAsBytes();
    }
    final url = source.imageUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: source.headers,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = response.data;
    if (data == null) return null;
    return Uint8List.fromList(data);
  }

  Future<bool> _ensureGalleryPermission() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt <= 28) {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
      return true;
    }
    return true;
  }

  bool _isGallerySaveSuccess(dynamic result) {
    if (result is Map) {
      final flag = result['isSuccess'] ?? result['success'];
      if (flag is bool) return flag;
    }
    return result == true;
  }

  String _safeBaseName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'MemoFlow';
    final base = p.basenameWithoutExtension(trimmed);
    if (base.trim().isEmpty) return 'MemoFlow';
    return base.replaceAll(RegExp(r'[<>:"/\\\\|?*]'), '_');
  }

  String _editedFilename(AttachmentImageSource source) {
    final base = _safeBaseName(source.title);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${base}_edited_$stamp.jpg';
  }

  Future<EditedImageResult> _persistEditedImage(
    AttachmentImageSource source,
    Uint8List bytes,
  ) async {
    final dir = await getTemporaryDirectory();
    final filename = _editedFilename(source);
    var path = p.join(dir.path, filename);
    var counter = 1;
    while (File(path).existsSync()) {
      final stem = p.basenameWithoutExtension(filename);
      path = p.join(dir.path, '${stem}_$counter.jpg');
      counter++;
    }
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    final size = await file.length();
    return EditedImageResult(
      sourceId: source.id,
      filePath: path,
      filename: filename,
      mimeType: 'image/jpeg',
      size: size,
    );
  }

  Uint8List _reencodeJpeg(Uint8List bytes, {int quality = 90}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final encoded = img.encodeJpg(decoded, quality: quality);
    return Uint8List.fromList(encoded);
  }

  Future<void> _saveBytesToGallery(
    Uint8List bytes, {
    required String name,
  }) async {
    if (_isDesktopGallery) {
      await _saveBytesToDesktop(bytes, suggestedName: name);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final allowed = await _ensureGalleryPermission();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_gallery_permission_required_2,
            ),
          ),
        );
        return;
      }
      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: name,
        quality: 90,
        albumName: widget.albumName,
      );
      final ok = _isGallerySaveSuccess(result);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_save_failed)),
        );
        return;
      }
      showTopToast(context, context.t.strings.legacy.msg_saved_gallery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveFileToGallery(File file, {required String name}) async {
    if (_isDesktopGallery) {
      await _saveFileToDesktop(file, suggestedName: name);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final allowed = await _ensureGalleryPermission();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_gallery_permission_required_2,
            ),
          ),
        );
        return;
      }
      final result = await ImageGallerySaver.saveFile(
        file.path,
        name: name,
        albumName: widget.albumName,
      );
      final ok = _isGallerySaveSuccess(result);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_save_failed)),
        );
        return;
      }
      showTopToast(context, context.t.strings.legacy.msg_saved_gallery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadCurrent() async {
    final source = _currentImage;
    if (source == null) return;
    final file = source.localFile;
    if (file != null && file.existsSync()) {
      final base = _safeBaseName(source.title);
      await _saveFileToGallery(file, name: base);
      return;
    }

    final bytes = await _loadBytes(source);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_unable_open_photo)),
      );
      return;
    }

    final ext = p.extension(source.title).replaceAll('.', '');
    final name = _safeBaseName(source.title);
    final dir = await getTemporaryDirectory();
    final filename = ext.isEmpty ? '$name.jpg' : '$name.$ext';
    var path = p.join(dir.path, filename);
    var counter = 1;
    while (File(path).existsSync()) {
      final stem = p.basenameWithoutExtension(filename);
      path = p.join(dir.path, '${stem}_$counter.${ext.isEmpty ? 'jpg' : ext}');
      counter++;
    }
    final tempFile = File(path);
    await tempFile.writeAsBytes(bytes, flush: true);
    await _saveFileToGallery(
      tempFile,
      name: p.basenameWithoutExtension(filename),
    );
  }

  Future<String?> _pickDesktopSavePath({required String suggestedName}) async {
    return FilePicker.platform.saveFile(
      dialogTitle: context.t.strings.legacy.msg_file_save_location,
      fileName: suggestedName,
    );
  }

  Future<void> _saveBytesToDesktop(
    Uint8List bytes, {
    required String suggestedName,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final targetPath = await _pickDesktopSavePath(
        suggestedName: suggestedName,
      );
      if (!mounted) return;
      if (targetPath == null || targetPath.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_select_file_save_location,
            ),
          ),
        );
        return;
      }
      final outFile = File(targetPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved(targetPath: outFile.path),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveFileToDesktop(
    File file, {
    required String suggestedName,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ext = p.extension(file.path);
      final hasExt = p.extension(suggestedName).isNotEmpty;
      final fileName = hasExt ? suggestedName : '$suggestedName$ext';
      final targetPath = await _pickDesktopSavePath(suggestedName: fileName);
      if (!mounted) return;
      if (targetPath == null || targetPath.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_select_file_save_location,
            ),
          ),
        );
        return;
      }
      final outFile = File(targetPath);
      await outFile.parent.create(recursive: true);
      await file.copy(outFile.path);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved(targetPath: outFile.path),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCurrent() async {
    if (widget.onReplace == null) return;
    final source = _currentImage;
    if (source == null) return;
    final bytes = await _loadBytes(source);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_unable_open_photo)),
      );
      return;
    }

    if (!mounted) return;
    final edited = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageEditor(
          image: bytes,
          outputFormat: editor_options.OutputFormat.jpeg,
        ),
      ),
    );
    if (!mounted) return;
    if (edited == null) return;

    final action = await showDialog<_EditAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.strings.legacy.msg_edit_completed),
        content: Text(context.t.strings.legacy.msg_choose_what_edited_image),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_EditAction.saveLocal),
            child: Text(context.t.strings.legacy.msg_save_gallery),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_EditAction.replace),
            child: Text(context.t.strings.legacy.msg_replace_memo_image),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == null) return;

    final encoded = _reencodeJpeg(edited, quality: 90);
    if (action == _EditAction.saveLocal) {
      final name = _safeBaseName(source.title);
      await _saveBytesToGallery(encoded, name: '${name}_edited');
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_replace_image),
            content: Text(
              context
                  .t
                  .strings
                  .legacy
                  .msg_replacing_delete_original_attachment_continue,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.t.strings.legacy.msg_continue),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted) return;
    if (!confirmed) return;

    final result = await _persistEditedImage(source, encoded);
    await widget.onReplace?.call(result);
  }

  void _openVideo(MemoVideoEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentVideoScreen(
          title: entry.title,
          localFile: entry.localFile,
          videoUrl: entry.videoUrl,
          thumbnailUrl: entry.thumbnailUrl,
          headers: entry.headers,
          cacheId: entry.id,
          cacheSize: entry.size,
          immersiveDesktopChrome: _usesImmersiveDesktopChrome,
          showViewerCloseButton: widget.showViewerCloseButton,
          onClose: widget.onClose,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildImage(
    AttachmentImageSource source, {
    int? previewCacheWidth,
    int? previewCacheHeight,
    int? cacheWidth,
    int? cacheHeight,
    bool preferDirectRender = false,
  }) {
    _logRenderModeIfNeeded(
      source,
      preferDirectRender: preferDirectRender,
      previewCacheWidth: previewCacheWidth,
      previewCacheHeight: previewCacheHeight,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
    final file = source.localFile;
    if (file != null && file.existsSync()) {
      final isSvg = shouldUseSvgRenderer(
        url: file.path,
        mimeType: source.mimeType,
      );
      if (isSvg) {
        return SvgPicture.file(
          file,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => _buildLoadingIndicator(context),
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'attachment_gallery_local_svg',
              source: file.path,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'sourceId': source.id,
                'mimeType': source.mimeType,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      if (preferDirectRender) {
        return Image(
          image: FileImage(file),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [_buildLoadingIndicator(context), child],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'attachment_gallery_local_direct',
              source: file.path,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'sourceId': source.id,
                'mimeType': source.mimeType,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      return ImagePreviewProgressiveRaster(
        debugTag: source.id,
        lowResImage: ResizeImage.resizeIfNeeded(
          previewCacheWidth,
          previewCacheHeight,
          FileImage(file),
        ),
        highResImage: ResizeImage.resizeIfNeeded(
          cacheWidth,
          cacheHeight,
          FileImage(file),
        ),
        fit: BoxFit.contain,
        loadingBuilder: _buildLoadingIndicator,
        onLowResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'attachment_gallery_local',
            source: file.path,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'sourceId': source.id,
              'mimeType': source.mimeType,
              'phase': 'preview',
            },
          );
        },
        onHighResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'attachment_gallery_local',
            source: file.path,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'sourceId': source.id,
              'mimeType': source.mimeType,
              'phase': 'full',
            },
          );
        },
      );
    }
    final url = source.imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      final isSvg = shouldUseSvgRenderer(url: url, mimeType: source.mimeType);
      if (isSvg) {
        return SvgPicture.network(
          url,
          headers: source.headers,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => _buildLoadingIndicator(context),
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'attachment_gallery_network_svg',
              source: url,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'sourceId': source.id,
                'mimeType': source.mimeType,
                'hasAuthHeader':
                    source.headers?['Authorization']?.trim().isNotEmpty ??
                    false,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      if (preferDirectRender) {
        return Image(
          image: CachedNetworkImageProvider(url, headers: source.headers),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [_buildLoadingIndicator(context), child],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'attachment_gallery_network_direct',
              source: url,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'sourceId': source.id,
                'mimeType': source.mimeType,
                'hasAuthHeader':
                    source.headers?['Authorization']?.trim().isNotEmpty ??
                    false,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      return ImagePreviewProgressiveRaster(
        debugTag: source.id,
        lowResImage: CachedNetworkImageProvider(
          url,
          headers: source.headers,
          maxWidth: previewCacheWidth,
          maxHeight: previewCacheHeight,
        ),
        highResImage: CachedNetworkImageProvider(
          url,
          headers: source.headers,
          maxWidth: cacheWidth,
          maxHeight: cacheHeight,
        ),
        fit: BoxFit.contain,
        loadingBuilder: _buildLoadingIndicator,
        onLowResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'attachment_gallery_network',
            source: url,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'sourceId': source.id,
              'mimeType': source.mimeType,
              'hasAuthHeader':
                  source.headers?['Authorization']?.trim().isNotEmpty ?? false,
              'phase': 'preview',
            },
          );
        },
        onHighResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'attachment_gallery_network',
            source: url,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'sourceId': source.id,
              'mimeType': source.mimeType,
              'hasAuthHeader':
                  source.headers?['Authorization']?.trim().isNotEmpty ?? false,
              'phase': 'full',
            },
          );
        },
      );
    }
    return const Icon(Icons.broken_image, color: Colors.white);
  }

  Widget _buildVideoPage(MemoVideoEntry entry) {
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openVideo(entry),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AttachmentVideoThumbnail(
                  entry: entry,
                  borderRadius: 12,
                  fit: BoxFit.contain,
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return _wrapGalleryPage(content);
  }

  Widget _buildImagePage(
    AttachmentImageSource source, {
    required int pageIndex,
  }) {
    return _wrapGalleryPage(
      LayoutBuilder(
        builder: (context, constraints) {
          final mediaSize = MediaQuery.sizeOf(context);
          final viewportWidth =
              constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : mediaSize.width;
          final viewportHeight =
              constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : mediaSize.height;
          final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          final intrinsicSize = _resolvedIntrinsicSizeFor(source);
          final shouldWaitForIntrinsicSize =
              intrinsicSize == null && _canResolveIntrinsicSize(source);
          if (shouldWaitForIntrinsicSize) {
            _scheduleIntrinsicSizeResolution(source);
          }
          final cacheSize = intrinsicSize == null
              ? null
              : resolveAttachmentGalleryDecodeSize(
                  Size(
                    intrinsicSize.width.toDouble(),
                    intrinsicSize.height.toDouble(),
                  ),
                  Size(viewportWidth, viewportHeight),
                  devicePixelRatio,
                  isDesktop: _isDesktopGallery,
                );
          final previewSize = resolveAttachmentGalleryPreviewSize(
            cacheSize,
            isDesktop: _isDesktopGallery,
          );
          final cacheHint = cacheSize == null
              ? null
              : resolveAttachmentGalleryDecodeHint(cacheSize);
          final previewHint = previewSize == null
              ? null
              : resolveAttachmentGalleryDecodeHint(previewSize);
          final preferDirectRender = shouldUseDirectAttachmentGalleryRender(
            intrinsicSize,
          );
          final displaySize = intrinsicSize == null
              ? null
              : applyBoxFit(
                  BoxFit.contain,
                  Size(
                    intrinsicSize.width.toDouble(),
                    intrinsicSize.height.toDouble(),
                  ),
                  Size(viewportWidth, viewportHeight),
                ).destination;
          _logRenderPlanIfNeeded(
            source,
            viewportSize: Size(viewportWidth, viewportHeight),
            devicePixelRatio: devicePixelRatio,
            intrinsicSize: intrinsicSize,
            shouldWaitForIntrinsicSize: shouldWaitForIntrinsicSize,
            cacheSize: cacheSize,
            previewSize: previewSize,
            cacheHint: cacheHint,
            previewHint: previewHint,
            displaySize: displaySize,
            preferDirectRender: preferDirectRender,
          );

          return ImagePreviewZoomableViewport(
            minScale: _minScale,
            maxScale: _maxScale,
            enableWheelZoom: _isDesktopGallery,
            onZoomChanged: (isZoomed) =>
                _handleImageZoomChanged(pageIndex, isZoomed),
            onEdgePageRequest: (direction) =>
                _handleImageEdgePageRequest(pageIndex, direction),
            onReset: () => _markSceneGuideSeen(
              SceneMicroGuideId.attachmentGalleryControls,
            ),
            child: Center(
              child: displaySize == null
                  ? shouldWaitForIntrinsicSize
                        ? _buildLoadingIndicator(context)
                        : _buildImage(
                            source,
                            previewCacheWidth:
                                previewHint == null || previewHint.width == 0
                                ? null
                                : previewHint.width,
                            previewCacheHeight:
                                previewHint == null || previewHint.height == 0
                                ? null
                                : previewHint.height,
                            cacheWidth:
                                cacheHint == null || cacheHint.width == 0
                                ? null
                                : cacheHint.width,
                            cacheHeight:
                                cacheHint == null || cacheHint.height == 0
                                ? null
                                : cacheHint.height,
                            preferDirectRender: preferDirectRender,
                          )
                  : SizedBox(
                      key: Key('attachment_gallery_display_box_${source.id}'),
                      width: displaySize.width,
                      height: displaySize.height,
                      child: shouldWaitForIntrinsicSize
                          ? _buildLoadingIndicator(context)
                          : _buildImage(
                              source,
                              previewCacheWidth:
                                  previewHint == null || previewHint.width == 0
                                  ? null
                                  : previewHint.width,
                              previewCacheHeight:
                                  previewHint == null || previewHint.height == 0
                                  ? null
                                  : previewHint.height,
                              cacheWidth:
                                  cacheHint == null || cacheHint.width == 0
                                  ? null
                                  : cacheHint.width,
                              cacheHeight:
                                  cacheHint == null || cacheHint.height == 0
                                  ? null
                                  : cacheHint.height,
                              preferDirectRender: preferDirectRender,
                            ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _wrapGalleryPage(Widget child) {
    if (!_isDesktopGallery) return child;
    return ImagePreviewDesktopFrame(
      canGoPrevious: _hasPreviousPage,
      canGoNext: _hasNextPage,
      onPrevious: _showPreviousPage,
      onNext: _showNextPage,
      child: child,
    );
  }

  Widget _actionButton({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _busy ? null : onTap,
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    );
  }

  Widget _buildViewerCloseButton(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('desktop_media_preview_close_button'),
          customBorder: const CircleBorder(),
          onTap: _closeGallery,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImmersivePageLabel(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: DesktopWindowChromeSafeArea(
        contentExtendsIntoTitleBar: true,
        includeTop: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '${_index + 1}/${_items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageOnlyItems = _items
        .where((item) => item.isImage)
        .toList(growable: false);
    if (imageOnlyItems.length == _items.length) {
      return ImagePreviewGalleryBody(
        request: ImagePreviewOpenRequest(
          items: imageOnlyItems
              .map(
                (item) => _attachmentImageSourceToImagePreviewItem(item.image!),
              )
              .toList(growable: false),
          initialIndex: widget.initialIndex.clamp(
            0,
            imageOnlyItems.isEmpty ? 0 : imageOnlyItems.length - 1,
          ),
          onReplace: widget.onReplace == null
              ? null
              : (result) => widget.onReplace!.call(
                  EditedImageResult(
                    sourceId: result.sourceId,
                    filePath: result.filePath,
                    filename: result.filename,
                    mimeType: result.mimeType,
                    size: result.size,
                  ),
                ),
          enableDownload: widget.enableDownload,
          albumName: widget.albumName,
        ),
        isDesktopOverride: widget.isDesktopOverride,
        immersiveDesktopChrome: _usesImmersiveDesktopChrome,
        showViewerCloseButton: widget.showViewerCloseButton,
        onClose: widget.onClose,
      );
    }

    final current = _items.isEmpty ? null : _items[_index];
    final canEdit = widget.onReplace != null && (current?.isImage ?? false);
    final canDownload = widget.enableDownload && (current?.isImage ?? false);
    final sceneGuideState = ref.watch(sceneMicroGuideProvider);
    final showControlsGuide =
        current?.isImage == true &&
        sceneGuideState.loaded &&
        !sceneGuideState.isSeen(SceneMicroGuideId.attachmentGalleryControls);
    final controlsGuideMessage = _isDesktopGallery
        ? context
              .t
              .strings
              .legacy
              .msg_scene_micro_guide_gallery_controls_desktop
        : context
              .t
              .strings
              .legacy
              .msg_scene_micro_guide_gallery_controls_mobile;
    final useImmersiveDesktopChrome = _usesImmersiveDesktopChrome;
    final galleryBody = Stack(
      children: [
        PageView.builder(
          controller: _controller,
          physics: _isDesktopGallery || _isCurrentImageZoomed
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: _items.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            final item = _items[index];
            if (item.isVideo) {
              return _buildVideoPage(item.video!);
            }
            return _buildImagePage(item.image!, pageIndex: index);
          },
        ),
        Positioned(
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit)
                _actionButton(
                  onTap: _editCurrent,
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              if (canEdit && canDownload) const SizedBox(width: 12),
              if (canDownload)
                _actionButton(
                  onTap: _downloadCurrent,
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
        if (useImmersiveDesktopChrome) _buildImmersivePageLabel(context),
        if (useImmersiveDesktopChrome && widget.showViewerCloseButton)
          _buildViewerCloseButton(context),
        if (showControlsGuide)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 18,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SceneMicroGuideOverlayPill(
                message: controlsGuideMessage,
                onDismiss: () => _markSceneGuideSeen(
                  SceneMicroGuideId.attachmentGalleryControls,
                ),
              ),
            ),
          ),
      ],
    );
    final scaffold = _items.isEmpty
        ? useImmersiveDesktopChrome
              ? Scaffold(
                  backgroundColor: Colors.black,
                  body: Stack(
                    children: [
                      Center(
                        child: Text(
                          context.t.strings.legacy.msg_no_image_available,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      if (widget.showViewerCloseButton)
                        _buildViewerCloseButton(context),
                    ],
                  ),
                )
              : Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    automaticallyImplyLeading:
                        resolveDesktopRouteAutomaticallyImplyLeading(
                          context: context,
                          automaticallyImplyLeading: true,
                        ),
                  ),
                  body: Center(
                    child: Text(
                      context.t.strings.legacy.msg_no_image_available,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
        : useImmersiveDesktopChrome
        ? Scaffold(backgroundColor: Colors.black, body: galleryBody)
        : Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading:
                  resolveDesktopRouteAutomaticallyImplyLeading(
                    context: context,
                    automaticallyImplyLeading: true,
                  ),
              title: Text(
                '${_index + 1}/${_items.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            body: galleryBody,
          );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) => _handleGalleryKeyEvent(event),
      child: scaffold,
    );
  }
}

enum _EditAction { replace, saveLocal }
