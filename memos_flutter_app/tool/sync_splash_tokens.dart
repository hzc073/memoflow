import 'dart:io';

import 'package:path/path.dart' as p;

class SplashTokens {
  SplashTokens({
    required this.backgroundColor,
    required this.brandColor,
    required this.logoAsset,
    required this.iosLogoAsset,
    required this.androidIconDrawable,
    required this.iconBackgroundColor,
    required this.startupVisibleMinMs,
    required this.startupFadeDurationMs,
  });

  final String backgroundColor;
  final String brandColor;
  final String logoAsset;
  final String iosLogoAsset;
  final String androidIconDrawable;
  final String iconBackgroundColor;
  final int startupVisibleMinMs;
  final int startupFadeDurationMs;
}

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final rootDir = _resolveRepoRoot();
  final rootPath = rootDir.path;
  final tokensPath = p.join(rootPath, 'tool', 'splash_tokens.yaml');
  final tokensFile = File(tokensPath);
  if (!tokensFile.existsSync()) {
    stderr.writeln('Missing tokens file: $tokensPath');
    exitCode = 2;
    return;
  }

  final tokens = _parseTokens(tokensFile.readAsStringSync());
  final outputs = <_OutputSpec>[
    _OutputSpec(
      path: p.join(rootPath, 'lib', 'core', 'splash_tokens.g.dart'),
      content: _buildDartTokens(tokens),
    ),
    _OutputSpec(
      path: p.join(
        rootPath,
        'android',
        'app',
        'src',
        'main',
        'res',
        'values',
        'splash.xml',
      ),
      content: _buildAndroidSplashXml(tokens),
    ),
    _OutputSpec(
      path: p.join(rootPath, 'flutter_native_splash.yaml'),
      content: _buildFlutterNativeSplashYaml(tokens),
    ),
  ];

  var hasDiff = false;
  for (final output in outputs) {
    final file = File(output.path);
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    if (existing != output.content) {
      hasDiff = true;
      if (!checkOnly) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(output.content);
      }
    }
  }

  if (checkOnly && hasDiff) {
    stderr.writeln('Splash token outputs are out of date.');
    exitCode = 1;
    return;
  }
}

Directory _resolveRepoRoot() {
  final scriptDir = File.fromUri(Platform.script).parent;
  return Directory(scriptDir.parent.path);
}

SplashTokens _parseTokens(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  var inSplash = false;
  final values = <String, String>{};

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) continue;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) continue;
    if (trimmed == 'splash:') {
      inSplash = true;
      continue;
    }
    if (!inSplash) continue;
    if (!line.startsWith('  ')) continue;
    final splitIndex = trimmed.indexOf(':');
    if (splitIndex <= 0) continue;
    final key = trimmed.substring(0, splitIndex).trim();
    var value = trimmed.substring(splitIndex + 1).trim();
    value = _stripQuotes(value);
    values[key] = value;
  }

  return SplashTokens(
    backgroundColor: _require(values, 'background_color'),
    brandColor: _require(values, 'brand_color'),
    logoAsset: _require(values, 'logo_asset'),
    iosLogoAsset: _require(values, 'ios_logo_asset'),
    androidIconDrawable: _require(values, 'android_icon_drawable'),
    iconBackgroundColor: _require(values, 'icon_background_color'),
    startupVisibleMinMs: int.parse(_require(values, 'startup_visible_min_ms')),
    startupFadeDurationMs: int.parse(
      _require(values, 'startup_fade_duration_ms'),
    ),
  );
}

String _require(Map<String, String> values, String key) {
  final value = values[key];
  if (value == null || value.isEmpty) {
    stderr.writeln('Missing splash token: $key');
    exitCode = 2;
    throw StateError('Missing splash token: $key');
  }
  return value;
}

String _stripQuotes(String value) {
  if (value.length < 2) return value;
  final startsWithQuote = value.startsWith('"') || value.startsWith("'");
  if (!startsWithQuote) return value;
  final quote = value[0];
  if (!value.endsWith(quote)) return value;
  return value.substring(1, value.length - 1);
}

String _normalizeHex(String value) {
  var hex = value.trim();
  if (!hex.startsWith('#')) {
    hex = '#$hex';
  }
  return hex.toUpperCase();
}

String _flutterColorLiteral(String value) {
  final hex = _normalizeHex(value).substring(1);
  final argb = hex.length == 6 ? 'FF$hex' : hex.padLeft(8, 'F');
  return '0x$argb';
}

String _buildDartTokens(SplashTokens tokens) {
  final background = _flutterColorLiteral(tokens.backgroundColor);
  final brand = _flutterColorLiteral(tokens.brandColor);
  final iconBackground = _flutterColorLiteral(tokens.iconBackgroundColor);
  return '''
// GENERATED FILE. DO NOT EDIT.
import 'package:flutter/material.dart';

class SplashTokens {
  const SplashTokens._();

  static const Color backgroundColor = Color($background);
  static const Color brandColor = Color($brand);
  static const Color iconBackgroundColor = Color($iconBackground);
  static const String logoAsset = '${tokens.logoAsset}';
  static const String iosLogoAsset = '${tokens.iosLogoAsset}';
  static const String androidIconDrawable = '${tokens.androidIconDrawable}';
  static const int startupVisibleMinMs = ${tokens.startupVisibleMinMs};
  static const int startupFadeDurationMs = ${tokens.startupFadeDurationMs};
}
''';
}

String _buildAndroidSplashXml(SplashTokens tokens) {
  final background = _normalizeHex(tokens.backgroundColor);
  final iconBg = _normalizeHex(tokens.iconBackgroundColor);
  return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED FILE. DO NOT EDIT. -->
<resources>
    <color name="splash_background">$background</color>
    <color name="splash_icon_background">$iconBg</color>
    <item type="drawable" name="splash_icon">@drawable/${tokens.androidIconDrawable}</item>
</resources>
''';
}

String _buildFlutterNativeSplashYaml(SplashTokens tokens) {
  final background = _normalizeHex(tokens.backgroundColor);
  final iconBg = _normalizeHex(tokens.iconBackgroundColor);
  return '''
flutter_native_splash:
  color: "$background"
  android: true
  ios: true
  web: false
  image_ios: ${tokens.iosLogoAsset}
  android_12:
    color: "$background"
    icon_background_color: "$iconBg"
''';
}

class _OutputSpec {
  _OutputSpec({required this.path, required this.content});

  final String path;
  final String content;
}
