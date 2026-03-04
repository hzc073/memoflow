import 'dart:convert';
import 'dart:io';

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
  static const List<String> _macFontDirs = [
    '/System/Library/Fonts',
    '/Library/Fonts',
  ];
  static const List<String> _linuxFontDirs = [
    '/usr/share/fonts',
    '/usr/local/share/fonts',
  ];

  static final Set<String> _loadedFamilies = <String>{};

  static Future<List<SystemFontInfo>> listFonts() async {
    if (Platform.isAndroid) {
      return _listFontsFromDirectories(
        _androidFontDirs,
        recursive: false,
        familyForDisplayName: (displayName, baseName) =>
            _familyFromBaseName(baseName),
      );
    }
    if (Platform.isWindows) {
      return _listWindowsFonts();
    }
    if (Platform.isMacOS) {
      return _listFontsFromDirectories(
        _macFontDirs,
        recursive: true,
        userDirSuffix: p.join('Library', 'Fonts'),
      );
    }
    if (Platform.isLinux) {
      return _listFontsFromDirectories(
        _linuxFontDirs,
        recursive: true,
        userDirSuffix: p.join('.local', 'share', 'fonts'),
      );
    }
    return const [];
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

  static List<SystemFontInfo> _listFontsFromDirectories(
    List<String> roots, {
    required bool recursive,
    String? userDirSuffix,
    String Function(String displayName, String baseName)? familyForDisplayName,
  }) {
    final results = <SystemFontInfo>[];
    final seenFamilies = <String>{};
    final directories = <String>[...roots];
    final home = Platform.environment['HOME'];
    if (home != null && userDirSuffix != null) {
      directories.add(p.join(home, userDirSuffix));
    }

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(
          recursive: recursive,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final ext = p.extension(entity.path).toLowerCase();
          if (ext != '.ttf' && ext != '.otf' && ext != '.ttc') continue;
          final baseName = p.basenameWithoutExtension(entity.path);
          final displayName = _prettyName(baseName);
          if (displayName.isEmpty) continue;
          final family =
              familyForDisplayName?.call(displayName, baseName) ?? displayName;
          if (!seenFamilies.add(family)) continue;
          results.add(
            SystemFontInfo(
              family: family,
              displayName: displayName,
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

  static Future<List<SystemFontInfo>> _listWindowsFonts() async {
    final results = <SystemFontInfo>[];
    final seenFamilies = <String>{};
    final registryFonts = await _readWindowsFontsFromRegistry();
    for (final font in registryFonts) {
      if (!seenFamilies.add(font.family)) continue;
      results.add(font);
    }

    final systemDir = _windowsFontDir();
    final userDir = _windowsUserFontDir();
    final fallbackDirs = <String>[
      if (systemDir != null) systemDir,
      if (userDir != null) userDir,
    ];
    if (fallbackDirs.isNotEmpty) {
      final fallback = _listFontsFromDirectories(
        fallbackDirs,
        recursive: false,
      );
      for (final font in fallback) {
        if (!seenFamilies.add(font.family)) continue;
        results.add(font);
      }
    }

    results.sort((a, b) => a.displayName.compareTo(b.displayName));
    return results;
  }

  static Future<List<SystemFontInfo>> _readWindowsFontsFromRegistry() async {
    const registryKeys = [
      r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      r'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
    ];
    final results = <SystemFontInfo>[];
    final seenFamilies = <String>{};

    for (final key in registryKeys) {
      try {
        final result = await Process.run('reg', ['query', key]);
        if (result.exitCode != 0) continue;
        final output = (result.stdout ?? '').toString();
        for (final line in LineSplitter.split(output)) {
          final match = RegExp(r'^\s*(.+?)\s+REG_\w+\s+(.+)$')
              .firstMatch(line);
          if (match == null) continue;
          final rawName = match.group(1)?.trim() ?? '';
          final rawFile = match.group(2)?.trim() ?? '';
          if (rawName.isEmpty || rawFile.isEmpty) continue;
          if (rawName.startsWith('@')) continue;
          final displayName = _normalizeWindowsDisplayName(rawName);
          if (displayName.isEmpty) continue;
          final filePath = _resolveWindowsFontPath(rawFile);
          if (filePath == null) continue;
          final family = displayName;
          if (!seenFamilies.add(family)) continue;
          results.add(
            SystemFontInfo(
              family: family,
              displayName: displayName,
              filePath: filePath,
            ),
          );
        }
      } catch (_) {
        // Skip registry errors and fall back to directory scan.
      }
    }
    return results;
  }

  static String _normalizeWindowsDisplayName(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return name;
    name = name.replaceAll(
      RegExp(
        r'\s*\((TrueType|OpenType|Raster|Type 1|Device)\)$',
        caseSensitive: false,
      ),
      '',
    );
    return name.trim();
  }

  static String? _windowsFontDir() {
    final systemRoot =
        Platform.environment['SystemRoot'] ?? Platform.environment['WINDIR'];
    if (systemRoot == null || systemRoot.trim().isEmpty) {
      return r'C:\Windows\Fonts';
    }
    return p.join(systemRoot, 'Fonts');
  }

  static String? _windowsUserFontDir() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) return null;
    return p.join(localAppData, 'Microsoft', 'Windows', 'Fonts');
  }

  static String? _resolveWindowsFontPath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceAll('"', '');
    value = _expandWindowsEnvVars(value);
    if (value.contains(',')) {
      value = value.split(',').first.trim();
    }
    if (p.isAbsolute(value) && File(value).existsSync()) return value;

    final candidates = <String>[];
    final systemDir = _windowsFontDir();
    final userDir = _windowsUserFontDir();
    if (systemDir != null) candidates.add(p.join(systemDir, value));
    if (userDir != null) candidates.add(p.join(userDir, value));
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  static String _expandWindowsEnvVars(String value) {
    return value.replaceAllMapped(RegExp(r'%([^%]+)%'), (match) {
      final key = match.group(1);
      if (key == null) return match.group(0) ?? '';
      return Platform.environment[key] ?? match.group(0) ?? '';
    });
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
