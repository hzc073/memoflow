import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/debug_ephemeral_storage.dart';
import 'compression_models.dart';

class CompressionCacheStore {
  static const String rootDirectoryName = 'image_compression_cache_v2';

  Directory? _cacheDir;

  Future<Directory> resolveRootDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final support = await resolveAppSupportDirectory();
    final dir = Directory(p.join(support.path, rootDirectoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<String> resolveOutputPath(
    String cacheKey,
    CompressionImageFormat outputFormat,
  ) async {
    final root = await resolveRootDirectory();
    return p.join(root.path, '$cacheKey.${_extensionFor(outputFormat)}');
  }

  Future<String> resolveManifestPath(String cacheKey) async {
    final root = await resolveRootDirectory();
    return p.join(root.path, '$cacheKey.json');
  }

  Future<CompressionCacheHit?> read(
    String cacheKey,
    CompressionImageFormat? outputFormat,
  ) async {
    final manifestPath = await resolveManifestPath(cacheKey);
    final manifestFile = File(manifestPath);
    if (!manifestFile.existsSync()) return null;
    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map) return null;
      final manifest = CompressionCacheManifest.fromJson(
        decoded.cast<String, dynamic>(),
      );
      final resolvedOutputFormat = outputFormat ?? manifest.outputFormat;
      final outputPath = resolvedOutputFormat == null
          ? ''
          : await resolveOutputPath(cacheKey, resolvedOutputFormat);
      return CompressionCacheHit(outputPath: outputPath, manifest: manifest);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeManifest(
    String cacheKey,
    CompressionCacheManifest manifest,
  ) async {
    final manifestPath = await resolveManifestPath(cacheKey);
    final file = File(manifestPath);
    await file.writeAsString(jsonEncode(manifest.toJson()), flush: true);
  }

  String extensionForFormat(CompressionImageFormat format) =>
      _extensionFor(format);

  String _extensionFor(CompressionImageFormat format) {
    return switch (format) {
      CompressionImageFormat.jpeg => 'jpg',
      CompressionImageFormat.png => 'png',
      CompressionImageFormat.webp => 'webp',
      CompressionImageFormat.tiff => 'tiff',
      CompressionImageFormat.gif => 'gif',
      CompressionImageFormat.bmp => 'bmp',
      CompressionImageFormat.heic => 'heic',
      CompressionImageFormat.heif => 'heif',
      CompressionImageFormat.unknown => 'bin',
    };
  }
}
