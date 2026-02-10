import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/url.dart';
import '../../core/video_thumbnail_cache.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/attachment.dart';
import 'attachment_video_screen.dart';

class MemoVideoEntry {
  const MemoVideoEntry({
    required this.id,
    required this.title,
    required this.mimeType,
    required this.size,
    this.localFile,
    this.videoUrl,
    this.headers,
  });

  final String id;
  final String title;
  final String mimeType;
  final int size;
  final File? localFile;
  final String? videoUrl;
  final Map<String, String>? headers;
}

List<MemoVideoEntry> collectMemoVideoEntries({
  required List<Attachment> attachments,
  required Uri? baseUrl,
  required String? authHeader,
}) {
  final entries = <MemoVideoEntry>[];
  final seen = <String>{};

  for (final attachment in attachments) {
    final type = attachment.type.trim().toLowerCase();
    if (!type.startsWith('video')) continue;
    final entry = memoVideoEntryFromAttachment(attachment, baseUrl, authHeader);
    if (entry == null) continue;
    final key = (entry.localFile?.path ?? entry.videoUrl ?? entry.id).trim();
    if (key.isEmpty || !seen.add(key)) continue;
    entries.add(entry);
  }

  return entries;
}

MemoVideoEntry? memoVideoEntryFromAttachment(
  Attachment attachment,
  Uri? baseUrl,
  String? authHeader,
) {
  final external = attachment.externalLink.trim();
  final localFile = _resolveLocalFile(external);
  final mimeType = attachment.type.trim().isEmpty ? 'video/*' : attachment.type.trim();
  final title = attachment.filename.trim().isNotEmpty ? attachment.filename.trim() : attachment.uid;

  if (localFile != null) {
    return MemoVideoEntry(
      id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
      title: title.isEmpty ? 'video' : title,
      mimeType: mimeType,
      size: attachment.size,
      localFile: localFile,
      videoUrl: null,
      headers: null,
    );
  }

  if (external.isNotEmpty) {
    final isAbsolute = isAbsoluteUrl(external);
    final resolved = resolveMaybeRelativeUrl(baseUrl, external);
    final headers = _authHeadersForUrl(
      resolved,
      baseUrl: baseUrl,
      isAbsolute: isAbsolute,
      authHeader: authHeader,
    );
    return MemoVideoEntry(
      id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
      title: title.isEmpty ? _titleFromUrl(external) : title,
      mimeType: mimeType,
      size: attachment.size,
      videoUrl: resolved,
      headers: headers,
    );
  }

  if (baseUrl == null) return null;
  final name = attachment.name.trim();
  final filename = attachment.filename.trim();
  if (name.isEmpty || filename.isEmpty) return null;
  final videoUrl = joinBaseUrl(baseUrl, 'file/$name/$filename');
  final headers = _authHeadersForUrl(
    videoUrl,
    baseUrl: baseUrl,
    isAbsolute: true,
    authHeader: authHeader,
  );
  return MemoVideoEntry(
    id: name,
    title: title.isEmpty ? filename : title,
    mimeType: mimeType,
    size: attachment.size,
    videoUrl: videoUrl,
    headers: headers,
  );
}

File? _resolveLocalFile(String externalLink) {
  if (!externalLink.startsWith('file://')) return null;
  final uri = Uri.tryParse(externalLink);
  if (uri == null) return null;
  final path = uri.toFilePath();
  if (path.trim().isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return file;
}

String _titleFromUrl(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return 'video';
  final segments = parsed.pathSegments;
  if (segments.isEmpty) return 'video';
  final last = segments.last.trim();
  return last.isEmpty ? 'video' : last;
}

Map<String, String>? _authHeadersForUrl(
  String url, {
  required Uri? baseUrl,
  required bool isAbsolute,
  required String? authHeader,
}) {
  final trimmed = authHeader?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (!isAbsolute) {
    return {'Authorization': trimmed};
  }
  if (baseUrl == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  final basePort = baseUrl.hasPort ? baseUrl.port : null;
  final uriPort = uri.hasPort ? uri.port : null;
  if (uri.scheme != baseUrl.scheme || uri.host != baseUrl.host || uriPort != basePort) {
    return null;
  }
  return {'Authorization': trimmed};
}

class AttachmentVideoThumbnail extends StatefulWidget {
  const AttachmentVideoThumbnail({
    super.key,
    required this.entry,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.showPlayIcon = true,
  });

  final MemoVideoEntry entry;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final bool showPlayIcon;

  @override
  State<AttachmentVideoThumbnail> createState() => _AttachmentVideoThumbnailState();
}

class _VideoThumbPayload {
  const _VideoThumbPayload({this.bytes, this.file});

  final Uint8List? bytes;
  final File? file;
}

class _AttachmentVideoThumbnailState extends State<AttachmentVideoThumbnail> {
  Uint8List? _bytes;
  File? _file;
  bool _loading = false;
  bool _loggedBuild = false;
  String _entryKey = '';
  int _loadToken = 0;
  Timer? _retryTimer;
  int _retryCount = 0;

  static const int _maxRetries = 4;
  static const Duration _retryBaseDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _startLoad(widget.entry);
  }

  @override
  void didUpdateWidget(covariant AttachmentVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameEntry(oldWidget.entry, widget.entry)) {
      _startLoad(widget.entry);
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  bool _isSameEntry(MemoVideoEntry a, MemoVideoEntry b) {
    return a.id == b.id &&
        a.size == b.size &&
        a.videoUrl == b.videoUrl &&
        a.localFile?.path == b.localFile?.path;
  }

  void _startLoad(MemoVideoEntry entry) {
    _entryKey = _buildEntryKey(entry);
    _bytes = null;
    _file = null;
    _loading = true;
    _retryCount = 0;
    _retryTimer?.cancel();
    final token = ++_loadToken;
    _load(entry, token);
  }

  String _buildEntryKey(MemoVideoEntry entry) {
    final source = (entry.localFile?.path ?? entry.videoUrl ?? '').trim();
    return '${entry.id}|${entry.size}|$source';
  }

  Future<void> _load(MemoVideoEntry entry, int token) async {
    try {
      final file = await VideoThumbnailCache.getThumbnailFile(
        id: entry.id,
        size: entry.size,
        localFile: entry.localFile,
        videoUrl: entry.videoUrl,
        headers: entry.headers,
      ).timeout(const Duration(seconds: 12));
      if (!mounted || token != _loadToken) return;
      setState(() {
        _file = file;
        _loading = false;
      });
      if (file == null || !file.existsSync() || file.lengthSync() == 0) {
        _scheduleRetry(entry, token);
      }
      assert(() {
        final hasFile = _file != null && _file!.existsSync() && _file!.lengthSync() > 0;
        debugPrint(
          'Video thumbnail widget result | {entry: $_entryKey, hasBytes: false, bytes: 0, hasFile: $hasFile, fileBytes: ${hasFile ? _file?.lengthSync() ?? 0 : 0}}',
        );
        return true;
      }());
    } catch (e, stackTrace) {
      if (!mounted || token != _loadToken) return;
      LogManager.instance.warn(
        'Video thumbnail load failed',
        error: e,
        stackTrace: stackTrace,
        context: {
          'entry': _entryKey,
        },
      );
      setState(() => _loading = false);
      _scheduleRetry(entry, token);
      assert(() {
        debugPrint('Video thumbnail widget result | {entry: $_entryKey, error: $e}');
        return true;
      }());
      return;
    }

    // Try to read bytes after the file is ready to avoid blocking the preview.
    try {
      final bytes = await VideoThumbnailCache.getThumbnailBytes(
        id: entry.id,
        size: entry.size,
        localFile: entry.localFile,
        videoUrl: entry.videoUrl,
        headers: entry.headers,
      ).timeout(const Duration(seconds: 8));
      if (!mounted || token != _loadToken) return;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() => _bytes = bytes);
        assert(() {
          debugPrint(
            'Video thumbnail widget bytes ready | {entry: $_entryKey, bytes: ${bytes.length}}',
          );
          return true;
        }());
      }
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      // Ignore byte read errors; file preview is already shown.
    }
  }

  void _scheduleRetry(MemoVideoEntry entry, int token) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    final delay = Duration(
      milliseconds: _retryBaseDelay.inMilliseconds * (1 << _retryCount),
    );
    _retryCount++;
    _retryTimer = Timer(delay, () {
      if (!mounted || token != _loadToken) return;
      setState(() => _loading = true);
      _load(entry, token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final width = widget.width;
    final height = widget.height;
    final borderRadius = widget.borderRadius;
    final fit = widget.fit;
    final showPlayIcon = widget.showPlayIcon;
    if (!_loggedBuild) {
      _loggedBuild = true;
      assert(() {
        debugPrint('Video thumbnail widget build | $_entryKey');
        return true;
      }());
    }

    Widget placeholder({IconData icon = Icons.videocam_outlined}) {
      return Container(
        width: width,
        height: height,
        color: Colors.black.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
      );
    }

    final bytes = _bytes;
    final file = _file;
    final hasBytes = bytes != null && bytes.isNotEmpty;
    final hasFile = file != null && file.existsSync() && file.lengthSync() > 0;

    Widget image;
    if (hasBytes) {
      final imageKey = ValueKey('${_entryKey}|${bytes!.length}');
      image = Image.memory(
        bytes,
        key: imageKey,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          LogManager.instance.warn(
            'Video thumbnail decode failed',
            error: error,
            stackTrace: stackTrace,
            context: {
              'id': entry.id,
              'bytes': bytes.length,
            },
          );
          return placeholder(icon: Icons.broken_image_outlined);
        },
      );
    } else if (hasFile) {
      final tag = '${file!.path}|${file.lengthSync()}';
      image = Image.file(
        file,
        key: ValueKey(tag),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          LogManager.instance.warn(
            'Video thumbnail file decode failed',
            error: error,
            stackTrace: stackTrace,
            context: {
              'id': entry.id,
              'path': file.path,
            },
          );
          return placeholder(icon: Icons.broken_image_outlined);
        },
      );
    } else {
      image = placeholder(icon: _loading ? Icons.hourglass_empty : Icons.videocam_outlined);
    }

    if (!showPlayIcon) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }
    final hasPreview = hasBytes || hasFile;
    if (!hasPreview) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoVideoGrid extends StatelessWidget {
  const MemoVideoGrid({
    super.key,
    required this.videos,
    this.columns = 3,
    this.maxCount,
    this.maxHeight,
    this.radius = 10,
    this.spacing = 8,
  });

  final List<MemoVideoEntry> videos;
  final int columns;
  final int? maxCount;
  final double? maxHeight;
  final double radius;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();
    final total = videos.length;
    final visibleCount = maxCount == null ? total : math.min(maxCount!, total);
    final overflow = total - visibleCount;
    final visible = videos.take(visibleCount).toList(growable: false);

    void openVideo(MemoVideoEntry entry) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentVideoScreen(
            title: entry.title,
            localFile: entry.localFile,
            videoUrl: entry.videoUrl,
            headers: entry.headers,
            cacheId: entry.id,
            cacheSize: entry.size,
          ),
        ),
      );
    }

    Widget buildTile(MemoVideoEntry entry, int index) {
      final overlay = (overflow > 0 && index == visibleCount - 1)
          ? Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                '+$overflow',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
          : null;

      return GestureDetector(
        onTap: () => openVideo(entry),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AttachmentVideoThumbnail(entry: entry, borderRadius: radius),
              if (overlay != null) overlay,
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawWidth = constraints.maxWidth;
        final maxWidth = rawWidth.isFinite && rawWidth > 0 ? rawWidth : MediaQuery.of(context).size.width;
        final totalSpacing = spacing * (columns - 1);
        final tileWidth = (maxWidth - totalSpacing) / columns;
        var tileHeight = tileWidth;

        if (maxHeight != null && visibleCount > 0) {
          final rows = (visibleCount / columns).ceil();
          final available = maxHeight! - spacing * (rows - 1);
          if (available > 0) {
            final target = available / rows;
            if (target.isFinite && target > 0 && target < tileHeight) {
              tileHeight = target;
            }
          }
        }

        final aspectRatio = tileWidth > 0 && tileHeight > 0 ? tileWidth / tileHeight : 1.0;
        return GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) => buildTile(visible[index], index),
        );
      },
    );
  }
}
