import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
