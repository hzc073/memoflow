import 'dart:async';
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

import '../../../core/image_error_logger.dart';
import '../../../core/image_formats.dart';
import '../../../core/scene_micro_guide_widgets.dart';
import '../../../core/top_toast.dart';
import '../../../data/logs/log_manager.dart';
import '../../../data/repositories/scene_micro_guide_repository.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/system/scene_micro_guide_provider.dart';
import '../image_preview_edit_result.dart';
import '../image_preview_item.dart';
import '../image_preview_metadata_resolver.dart';
import '../image_preview_open_request.dart';
import '_image_preview_desktop_frame.dart';
import '_image_preview_progressive_raster.dart';
import '_image_preview_zoomable_viewport.dart';

class ImagePreviewGalleryBody extends ConsumerStatefulWidget {
  const ImagePreviewGalleryBody({
    super.key,
    required this.request,
    this.isDesktopOverride,
    this.editResultOverride,
    this.editImageOverride,
    this.editActionOverride,
    this.confirmReplaceOverride,
  });

  final ImagePreviewOpenRequest request;
  final bool? isDesktopOverride;
  final Future<ImagePreviewEditResult?> Function()? editResultOverride;
  final Future<Uint8List?> Function(Uint8List imageBytes)? editImageOverride;
  final Future<ImagePreviewGalleryEditAction?> Function()? editActionOverride;
  final Future<bool> Function()? confirmReplaceOverride;

  @override
  ConsumerState<ImagePreviewGalleryBody> createState() =>
      ImagePreviewGalleryBodyState();
}

class ImagePreviewGalleryBodyState
    extends ConsumerState<ImagePreviewGalleryBody> {
  static const double _minScale = 1;
  static const double _maxScale = 4;
  static const Duration _pageAnimationDuration = Duration(milliseconds: 180);
  static const double _pendingPreviewTopBarHeight = 56;

  late final PageController _controller;
  late final FocusNode _focusNode;
  int _index = 0;
  bool _busy = false;
  final Set<int> _zoomedImageIndexes = <int>{};
  final Map<String, ImagePreviewRasterSize> _resolvedImageSizes =
      <String, ImagePreviewRasterSize>{};
  final Set<String> _resolvingImageSizes = <String>{};
  final Set<String> _failedImageSizeResolutions = <String>{};
  final Map<String, String> _loggedRenderPlanSignatures = <String, String>{};
  final Map<String, String> _loggedRenderModeSignatures = <String, String>{};

  bool get _isDesktopGallery =>
      widget.isDesktopOverride ??
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _isPendingPreviewContext =>
      !_isDesktopGallery &&
      _currentImage != null &&
      _isPendingPreviewItem(_currentImage!);

  bool get _hasPreviousPage => _index > 0;
  bool get _hasNextPage => _index < widget.request.items.length - 1;
  bool get _isCurrentImageZoomed => _zoomedImageIndexes.contains(_index);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'image_preview_gallery');
    final safeIndex = widget.request.items.isEmpty
        ? 0
        : widget.request.initialIndex.clamp(0, widget.request.items.length - 1);
    _index = safeIndex;
    _controller = PageController(initialPage: safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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
    if (widget.request.items.isEmpty) {
      return;
    }
    final nextIndex = targetIndex.clamp(0, widget.request.items.length - 1);
    if (nextIndex == _index) {
      return;
    }
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
    if (!mounted ||
        widget.request.items.isEmpty ||
        index < 0 ||
        index >= widget.request.items.length) {
      return;
    }
    final hasChanged = isZoomed
        ? _zoomedImageIndexes.add(index)
        : _zoomedImageIndexes.remove(index);
    if (!hasChanged) {
      return;
    }
    setState(() {});
  }

  void _handleImageEdgePageRequest(
    int index,
    ImagePreviewPageDirection direction,
  ) {
    if (!mounted || index != _index) {
      return;
    }
    _markSceneGuideSeen(SceneMicroGuideId.attachmentGalleryControls);
    switch (direction) {
      case ImagePreviewPageDirection.previous:
        _showPreviousPage();
      case ImagePreviewPageDirection.next:
        _showNextPage();
    }
  }

  void _closeGallery() {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      return;
    }
    navigator.maybePop();
  }

  void _markSceneGuideSeen(SceneMicroGuideId id) {
    unawaited(ref.read(sceneMicroGuideProvider.notifier).markSeen(id));
  }

  Map<String, Object?> _galleryLogContext(
    ImagePreviewItem item, {
    ImagePreviewRasterSize? intrinsicSize,
    Map<String, Object?>? extra,
  }) {
    return <String, Object?>{
      'itemId': item.id,
      'title': item.title,
      'mimeType': item.mimeType,
      'hasLocalFile': item.localFile != null,
      'hasImageUrl': (item.resolvedGalleryUrl?.trim().isNotEmpty ?? false),
      'metadataWidth': item.width,
      'metadataHeight': item.height,
      if (intrinsicSize != null) 'intrinsicWidth': intrinsicSize.width,
      if (intrinsicSize != null) 'intrinsicHeight': intrinsicSize.height,
      ...?extra,
    };
  }

  void _logRenderPlanIfNeeded(
    ImagePreviewItem item, {
    required Size viewportSize,
    required double devicePixelRatio,
    required ImagePreviewRasterSize? intrinsicSize,
    required bool shouldWaitForIntrinsicSize,
    required ImagePreviewRasterSize? cacheSize,
    required ImagePreviewRasterSize? previewSize,
    required ImagePreviewRasterSize? cacheHint,
    required ImagePreviewRasterSize? previewHint,
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
    final lastSignature = _loggedRenderPlanSignatures[item.id];
    if (lastSignature == signature) {
      return;
    }
    _loggedRenderPlanSignatures[item.id] = signature;
    LogManager.instance.debug(
      'ImagePreviewGallery: render_plan',
      context: _galleryLogContext(
        item,
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
    ImagePreviewItem item, {
    required bool preferDirectRender,
    required int? previewCacheWidth,
    required int? previewCacheHeight,
    required int? cacheWidth,
    required int? cacheHeight,
  }) {
    final hasLocalFile = item.localFile != null && item.localFile!.existsSync();
    final mode = preferDirectRender ? 'direct' : 'progressive';
    final signature =
        'mode=$mode'
        '|source=${hasLocalFile ? 'local' : 'remote'}'
        '|preview=${previewCacheWidth ?? 0}x${previewCacheHeight ?? 0}'
        '|cache=${cacheWidth ?? 0}x${cacheHeight ?? 0}';
    final lastSignature = _loggedRenderModeSignatures[item.id];
    if (lastSignature == signature) {
      return;
    }
    _loggedRenderModeSignatures[item.id] = signature;
    LogManager.instance.debug(
      'ImagePreviewGallery: render_mode',
      context: _galleryLogContext(
        item,
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

  ImagePreviewRasterSize? _resolvedIntrinsicSizeFor(ImagePreviewItem item) {
    return resolveImagePreviewKnownIntrinsicSize(item) ??
        _resolvedImageSizes[item.id];
  }

  bool _canResolveIntrinsicSize(ImagePreviewItem item) {
    if (_resolvedIntrinsicSizeFor(item) != null) {
      return false;
    }
    if (_failedImageSizeResolutions.contains(item.id)) {
      return false;
    }
    if (isSvgImagePreviewItem(item)) {
      return false;
    }
    return imagePreviewOriginalRasterProvider(item) != null;
  }

  void _scheduleIntrinsicSizeResolution(ImagePreviewItem item) {
    if (!_canResolveIntrinsicSize(item)) {
      return;
    }
    if (!_resolvingImageSizes.add(item.id)) {
      return;
    }
    LogManager.instance.debug(
      'ImagePreviewGallery: intrinsic_size_resolve_start',
      context: _galleryLogContext(item),
    );
    unawaited(() async {
      ImagePreviewRasterSize? fileResolved;
      final file = item.localFile;
      if (file != null && file.existsSync()) {
        try {
          final bytes = await file.readAsBytes();
          fileResolved = await compute(
            resolveImagePreviewDisplaySizeFromBytes,
            bytes,
          );
          LogManager.instance.debug(
            'ImagePreviewGallery: intrinsic_size_file_probe',
            context: _galleryLogContext(
              item,
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
            'ImagePreviewGallery: intrinsic_size_file_probe_failed',
            error: error,
            stackTrace: stackTrace,
            context: _galleryLogContext(
              item,
              extra: <String, Object?>{'filePath': file.path},
            ),
          );
        }
      }
      final providerResolved = await resolveImagePreviewIntrinsicSize(item);
      final resolved = chooseImagePreviewResolvedIntrinsicSize(
        fileResolved: fileResolved,
        providerResolved: providerResolved,
      );
      LogManager.instance.debug(
        'ImagePreviewGallery: intrinsic_size_resolve_complete',
        context: _galleryLogContext(
          item,
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
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvingImageSizes.remove(item.id);
        if (resolved != null) {
          _resolvedImageSizes[item.id] = resolved;
          _failedImageSizeResolutions.remove(item.id);
        } else {
          _failedImageSizeResolutions.add(item.id);
        }
      });
    }());
  }

  KeyEventResult _handleGalleryKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

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

  ImagePreviewItem? get _currentImage {
    if (widget.request.items.isEmpty) {
      return null;
    }
    return widget.request.items[_index];
  }

  bool _isPendingPreviewItem(ImagePreviewItem item) {
    return item.id.startsWith('pending:') ||
        item.id.startsWith('inline-pending:');
  }

  Future<Uint8List?> _loadBytes(ImagePreviewItem item) async {
    final file = item.localFile;
    if (file != null && file.existsSync()) {
      return file.readAsBytes();
    }
    final url = item.resolvedGalleryUrl?.trim() ?? '';
    if (url.isEmpty) {
      return null;
    }
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: item.headers,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = response.data;
    if (data == null) {
      return null;
    }
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
      if (flag is bool) {
        return flag;
      }
    }
    return result == true;
  }

  String _safeBaseName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'MemoFlow';
    }
    final base = p.basenameWithoutExtension(trimmed);
    if (base.trim().isEmpty) {
      return 'MemoFlow';
    }
    return base.replaceAll(RegExp(r'[<>:\"/\\\\|?*]'), '_');
  }

  String _editedFilename(ImagePreviewItem item) {
    final base = _safeBaseName(item.title);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${base}_edited_$stamp.jpg';
  }

  Future<ImagePreviewEditResult> _persistEditedImage(
    ImagePreviewItem item,
    Uint8List bytes,
  ) async {
    final dir = await getTemporaryDirectory();
    final filename = _editedFilename(item);
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
    return ImagePreviewEditResult(
      sourceId: item.id,
      filePath: path,
      filename: filename,
      mimeType: 'image/jpeg',
      size: size,
    );
  }

  Uint8List _reencodeJpeg(Uint8List bytes, {int quality = 90}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return bytes;
    }
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
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final allowed = await _ensureGalleryPermission();
      if (!allowed) {
        if (!mounted) {
          return;
        }
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
        albumName: widget.request.albumName,
      );
      final ok = _isGallerySaveSuccess(result);
      if (!mounted) {
        return;
      }
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_save_failed)),
        );
        return;
      }
      showTopToast(context, context.t.strings.legacy.msg_saved_gallery);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveFileToGallery(File file, {required String name}) async {
    if (_isDesktopGallery) {
      await _saveFileToDesktop(file, suggestedName: name);
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final allowed = await _ensureGalleryPermission();
      if (!allowed) {
        if (!mounted) {
          return;
        }
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
        albumName: widget.request.albumName,
      );
      final ok = _isGallerySaveSuccess(result);
      if (!mounted) {
        return;
      }
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_save_failed)),
        );
        return;
      }
      showTopToast(context, context.t.strings.legacy.msg_saved_gallery);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadCurrent() async {
    final item = _currentImage;
    if (item == null) {
      return;
    }
    final file = item.localFile;
    if (file != null && file.existsSync()) {
      final base = _safeBaseName(item.title);
      await _saveFileToGallery(file, name: base);
      return;
    }

    final bytes = await _loadBytes(item);
    if (bytes == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_unable_open_photo)),
      );
      return;
    }

    final ext = p.extension(item.title).replaceAll('.', '');
    final name = _safeBaseName(item.title);
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
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final targetPath = await _pickDesktopSavePath(
        suggestedName: suggestedName,
      );
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved(targetPath: outFile.path),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveFileToDesktop(
    File file, {
    required String suggestedName,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ext = p.extension(file.path);
      final hasExt = p.extension(suggestedName).isNotEmpty;
      final fileName = hasExt ? suggestedName : '$suggestedName$ext';
      final targetPath = await _pickDesktopSavePath(suggestedName: fileName);
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved(targetPath: outFile.path),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Uint8List?> _openImageEditor(Uint8List bytes) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageEditor(
          image: bytes,
          outputFormat: editor_options.OutputFormat.jpeg,
        ),
      ),
    );
  }

  Future<ImagePreviewGalleryEditAction?> _promptEditAction() {
    return showDialog<ImagePreviewGalleryEditAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.strings.legacy.msg_edit_completed),
        content: Text(context.t.strings.legacy.msg_choose_what_edited_image),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(ImagePreviewGalleryEditAction.saveLocal),
            child: Text(context.t.strings.legacy.msg_save_gallery),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(ImagePreviewGalleryEditAction.replace),
            child: Text(context.t.strings.legacy.msg_replace_memo_image),
          ),
        ],
      ),
    );
  }

  Future<bool> _promptReplaceConfirmation() async {
    return await showDialog<bool>(
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
  }

  Future<void> _editCurrent() async {
    if (widget.request.onReplace == null) {
      return;
    }
    final item = _currentImage;
    if (item == null) {
      return;
    }
    if (widget.editResultOverride != null) {
      final result = await widget.editResultOverride!.call();
      if (!context.mounted || result == null) {
        return;
      }
      await widget.request.onReplace?.call(result);
      return;
    }
    final bytes = await _loadBytes(item);
    if (bytes == null) {
      if (!context.mounted) {
        return;
      }
      final currentContext = context;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text(currentContext.t.strings.legacy.msg_unable_open_photo),
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    final edited = widget.editImageOverride != null
        ? await widget.editImageOverride!.call(bytes)
        : await _openImageEditor(bytes);
    if (!context.mounted || edited == null) {
      return;
    }

    final action = widget.editActionOverride != null
        ? await widget.editActionOverride!.call()
        : await _promptEditAction();
    if (!context.mounted || action == null) {
      return;
    }

    final encoded = _reencodeJpeg(edited, quality: 90);
    if (action == ImagePreviewGalleryEditAction.saveLocal) {
      final name = _safeBaseName(item.title);
      await _saveBytesToGallery(encoded, name: '${name}_edited');
      return;
    }

    final confirmed = widget.confirmReplaceOverride != null
        ? await widget.confirmReplaceOverride!.call()
        : await _promptReplaceConfirmation();
    if (!context.mounted || !confirmed) {
      return;
    }

    final result = await _persistEditedImage(item, encoded);
    await widget.request.onReplace?.call(result);
  }

  Future<void> triggerEditForTesting() => _editCurrent();

  Widget _buildLoadingIndicator(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildImage(
    ImagePreviewItem item, {
    int? previewCacheWidth,
    int? previewCacheHeight,
    int? cacheWidth,
    int? cacheHeight,
    bool preferDirectRender = false,
  }) {
    _logRenderModeIfNeeded(
      item,
      preferDirectRender: preferDirectRender,
      previewCacheWidth: previewCacheWidth,
      previewCacheHeight: previewCacheHeight,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
    final file = item.localFile;
    if (file != null && file.existsSync()) {
      final isSvg = shouldUseSvgRenderer(
        url: file.path,
        mimeType: item.mimeType,
      );
      if (isSvg) {
        return SvgPicture.file(
          file,
          fit: BoxFit.contain,
          placeholderBuilder: _buildLoadingIndicator,
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'image_preview_gallery_local_svg',
              source: file.path,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'itemId': item.id,
                'mimeType': item.mimeType,
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
              alignment: Alignment.center,
              children: [
                _buildLoadingIndicator(context),
                child,
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'image_preview_gallery_local_direct',
              source: file.path,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'itemId': item.id,
                'mimeType': item.mimeType,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      return ImagePreviewProgressiveRaster(
        debugTag: item.id,
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
            scope: 'image_preview_gallery_local',
            source: file.path,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'itemId': item.id,
              'mimeType': item.mimeType,
              'phase': 'preview',
            },
          );
        },
        onHighResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'image_preview_gallery_local',
            source: file.path,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'itemId': item.id,
              'mimeType': item.mimeType,
              'phase': 'full',
            },
          );
        },
      );
    }

    final url = item.resolvedGalleryUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      final isSvg = shouldUseSvgRenderer(url: url, mimeType: item.mimeType);
      if (isSvg) {
        return SvgPicture.network(
          url,
          headers: item.headers,
          fit: BoxFit.contain,
          placeholderBuilder: _buildLoadingIndicator,
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'image_preview_gallery_network_svg',
              source: url,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'itemId': item.id,
                'mimeType': item.mimeType,
                'hasAuthHeader':
                    item.headers?['Authorization']?.trim().isNotEmpty ?? false,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      if (preferDirectRender) {
        return Image(
          image: CachedNetworkImageProvider(url, headers: item.headers),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildLoadingIndicator(context),
                child,
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: 'image_preview_gallery_network_direct',
              source: url,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'itemId': item.id,
                'mimeType': item.mimeType,
                'hasAuthHeader':
                    item.headers?['Authorization']?.trim().isNotEmpty ?? false,
              },
            );
            return const Icon(Icons.broken_image, color: Colors.white);
          },
        );
      }
      return ImagePreviewProgressiveRaster(
        debugTag: item.id,
        lowResImage: CachedNetworkImageProvider(
          url,
          headers: item.headers,
          maxWidth: previewCacheWidth,
          maxHeight: previewCacheHeight,
        ),
        highResImage: CachedNetworkImageProvider(
          url,
          headers: item.headers,
          maxWidth: cacheWidth,
          maxHeight: cacheHeight,
        ),
        fit: BoxFit.contain,
        loadingBuilder: _buildLoadingIndicator,
        onLowResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'image_preview_gallery_network',
            source: url,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'itemId': item.id,
              'mimeType': item.mimeType,
              'hasAuthHeader':
                  item.headers?['Authorization']?.trim().isNotEmpty ?? false,
              'phase': 'preview',
            },
          );
        },
        onHighResError: (error, stackTrace) {
          logImageLoadError(
            scope: 'image_preview_gallery_network',
            source: url,
            error: error,
            stackTrace: stackTrace,
            extraContext: <String, Object?>{
              'itemId': item.id,
              'mimeType': item.mimeType,
              'hasAuthHeader':
                  item.headers?['Authorization']?.trim().isNotEmpty ?? false,
              'phase': 'full',
            },
          );
        },
      );
    }
    return const Icon(Icons.broken_image, color: Colors.white);
  }

  Widget _buildImagePage(ImagePreviewItem item, {required int pageIndex}) {
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
          final intrinsicSize = _resolvedIntrinsicSizeFor(item);
          final shouldWaitForIntrinsicSize =
              intrinsicSize == null && _canResolveIntrinsicSize(item);
          if (shouldWaitForIntrinsicSize) {
            _scheduleIntrinsicSizeResolution(item);
          }
          final cacheSize = intrinsicSize == null
              ? null
              : resolveImagePreviewDecodeSize(
                  Size(
                    intrinsicSize.width.toDouble(),
                    intrinsicSize.height.toDouble(),
                  ),
                  Size(viewportWidth, viewportHeight),
                  devicePixelRatio,
                  isDesktop: _isDesktopGallery,
                );
          final previewSize = resolveImagePreviewPreviewSize(
            cacheSize,
            isDesktop: _isDesktopGallery,
          );
          final cacheHint = cacheSize == null
              ? null
              : resolveImagePreviewDecodeHint(cacheSize);
          final previewHint = previewSize == null
              ? null
              : resolveImagePreviewDecodeHint(previewSize);
          final preferDirectRender =
              shouldUseDirectImagePreviewRender(intrinsicSize);
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
            item,
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
                            item,
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
                      key: Key('image_preview_display_box_${item.id}'),
                      width: displaySize.width,
                      height: displaySize.height,
                      child: shouldWaitForIntrinsicSize
                          ? _buildLoadingIndicator(context)
                          : _buildImage(
                              item,
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
    if (!_isDesktopGallery) {
      return child;
    }
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

  Widget _buildPendingPreviewTopBar(BuildContext context) {
    final pageLabel = '${_index + 1}/${widget.request.items.length}';
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _pendingPreviewTopBarHeight,
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _closeGallery,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Text(
                pageLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPreviewChrome(BuildContext context) {
    return _buildPendingPreviewTopBar(context);
  }

  Widget _buildGalleryActionButtons({
    required bool canEdit,
    required bool canDownload,
  }) {
    return Row(
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
    );
  }

  Widget _buildPendingPreviewActionDock({
    required bool canEdit,
    required bool canDownload,
  }) {
    if (!canEdit && !canDownload) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _buildGalleryActionButtons(
            canEdit: canEdit,
            canDownload: canDownload,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPreviewCloseButton(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: Material(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('pending_preview_close_button'),
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

  Widget _buildDefaultActionDock({
    required bool canEdit,
    required bool canDownload,
  }) {
    return Positioned(
      right: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: _buildGalleryActionButtons(
        canEdit: canEdit,
        canDownload: canDownload,
      ),
    );
  }

  Widget _buildGalleryViewport({
    required bool canEdit,
    required bool canDownload,
    required bool showControlsGuide,
    required String controlsGuideMessage,
    required bool usePendingPreviewChrome,
  }) {
    final hasFloatingActions = canEdit || canDownload;
    final guideBottom =
        MediaQuery.paddingOf(context).bottom +
        (usePendingPreviewChrome && hasFloatingActions ? 84 : 18);
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          physics: _isDesktopGallery || _isCurrentImageZoomed
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: widget.request.items.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) =>
              _buildImagePage(widget.request.items[index], pageIndex: index),
        ),
        if (hasFloatingActions)
          if (usePendingPreviewChrome)
            _buildPendingPreviewActionDock(
              canEdit: canEdit,
              canDownload: canDownload,
            )
          else
            _buildDefaultActionDock(canEdit: canEdit, canDownload: canDownload),
        if (usePendingPreviewChrome) _buildPendingPreviewCloseButton(context),
        if (showControlsGuide)
          Positioned(
            left: 16,
            right: 16,
            bottom: guideBottom,
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
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentImage;
    final canEdit = widget.request.onReplace != null && current != null;
    final canDownload = widget.request.enableDownload && current != null;
    final sceneGuideState = ref.watch(sceneMicroGuideProvider);
    final showControlsGuide =
        current != null &&
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
    final usePendingPreviewChrome = _isPendingPreviewContext;
    final scaffold = widget.request.items.isEmpty
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
        : usePendingPreviewChrome
        ? Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                _buildPendingPreviewChrome(context),
                Expanded(
                  child: _buildGalleryViewport(
                    canEdit: canEdit,
                    canDownload: canDownload,
                    showControlsGuide: showControlsGuide,
                    controlsGuideMessage: controlsGuideMessage,
                    usePendingPreviewChrome: true,
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                '${_index + 1}/${widget.request.items.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            body: _buildGalleryViewport(
              canEdit: canEdit,
              canDownload: canDownload,
              showControlsGuide: showControlsGuide,
              controlsGuideMessage: controlsGuideMessage,
              usePendingPreviewChrome: false,
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

enum ImagePreviewGalleryEditAction { replace, saveLocal }
