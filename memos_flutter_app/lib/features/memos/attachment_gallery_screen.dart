import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_editor_plus/options.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../i18n/strings.g.dart';

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

class AttachmentGalleryScreen extends StatefulWidget {
  const AttachmentGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.onReplace,
    this.enableDownload = true,
    this.albumName = 'MemoFlow',
  });

  final List<AttachmentImageSource> images;
  final int initialIndex;
  final Future<void> Function(EditedImageResult result)? onReplace;
  final bool enableDownload;
  final String albumName;

  @override
  State<AttachmentGalleryScreen> createState() => _AttachmentGalleryScreenState();
}

class _AttachmentGalleryScreenState extends State<AttachmentGalleryScreen> {
  late final PageController _controller;
  int _index = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _index = safeIndex;
    _controller = PageController(initialPage: safeIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AttachmentImageSource get _current => widget.images[_index];

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

  Future<void> _saveBytesToGallery(Uint8List bytes, {required String name}) async {
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
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved_gallery,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_save_failed_2(e: e))),
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
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved_gallery,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_save_failed_2(e: e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadCurrent() async {
    final source = _current;
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
    await _saveFileToGallery(tempFile, name: p.basenameWithoutExtension(filename));
  }

  Future<void> _editCurrent() async {
    if (widget.onReplace == null) return;
    final source = _current;
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
          outputFormat: OutputFormat.jpeg,
        ),
      ),
    );
    if (!mounted) return;
    if (edited == null) return;

    final action = await showDialog<_EditAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.strings.legacy.msg_edit_completed),
        content: Text(
          context.t.strings.legacy.msg_choose_what_edited_image,
        ),
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

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_replace_image),
            content: Text(
              context.t.strings.legacy.msg_replacing_delete_original_attachment_continue,
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

  Widget _buildImage(AttachmentImageSource source) {
    final file = source.localFile;
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
      );
    }
    final url = source.imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        httpHeaders: source.headers,
        fit: BoxFit.contain,
        placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, _, _) => const Icon(Icons.broken_image, color: Colors.white),
      );
    }
    return const Icon(Icons.broken_image, color: Colors.white);
  }

  Widget _actionButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _busy ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.onReplace != null;
    if (widget.images.isEmpty) {
      return Scaffold(
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
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_index + 1}/${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final source = widget.images[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: _buildImage(source)),
              );
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
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                  ),
                if (canEdit && widget.enableDownload) const SizedBox(width: 12),
                if (widget.enableDownload)
                  _actionButton(
                    onTap: _downloadCurrent,
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _EditAction {
  replace,
  saveLocal,
}
