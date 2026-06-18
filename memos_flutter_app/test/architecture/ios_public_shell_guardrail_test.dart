import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _PngSize {
  const _PngSize(this.width, this.height);

  final int width;
  final int height;
}

bool _isTextConfigurationFile(String path) {
  final fileName = path.split('/').last;
  if (fileName == '.gitignore' || fileName == 'Podfile') return true;

  const textExtensions = <String>[
    '.h',
    '.json',
    '.m',
    '.md',
    '.pbxproj',
    '.plist',
    '.storyboard',
    '.swift',
    '.xcconfig',
    '.xcscheme',
    '.xcsettings',
    '.xcworkspacedata',
  ];

  return textExtensions.any(path.endsWith);
}

Map<String, String> _readSplashTokenValues() {
  final values = <String, String>{};
  var inSplash = false;
  for (final rawLine in File('tool/splash_tokens.yaml').readAsLinesSync()) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) continue;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) continue;
    if (trimmed == 'splash:') {
      inSplash = true;
      continue;
    }
    if (!inSplash || !line.startsWith('  ')) continue;

    final splitIndex = trimmed.indexOf(':');
    if (splitIndex <= 0) continue;
    final key = trimmed.substring(0, splitIndex).trim();
    var value = trimmed.substring(splitIndex + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

String _iosColorXml(String hexColor) {
  final hex = hexColor.replaceFirst('#', '').toUpperCase();
  final alpha = hex.length == 8
      ? int.parse(hex.substring(0, 2), radix: 16)
      : 255;
  final colorStart = hex.length == 8 ? 2 : 0;
  final red = int.parse(hex.substring(colorStart, colorStart + 2), radix: 16);
  final green = int.parse(
    hex.substring(colorStart + 2, colorStart + 4),
    radix: 16,
  );
  final blue = int.parse(
    hex.substring(colorStart + 4, colorStart + 6),
    radix: 16,
  );

  return '<color key="backgroundColor" red="${_iosComponent(red)}" '
      'green="${_iosComponent(green)}" '
      'blue="${_iosComponent(blue)}" '
      'alpha="${_iosComponent(alpha)}" '
      'colorSpace="custom" customColorSpace="sRGB"/>';
}

String _iosComponent(int value) {
  if (value <= 0) return '0';
  if (value >= 255) return '1';
  return (value / 255).toStringAsFixed(10);
}

_PngSize _readPngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(
    bytes.length,
    greaterThanOrEqualTo(24),
    reason: '${file.path} is too small',
  );
  expect(
    bytes.take(8).toList(),
    equals(const [137, 80, 78, 71, 13, 10, 26, 10]),
  );

  int readUint32(int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  return _PngSize(readUint32(16), readUint32(20));
}

void _copyFileIntoTemp(String sourcePath, String destinationPath) {
  final destination = File(destinationPath);
  destination.parent.createSync(recursive: true);
  File(sourcePath).copySync(destination.path);
}

void main() {
  String readFile(String relativePath) => File(relativePath).readAsStringSync();

  Iterable<File> publicIosFiles() sync* {
    final root = Directory('ios');
    if (!root.existsSync()) return;

    for (final entry in root.listSync(recursive: true, followLinks: false)) {
      if (entry is! File) continue;
      final path = entry.path.replaceAll('\\', '/');
      if (!_isTextConfigurationFile(path)) continue;
      if (path.contains('/Pods/')) continue;
      if (path.contains('/Flutter/ephemeral/')) continue;
      if (path.endsWith('/Flutter/Generated.xcconfig')) continue;
      if (path.endsWith('/Flutter/flutter_export_environment.sh')) continue;
      if (path.contains('/Runner/GeneratedPluginRegistrant.')) continue;
      yield entry;
    }
  }

  test('iOS public shell keeps MemoFlow identity and public permissions', () {
    expect(Directory('ios').existsSync(), isTrue);
    expect(File('ios/Runner/Info.plist').existsSync(), isTrue);
    expect(File('ios/Runner.xcodeproj/project.pbxproj').existsSync(), isTrue);
    expect(
      File(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/play.xcscheme',
      ).existsSync(),
      isTrue,
    );
    expect(File('ios/Runner/AppDelegate.swift').existsSync(), isTrue);
    expect(File('ios/Podfile').existsSync(), isTrue);

    final infoPlist = readFile('ios/Runner/Info.plist');
    final podfile = readFile('ios/Podfile');
    final project = readFile('ios/Runner.xcodeproj/project.pbxproj');
    final appDelegate = readFile('ios/Runner/AppDelegate.swift');

    expect(infoPlist.contains('<string>MemoFlow</string>'), isTrue);
    expect(
      project.contains('PRODUCT_BUNDLE_IDENTIFIER = com.memoflow.hzc073;'),
      isTrue,
    );
    expect(project.contains('name = "Release-play";'), isTrue);
    expect(project.contains('IPHONEOS_DEPLOYMENT_TARGET = 15.5;'), isTrue);
    expect(podfile.contains("platform :ios, '15.5'"), isTrue);
    expect(
      project.contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.memoflow.hzc073.RunnerTests;',
      ),
      isTrue,
    );

    const requiredPrivacyKeys = <String>[
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSLocationWhenInUseUsageDescription',
      'NSLocalNetworkUsageDescription',
      'NSBonjourServices',
      '_memoflow._tcp',
      '_memoflow-migrate._tcp',
      'NSAppTransportSecurity',
      'NSAllowsArbitraryLoads',
    ];
    for (final key in requiredPrivacyKeys) {
      expect(infoPlist.contains(key), isTrue, reason: '$key is required');
    }

    expect(appDelegate.contains('GeneratedPluginRegistrant.register'), isTrue);
    expect(appDelegate.contains('FlutterDartProject'), isFalse);
    expect(appDelegate.contains('dartEntrypoint'), isFalse);
    expect(appDelegate.contains('private_hooks'), isFalse);
  });

  test('iOS mobile public feature targets are wired', () {
    expect(File('ios/Runner/MemoFlowNativeBridge.swift').existsSync(), isTrue);
    expect(File('ios/Runner/Runner.entitlements').existsSync(), isTrue);
    expect(
      File(
        'ios/MemoFlowWidgetExtension/MemoFlowWidgetExtension.swift',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('ios/MemoFlowShareExtension/ShareViewController.swift').existsSync(),
      isTrue,
    );

    final infoPlist = readFile('ios/Runner/Info.plist');
    final project = readFile('ios/Runner.xcodeproj/project.pbxproj');
    final runnerEntitlements = readFile('ios/Runner/Runner.entitlements');
    final widgetEntitlements = readFile(
      'ios/MemoFlowWidgetExtension/MemoFlowWidgetExtension.entitlements',
    );
    final shareEntitlements = readFile(
      'ios/MemoFlowShareExtension/MemoFlowShareExtension.entitlements',
    );
    final bridge = readFile('ios/Runner/MemoFlowNativeBridge.swift');
    final widget = readFile(
      'ios/MemoFlowWidgetExtension/MemoFlowWidgetExtension.swift',
    );
    final share = readFile(
      'ios/MemoFlowShareExtension/ShareViewController.swift',
    );
    final shareInfo = readFile('ios/MemoFlowShareExtension/Info.plist');

    expect(infoPlist, contains('<string>memoflow</string>'));
    expect(project, contains('MemoFlowWidgetExtension'));
    expect(project, contains('MemoFlowShareExtension'));
    expect(project, contains('Embed App Extensions'));
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.memoflow.hzc073.widget;'),
    );
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.memoflow.hzc073.share;'),
    );
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
    expect(project, contains('WidgetKit.framework'));
    expect(project, contains('UniformTypeIdentifiers.framework'));

    for (final entitlements in <String>[
      runnerEntitlements,
      widgetEntitlements,
      shareEntitlements,
    ]) {
      expect(entitlements, contains('group.com.memoflow.hzc073'));
    }

    expect(bridge, contains('memoflow/widgets'));
    expect(bridge, contains('memoflow/share'));
    expect(bridge, contains('WidgetCenter.shared.reloadTimelines'));
    expect(bridge, contains('memoflow.pendingSharePayload'));
    expect(widget, contains('WidgetBundle'));
    expect(widget, contains('MemoFlowDailyReviewWidget'));
    expect(widget, contains('MemoFlowQuickInputWidget'));
    expect(widget, contains('MemoFlowCalendarWidget'));
    expect(share, contains('ShareIntake'));
    expect(share, contains('extensionContext?.open'));
    expect(shareInfo, contains('com.apple.share-services'));
  });

  test(
    'iOS public shell contains no commercial runtime or release secrets',
    () {
      const forbiddenPatterns = <String>[
        'DEVELOPMENT_TEAM',
        'PROVISIONING_PROFILE',
        'Apple Development:',
        'App Store Connect',
        'TestFlight',
        'AuthKey_',
        '.mobileprovision',
        'Store'
            'Kit',
        'SKPayment',
        'in_app_purchase',
        'purchases_flutter',
        'RevenueCat',
        'productId',
        'productIdentifier',
        'priceLocale',
        'restorePurchase',
        'restorePurchases',
        'receipt',
        'transaction',
        'paywall',
        'familySharing',
        'AccessDecision.source',
      ];

      final violations = <String>[];
      for (final file in publicIosFiles()) {
        final path = file.path.replaceAll('\\', '/');
        final contents = file.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          if (contents.contains(pattern)) {
            violations.add('$path: $pattern');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'iOS public shell must not leak commercial runtime or release '
                  'secrets:\n${violations.join('\n')}',
      );
    },
  );

  test('iOS native splash surfaces match splash tokens', () {
    final tokens = _readSplashTokenValues();
    final expectedBackground = _iosColorXml(tokens['background_color']!);
    final logoAsset = tokens['ios_logo_asset']!;

    final launchScreen = readFile(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    );
    final mainStoryboard = readFile('ios/Runner/Base.lproj/Main.storyboard');
    final contentsJson = readFile(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json',
    );

    expect(launchScreen, contains('<!-- GENERATED FILE. DO NOT EDIT. -->'));
    expect(launchScreen, contains(expectedBackground));
    expect(
      launchScreen,
      contains('contentMode="scaleAspectFit" image="LaunchImage"'),
    );
    expect(launchScreen, contains('firstAttribute="width" constant="168"'));
    expect(launchScreen, contains('firstAttribute="height" constant="168"'));
    expect(launchScreen, isNot(contains('red="1" green="1" blue="1"')));

    expect(mainStoryboard, contains('<!-- GENERATED FILE. DO NOT EDIT. -->'));
    expect(mainStoryboard, contains('customClass="FlutterViewController"'));
    expect(mainStoryboard, contains(expectedBackground));
    expect(mainStoryboard, isNot(contains('white="1"')));

    const launchImageFiles = <String>[
      'LaunchImage.png',
      'LaunchImage@2x.png',
      'LaunchImage@3x.png',
    ];
    for (final fileName in launchImageFiles) {
      expect(contentsJson, contains(fileName));
    }

    final logoFile = File(logoAsset);
    final logoBytes = logoFile.readAsBytesSync();
    final logoSize = _readPngSize(logoFile);
    for (final fileName in launchImageFiles) {
      final launchImage = File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/$fileName',
      );
      final launchImageSize = _readPngSize(launchImage);
      expect(launchImageSize.width, greaterThan(1), reason: launchImage.path);
      expect(launchImageSize.height, greaterThan(1), reason: launchImage.path);
      expect(launchImageSize.width, logoSize.width, reason: launchImage.path);
      expect(launchImageSize.height, logoSize.height, reason: launchImage.path);
      expect(launchImage.readAsBytesSync(), equals(logoBytes));
    }
  });

  test(
    'splash token sync check guards committed and stale outputs',
    () async {
      final current = await Process.run('dart', [
        'run',
        'tool/sync_splash_tokens.dart',
        '--check',
      ]);
      expect(
        current.exitCode,
        0,
        reason: '${current.stdout}\n${current.stderr}',
      );

      final packageConfig = File('.dart_tool/package_config.json');
      expect(packageConfig.existsSync(), isTrue);

      final tempDir = Directory.systemTemp.createTempSync(
        'memoflow_splash_check_',
      );
      try {
        _copyFileIntoTemp(
          'tool/sync_splash_tokens.dart',
          '${tempDir.path}/tool/sync_splash_tokens.dart',
        );
        _copyFileIntoTemp(
          'tool/splash_tokens.yaml',
          '${tempDir.path}/tool/splash_tokens.yaml',
        );
        _copyFileIntoTemp(
          'assets/splash/splash_logo_native.png',
          '${tempDir.path}/assets/splash/splash_logo_native.png',
        );

        final stale = await Process.run('dart', [
          '--packages=${packageConfig.path}',
          '${tempDir.path}/tool/sync_splash_tokens.dart',
          '--check',
        ]);
        final output = '${stale.stdout}\n${stale.stderr}';
        expect(stale.exitCode, 1, reason: output);
        expect(output, contains('dart run tool/sync_splash_tokens.dart'));
        expect(output, contains('tool/splash_tokens.yaml'));
        expect(
          output,
          contains('ios/Runner/Base.lproj/LaunchScreen.storyboard'),
        );
        expect(output, contains('ios/Runner/Base.lproj/Main.storyboard'));
        expect(
          output,
          contains(
            'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
          ),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
