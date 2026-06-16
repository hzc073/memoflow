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
  final iosLogoPath = p.join(rootPath, tokens.iosLogoAsset);
  final iosLogoFile = File(iosLogoPath);
  if (!iosLogoFile.existsSync()) {
    stderr.writeln('Missing iOS splash logo asset: ${tokens.iosLogoAsset}');
    exitCode = 2;
    return;
  }
  final iosLogoBytes = iosLogoFile.readAsBytesSync();

  final outputs = <_OutputSpec>[
    _OutputSpec.text(
      path: p.join(rootPath, 'lib', 'core', 'splash_tokens.g.dart'),
      content: _buildDartTokens(tokens),
    ),
    _OutputSpec.text(
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
    _OutputSpec.text(
      path: p.join(rootPath, 'flutter_native_splash.yaml'),
      content: _buildFlutterNativeSplashYaml(tokens),
    ),
    _OutputSpec.text(
      path: p.join(
        rootPath,
        'ios',
        'Runner',
        'Base.lproj',
        'LaunchScreen.storyboard',
      ),
      content: _buildIosLaunchScreenStoryboard(tokens),
    ),
    _OutputSpec.text(
      path: p.join(rootPath, 'ios', 'Runner', 'Base.lproj', 'Main.storyboard'),
      content: _buildIosMainStoryboard(tokens),
    ),
    _OutputSpec.text(
      path: p.join(
        rootPath,
        'ios',
        'Runner',
        'Assets.xcassets',
        'LaunchImage.imageset',
        'Contents.json',
      ),
      content: _buildIosLaunchImageContentsJson(),
    ),
    for (final fileName in const [
      'LaunchImage.png',
      'LaunchImage@2x.png',
      'LaunchImage@3x.png',
    ])
      _OutputSpec.binary(
        path: p.join(
          rootPath,
          'ios',
          'Runner',
          'Assets.xcassets',
          'LaunchImage.imageset',
          fileName,
        ),
        bytes: iosLogoBytes,
      ),
  ];

  final staleOutputs = <String>[];
  for (final output in outputs) {
    if (output.hasDiff()) {
      staleOutputs.add(p.relative(output.path, from: rootPath));
      if (!checkOnly) {
        output.write();
      }
    }
  }

  if (checkOnly && staleOutputs.isNotEmpty) {
    stderr.writeln('Splash token outputs are out of date.');
    stderr.writeln('Source of truth: tool/splash_tokens.yaml');
    stderr.writeln('Regenerate outputs from memos_flutter_app:');
    stderr.writeln('  dart run tool/sync_splash_tokens.dart');
    stderr.writeln('Stale outputs:');
    for (final outputPath in staleOutputs) {
      stderr.writeln('  - $outputPath');
    }
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

_ArgbColor _parseArgbColor(String value) {
  final hex = _normalizeHex(value).substring(1);
  if (hex.length == 6) {
    return _ArgbColor(
      alpha: 255,
      red: int.parse(hex.substring(0, 2), radix: 16),
      green: int.parse(hex.substring(2, 4), radix: 16),
      blue: int.parse(hex.substring(4, 6), radix: 16),
    );
  }
  if (hex.length == 8) {
    return _ArgbColor(
      alpha: int.parse(hex.substring(0, 2), radix: 16),
      red: int.parse(hex.substring(2, 4), radix: 16),
      green: int.parse(hex.substring(4, 6), radix: 16),
      blue: int.parse(hex.substring(6, 8), radix: 16),
    );
  }
  stderr.writeln('Unsupported color token: $value');
  exitCode = 2;
  throw StateError('Unsupported color token: $value');
}

String _iosComponent(int value) {
  if (value <= 0) return '0';
  if (value >= 255) return '1';
  return (value / 255).toStringAsFixed(10);
}

String _iosBackgroundColorXml(SplashTokens tokens) {
  final color = _parseArgbColor(tokens.backgroundColor);
  return '<color key="backgroundColor" red="${_iosComponent(color.red)}" '
      'green="${_iosComponent(color.green)}" '
      'blue="${_iosComponent(color.blue)}" '
      'alpha="${_iosComponent(color.alpha)}" '
      'colorSpace="custom" customColorSpace="sRGB"/>';
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

String _buildIosLaunchScreenStoryboard(SplashTokens tokens) {
  final backgroundColor = _iosBackgroundColorXml(tokens);
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- GENERATED FILE. DO NOT EDIT. -->
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="12121" systemVersion="16G29" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="12089"/>
    </dependencies>
    <scenes>
        <!--View Controller-->
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="Ydg-fD-yQy"/>
                        <viewControllerLayoutGuide type="bottom" id="xbc-2k-c8Z"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView opaque="NO" clipsSubviews="YES" userInteractionEnabled="NO" contentMode="scaleAspectFit" image="LaunchImage" translatesAutoresizingMaskIntoConstraints="NO" id="YRO-k0-Ey4"/>
                        </subviews>
                        $backgroundColor
                        <constraints>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="1a2-6s-vTC"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="4X2-HB-R7a"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="width" constant="168" id="LqW-3e-Np1"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="height" constant="168" id="v6K-7u-tb2"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="LaunchImage" width="168" height="168"/>
    </resources>
</document>
''';
}

String _buildIosMainStoryboard(SplashTokens tokens) {
  final backgroundColor = _iosBackgroundColorXml(tokens);
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- GENERATED FILE. DO NOT EDIT. -->
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="10117" systemVersion="15F34" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" useTraitCollections="YES" initialViewController="BYZ-38-t0r">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="10085"/>
    </dependencies>
    <scenes>
        <!--Flutter View Controller-->
        <scene sceneID="tne-QT-ifu">
            <objects>
                <viewController id="BYZ-38-t0r" customClass="FlutterViewController" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="y3c-jy-aDJ"/>
                        <viewControllerLayoutGuide type="bottom" id="wfy-db-euE"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="8bC-Xf-vdC">
                        <rect key="frame" x="0.0" y="0.0" width="600" height="600"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        $backgroundColor
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="dkx-z0-nzr" sceneMemberID="firstResponder"/>
            </objects>
        </scene>
    </scenes>
</document>
''';
}

String _buildIosLaunchImageContentsJson() {
  return '''
{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "LaunchImage.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
''';
}

class _ArgbColor {
  _ArgbColor({
    required this.alpha,
    required this.red,
    required this.green,
    required this.blue,
  });

  final int alpha;
  final int red;
  final int green;
  final int blue;
}

class _OutputSpec {
  _OutputSpec.text({required this.path, required String content})
    : _content = content,
      _bytes = null;

  _OutputSpec.binary({required this.path, required List<int> bytes})
    : _content = null,
      _bytes = bytes;

  final String path;
  final String? _content;
  final List<int>? _bytes;

  bool hasDiff() {
    final file = File(path);
    if (_content != null) {
      final existing = file.existsSync() ? file.readAsStringSync() : '';
      return existing != _content;
    }

    final bytes = _bytes;
    if (bytes == null) return false;
    final existing = file.existsSync() ? file.readAsBytesSync() : <int>[];
    return !_listEquals(existing, bytes);
  }

  void write() {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final content = _content;
    if (content != null) {
      file.writeAsStringSync(content);
      return;
    }

    final bytes = _bytes;
    if (bytes != null) {
      file.writeAsBytesSync(bytes);
    }
  }
}

bool _listEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
