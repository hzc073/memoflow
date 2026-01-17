import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class SystemFontInfo {
  const SystemFontInfo({
    required this.family,
    required this.displayName,
    this.filePath,
  });

  final String family;
  final String displayName;
  final String? filePath;

  bool get isSystemDefault => family.trim().isEmpty;
}

class SystemFonts {
  static const List<String> _androidFontDirs = [
    '/system/fonts',
    '/system/font',
    '/product/fonts',
    '/vendor/fonts',
  ];

  static final Set<String> _loadedFamilies = <String>{};

  static Future<List<SystemFontInfo>> listFonts() async {
    if (!Platform.isAndroid) return const [];

    final results = <SystemFontInfo>[];
    final seenFamilies = <String>{};

    for (final dirPath in _androidFontDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is! File) continue;
          final ext = p.extension(entity.path).toLowerCase();
          if (ext != '.ttf' && ext != '.otf') continue;
          final baseName = p.basenameWithoutExtension(entity.path);
          if (baseName.trim().isEmpty) continue;
          final family = _familyFromBaseName(baseName);
          if (!seenFamilies.add(family)) continue;
          results.add(
            SystemFontInfo(
              family: family,
              displayName: _prettyName(baseName),
              filePath: entity.path,
            ),
          );
        }
      } catch (_) {
        // Skip unreadable font directories.
      }
    }

    results.sort((a, b) => a.displayName.compareTo(b.displayName));
    return results;
  }

  static String _familyFromBaseName(String baseName) {
    final trimmed = baseName.trim();
    if (trimmed.isEmpty) return 'system-font';
    return 'system-font-$trimmed';
  }

  static String _prettyName(String baseName) {
    return baseName
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<bool> ensureLoaded(SystemFontInfo font) async {
    if (font.filePath == null || font.filePath!.trim().isEmpty) return false;
    if (_loadedFamilies.contains(font.family)) return false;

    try {
      final file = File(font.filePath!);
      if (!file.existsSync()) return false;

      final bytes = await file.readAsBytes();
      final loader = FontLoader(font.family);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      _loadedFamilies.add(font.family);
      return true;
    } catch (_) {
      return false;
    }
  }
}
