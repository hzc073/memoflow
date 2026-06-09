import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readFile(String relativePath) => File(relativePath).readAsStringSync();

  test('macOS distribution identity keeps production storage isolated', () {
    final identity = readFile('lib/core/macos_distribution_identity.dart');
    final sessionProvider = readFile('lib/state/system/session_provider.dart');
    final appInfo = readFile('macos/Runner/Configs/AppInfo.xcconfig');
    final xcodeProject = readFile('macos/Runner.xcodeproj/project.pbxproj');
    final configurationBlocks = RegExp(
      r'\t\t[A-F0-9]+ /\* ([^*]+) \*/ = \{\n([\s\S]*?)\n\t\t\};',
    ).allMatches(xcodeProject);

    bool runnerConfigUsesBundleId(String name, String bundleId) {
      return configurationBlocks.any((match) {
        final blockName = match.group(1);
        final body = match.group(2) ?? '';
        return blockName == name &&
            body.contains(
              'baseConfigurationReference = 33E5194F232828860026EE4D '
              '/* AppInfo.xcconfig */;',
            ) &&
            body.contains('MEMOFLOW_MACOS_BUNDLE_ID = $bundleId;');
      });
    }

    expect(
      appInfo.contains(
        'PRODUCT_BUNDLE_IDENTIFIER = '
        r'$(MEMOFLOW_MACOS_BUNDLE_ID)',
      ),
      isTrue,
    );
    expect(
      runnerConfigUsesBundleId('Debug', 'com.memoflow.hzc073.dev'),
      isTrue,
    );
    expect(
      runnerConfigUsesBundleId('Debug-Runner', 'com.memoflow.hzc073.dev'),
      isTrue,
    );
    expect(
      runnerConfigUsesBundleId('Profile', 'com.memoflow.hzc073.qa'),
      isTrue,
    );
    expect(
      runnerConfigUsesBundleId('Profile-Runner', 'com.memoflow.hzc073.qa'),
      isTrue,
    );
    expect(runnerConfigUsesBundleId('Release', 'com.memoflow.hzc073'), isTrue);
    expect(
      runnerConfigUsesBundleId('Release-Runner', 'com.memoflow.hzc073'),
      isTrue,
    );
    expect(identity.contains('com.memoflow.hzc073.secure.production'), isTrue);
    expect(identity.contains('com.memoflow.hzc073.secure.dev'), isTrue);
    expect(identity.contains('com.memoflow.hzc073.secure.qa'), isTrue);
    expect(identity.contains('flutter_secure_storage_service'), isFalse);
    expect(identity.contains("defaultValue: ''"), isTrue);
    expect(
      identity.contains('_ => MacosDistributionChannel.development'),
      isTrue,
      reason:
          'Unset, unknown, debug, and ad-hoc channels must not default to production.',
    );
    expect(
      identity.contains(
        'MacosDistributionChannel.production => macosProductionKeychainService',
      ),
      isTrue,
    );
    expect(
      identity.contains(
        'MacosDistributionChannel.development => macosDevelopmentKeychainService',
      ),
      isTrue,
    );
    expect(
      identity.contains(
        'MacosDistributionChannel.qa => macosQaKeychainService',
      ),
      isTrue,
    );
    expect(
      sessionProvider.contains(
        'mOptions: macosSecureStorageOptionsForCurrentDistributionChannel()',
      ),
      isTrue,
    );
    expect(sessionProvider.contains('macosProductionKeychainService'), isFalse);
    expect(sessionProvider.contains('flutter_secure_storage_service'), isFalse);
  });

  test('macOS distribution governance files stay public and non-secret', () {
    final releaseEntitlements = readFile('macos/Runner/Release.entitlements');
    final validator = readFile('tool/validate_macos_dmg.sh');

    expect(
      releaseEntitlements.contains('com.apple.security.get-task-allow'),
      isFalse,
    );
    expect(
      validator.contains(
        '--dart-define=MEMOFLOW_MACOS_DISTRIBUTION_CHANNEL=production',
      ),
      isTrue,
    );
    expect(validator.contains('codesign -dv --verbose=4'), isTrue);
    expect(validator.contains('Signature=adhoc'), isTrue);
    expect(validator.contains('Authority=Developer ID Application:'), isTrue);
    expect(validator.contains('TeamIdentifier'), isTrue);
    expect(validator.contains('com.apple.security.get-task-allow'), isTrue);
    expect(validator.contains('spctl -a -vvv -t exec'), isTrue);
    expect(validator.contains('stapler validate'), isTrue);

    const scannedFiles = <String>[
      'lib/core/macos_distribution_identity.dart',
      'lib/state/system/session_provider.dart',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'macos/Runner/Release.entitlements',
      'tool/validate_macos_dmg.sh',
    ];
    const forbiddenPatterns = <String>[
      'DEVELOPMENT_TEAM =',
      'notarytool store-credentials',
      'AC_PASSWORD',
      'ASC_KEY',
      'AuthKey_',
      '.p8',
      '.p12',
      'app-specific password',
      'APPLE_ID',
      'FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD',
      'Store'
          'Kit',
      'SKPayment',
      'in_app_purchase',
      'purchases_flutter',
      'RevenueCat',
      'productId',
      'productIdentifier',
      'priceLocale',
      'paywall',
      'receipt',
    ];

    final violations = <String>[];
    for (final file in scannedFiles) {
      final contents = readFile(file);
      for (final pattern in forbiddenPatterns) {
        if (contents.contains(pattern)) {
          violations.add('$file: $pattern');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'macOS distribution governance files must not leak secrets or commercial runtime:\n'
                '${violations.join('\n')}',
    );
  });
}
