import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

import '../../core/image_formats.dart';
import '../../core/image_error_logger.dart';
import '../../core/scene_micro_guide_widgets.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import 'attachment_video_screen.dart';
import 'memo_video_grid.dart';

const double _galleryDecodeOverscan = 1.5;
const int _galleryMobileMaxDecodePx = 1920;
const int _galleryDesktopMaxDecodePx = 1920;
const double _galleryPreviewDecodeFactor = 0.5;
const int _galleryMobilePreviewMaxDecodePx = 960;
const int _galleryDesktopPreviewMaxDecodePx = 1440;

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

class AttachmentImageSource {
  const AttachmentImageSource({
    required this.id,
    required this.title,
    required this.mimeType,
    this.localFile,
    this.imageUrl,
    this.headers,
  });

  final String id;
  final String title;
  final String mimeType;
  final File? localFile;
  final String? imageUrl;
  final Map<String, String>? headers;
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

class AttachmentGalleryScreen extends ConsumerStatefulWidget {
  const AttachmentGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.items,
    this.onReplace,
    this.enableDownload = true,
    this.albumName = 'MemoFlow',
  });

  final List<AttachmentImageSource> images;
  final List<AttachmentGalleryItem>? items;
  final int initialIndex;
  final Future<void> Function(EditedImageResult result)? onReplace;
  final bool enableDownload;
  final String albumName;

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

  bool get _isDesktopGallery =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _hasPreviousPage => _index > 0;
  bool get _hasNextPage => _index < _items.length - 1;

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

  void _closeGallery() {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.maybePop();
  }

  void _markSceneGuideSeen(SceneMicroGuideId id) {
    unawaited(ref.read(sceneMicroGuideProvider.notifier).markSeen(id));
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
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
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
  }) {
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
      return _AttachmentGalleryProgressiveRaster(
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
      return _AttachmentGalleryProgressiveRaster(
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

  Widget _buildImagePage(AttachmentImageSource source) {
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
          final cacheWidth = resolveAttachmentGalleryCacheExtent(
            viewportWidth,
            devicePixelRatio,
            isDesktop: _isDesktopGallery,
          );
          final cacheHeight = resolveAttachmentGalleryCacheExtent(
            viewportHeight,
            devicePixelRatio,
            isDesktop: _isDesktopGallery,
          );
          final previewCacheWidth = resolveAttachmentGalleryPreviewExtent(
            cacheWidth,
            isDesktop: _isDesktopGallery,
          );
          final previewCacheHeight = resolveAttachmentGalleryPreviewExtent(
            cacheHeight,
            isDesktop: _isDesktopGallery,
          );

          return _AttachmentGalleryZoomableImage(
            minScale: _minScale,
            maxScale: _maxScale,
            enableWheelZoom: _isDesktopGallery,
            onReset: () => _markSceneGuideSeen(
              SceneMicroGuideId.attachmentGalleryControls,
            ),
            child: Center(
              child: _buildImage(
                source,
                previewCacheWidth: previewCacheWidth,
                previewCacheHeight: previewCacheHeight,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wrapGalleryPage(Widget child) {
    if (!_isDesktopGallery) return child;
    return _AttachmentGalleryDesktopFrame(
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

  @override
  Widget build(BuildContext context) {
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
    final scaffold = _items.isEmpty
        ? Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Text(
                context.t.strings.legacy.msg_no_image_available,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          )
        : Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                '${_index + 1}/${_items.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            body: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  physics: _isDesktopGallery
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: _items.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    if (item.isVideo) {
                      return _buildVideoPage(item.video!);
                    }
                    return _buildImagePage(item.image!);
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
            ),
          );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) => _handleGalleryKeyEvent(event),
      child: scaffold,
    );
  }
}

class _AttachmentGalleryProgressiveRaster extends StatefulWidget {
  const _AttachmentGalleryProgressiveRaster({
    required this.lowResImage,
    required this.highResImage,
    required this.fit,
    required this.loadingBuilder,
    this.onLowResError,
    this.onHighResError,
  });

  final ImageProvider lowResImage;
  final ImageProvider highResImage;
  final BoxFit fit;
  final WidgetBuilder loadingBuilder;
  final ImageErrorListener? onLowResError;
  final ImageErrorListener? onHighResError;

  @override
  State<_AttachmentGalleryProgressiveRaster> createState() =>
      _AttachmentGalleryProgressiveRasterState();
}

class _AttachmentGalleryProgressiveRasterState
    extends State<_AttachmentGalleryProgressiveRaster> {
  bool _lowResReady = false;
  bool _highResReady = false;
  bool _lowResFailed = false;
  bool _highResAttempted = false;

  void _markLowResReady() {
    if (!mounted || _lowResReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lowResReady) return;
      setState(() {
        _lowResReady = true;
        _highResAttempted = true;
      });
    });
  }

  void _markHighResReady() {
    if (!mounted || _highResReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _highResReady) return;
      setState(() => _highResReady = true);
    });
  }

  void _markLowResFailed() {
    if (!mounted || _lowResFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lowResFailed) return;
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
      return Stack(
        alignment: Alignment.center,
        children: [
          if (!_lowResReady && !_lowResFailed) widget.loadingBuilder(context),
          lowResImage,
        ],
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

    return Stack(
      alignment: Alignment.center,
      children: [
        if (!_lowResReady && !_lowResFailed) widget.loadingBuilder(context),
        if (!_lowResFailed) lowResImage,
        if (_highResAttempted) highResImage,
      ],
    );
  }
}

class _AttachmentGalleryZoomableImage extends StatefulWidget {
  const _AttachmentGalleryZoomableImage({
    required this.child,
    required this.minScale,
    required this.maxScale,
    required this.enableWheelZoom,
    this.onReset,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final bool enableWheelZoom;
  final VoidCallback? onReset;

  @override
  State<_AttachmentGalleryZoomableImage> createState() =>
      _AttachmentGalleryZoomableImageState();
}

class _AttachmentGalleryZoomableImageState
    extends State<_AttachmentGalleryZoomableImage> {
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.enableWheelZoom || event is! PointerScrollEvent) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final scaleDelta = math.exp(-event.scrollDelta.dy / 240);
    final nextScale = (currentScale * scaleDelta).clamp(
      widget.minScale,
      widget.maxScale,
    );
    if ((nextScale - currentScale).abs() < 0.001) return;

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

  void _resetTransform() {
    _transformationController.value = Matrix4.identity();
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = InteractiveViewer(
      transformationController: _transformationController,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      trackpadScrollCausesScale: widget.enableWheelZoom,
      child: widget.child,
    );

    final resettableViewer = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _resetTransform,
      child: viewer,
    );

    if (!widget.enableWheelZoom) return resettableViewer;
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: resettableViewer,
    );
  }
}

class _AttachmentGalleryDesktopFrame extends StatelessWidget {
  const _AttachmentGalleryDesktopFrame({
    required this.child,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final edgeWidth = math.max(
                  96.0,
                  math.min(180.0, constraints.maxWidth * 0.24),
                );
                return Row(
                  children: [
                    SizedBox(
                      width: edgeWidth,
                      child: _AttachmentGalleryDesktopHotspot(
                        alignment: Alignment.centerLeft,
                        icon: Icons.chevron_left_rounded,
                        enabled: canGoPrevious,
                        onTap: onPrevious,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: edgeWidth,
                      child: _AttachmentGalleryDesktopHotspot(
                        alignment: Alignment.centerRight,
                        icon: Icons.chevron_right_rounded,
                        enabled: canGoNext,
                        onTap: onNext,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentGalleryDesktopHotspot extends StatefulWidget {
  const _AttachmentGalleryDesktopHotspot({
    required this.alignment,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final Alignment alignment;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_AttachmentGalleryDesktopHotspot> createState() =>
      _AttachmentGalleryDesktopHotspotState();
}

class _AttachmentGalleryDesktopHotspotState
    extends State<_AttachmentGalleryDesktopHotspot> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final leadingEdge = widget.alignment == Alignment.centerLeft;
    final buttonOpacity = widget.enabled ? (_hovered ? 1.0 : 0.34) : 0.0;
    final edgeOpacity = widget.enabled ? (_hovered ? 0.22 : 0.0) : 0.0;
    final slideOffset = _hovered
        ? Offset.zero
        : Offset(leadingEdge ? -0.08 : 0.08, 0);

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (widget.enabled) _setHovered(true);
      },
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.enabled ? widget.onTap : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: edgeOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: leadingEdge
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: leadingEdge
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.58),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: widget.alignment,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: slideOffset,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  scale: _hovered ? 1.0 : 0.94,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: buttonOpacity,
                    child: IgnorePointer(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: _hovered ? 0.52 : 0.34,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: _hovered ? 0.24 : 0.1,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _hovered ? 0.22 : 0.08,
                              ),
                              blurRadius: _hovered ? 18 : 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white.withValues(
                            alpha: _hovered ? 1.0 : 0.86,
                          ),
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EditAction { replace, saveLocal }
