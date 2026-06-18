import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = Directory.current.parent;

  String readRepoFile(String relativePath) {
    return File(
      '${repoRoot.path}${Platform.pathSeparator}$relativePath',
    ).readAsStringSync();
  }

  test('public shell depends on bundle provider seam only', () {
    final appContent = readRepoFile('memos_flutter_app/lib/app.dart');
    final settingsContent = readRepoFile(
      'memos_flutter_app/lib/features/settings/settings_screen.dart',
    );

    expect(
      appContent.contains('private_extension_bundle_provider.dart'),
      isTrue,
    );
    expect(
      settingsContent.contains('private_extension_bundle_provider.dart'),
      isTrue,
    );
    expect(settingsContent.contains('access_boundary/'), isFalse);
    expect(appContent.contains('access_boundary/'), isFalse);
  });

  test('public settings shell does not read commercial state', () {
    final settingsFiles = <String>[
      'memos_flutter_app/lib/features/settings/settings_screen.dart',
      'memos_flutter_app/lib/features/settings/support_memoflow_screen.dart',
      'memos_flutter_app/lib/features/settings/support_memoflow_policy.dart',
    ];

    const forbiddenTerms = <String>[
      'access_boundary/',
      'AppCapability',
      'AccessDecision',
      'Store'
          'Kit',
      'productId',
      'price',
      'purchase',
      'restore',
      'receipt',
      'transaction',
      'buyout',
      'familySharing',
      'entitlement',
      'paywall',
    ];

    final violations = <String>[];
    for (final path in settingsFiles) {
      final content = readRepoFile(path);
      for (final term in forbiddenTerms) {
        if (content.contains(term)) {
          violations.add('$path contains $term');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'settings_screen.dart must render private bundle contributions '
                'without commercial branching: ${violations.join(', ')}',
    );
  });

  test('public support page does not use QR payment assets', () {
    final supportContent = readRepoFile(
      'memos_flutter_app/lib/features/settings/support_memoflow_screen.dart',
    );

    expect(supportContent.contains('donation_qr.png'), isFalse);
    expect(supportContent.contains('assets/images/donation_qr.png'), isFalse);
    expect(
      supportContent.contains('https://qr.alipay.com/tsx16856ygfke5rugz1ao4a'),
      isTrue,
    );
  });

  test('public support page keeps Apple external support denied by policy', () {
    final supportContent = readRepoFile(
      'memos_flutter_app/lib/features/settings/support_memoflow_screen.dart',
    );
    final policyContent = readRepoFile(
      'memos_flutter_app/lib/features/settings/support_memoflow_policy.dart',
    );

    expect(
      policyContent.contains('allowsExternalSupport: !experience.isApple'),
      isTrue,
    );
    expect(
      policyContent.contains('showAppleExplanation: experience.isApple'),
      isTrue,
    );
    expect(
      supportContent.contains('supportMemoFlow.appleSupportExplanation'),
      isTrue,
    );
  });

  test('public runtime does not include StoreKit or IAP implementation', () {
    final checkedFiles = <String>[
      'memos_flutter_app/pubspec.yaml',
      'memos_flutter_app/pubspec.lock',
      'memos_flutter_app/lib/app.dart',
      'memos_flutter_app/lib/main.dart',
      'memos_flutter_app/lib/features/settings/settings_screen.dart',
      'memos_flutter_app/lib/features/settings/support_memoflow_screen.dart',
      'memos_flutter_app/lib/features/settings/support_memoflow_policy.dart',
      'memos_flutter_app/lib/module_boundary/settings_entry_contribution.dart',
      'memos_flutter_app/lib/module_boundary/support_memo_flow_contribution.dart',
      'memos_flutter_app/lib/private_hooks/private_extension_bundle.dart',
      'memos_flutter_app/lib/private_hooks/private_extension_bundle_provider.dart',
      'memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart',
    ];

    const forbiddenTerms = <String>[
      'Store'
          'Kit',
      'IAP',
      'SKPayment',
      'in_app_purchase',
      'purchases_flutter',
      'RevenueCat',
      'subscription',
      'billing',
      'entitlement',
      'productId',
      'productIdentifier',
      'displayPrice',
      'priceLocale',
      'restorePurchase',
      'restorePurchases',
      'receipt',
      'transaction',
      'paywall',
      'familySharing',
    ];

    final violations = <String>[];
    for (final path in checkedFiles) {
      final content = readRepoFile(path);
      for (final term in forbiddenTerms) {
        if (content.contains(term)) {
          violations.add('$path contains $term');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'public runtime must not include StoreKit or IAP implementation:\n'
                '${violations.join('\n')}',
    );
  });

  test('public active bundle remains a no-op implementation', () {
    final activeBundle = readRepoFile(
      'memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart',
    );

    expect(activeBundle.contains('public-default'), isTrue);
    expect(
      activeBundle.contains('return const <SettingsEntryContribution>[];'),
      isTrue,
    );
  });

  test('public platform ui seam stays free of commercial branching', () async {
    final platformDir = Directory(
      '${repoRoot.path}${Platform.pathSeparator}memos_flutter_app${Platform.pathSeparator}lib${Platform.pathSeparator}platform',
    );
    if (!platformDir.existsSync()) {
      return;
    }

    const forbiddenTerms = <String>[
      'Store'
          'Kit',
      'productId',
      'price',
      'purchase',
      'restore',
      'receipt',
      'transaction',
      'buyout',
      'familySharing',
      'entitlement',
      'paywall',
      'AccessDecision.source',
      'subscription',
    ];

    final violations = <String>[];
    await for (final entry in platformDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final contents = await entry.readAsString();
      final relativePath = entry.path.replaceAll('\\', '/');

      for (final term in forbiddenTerms) {
        if (contents.contains(term)) {
          violations.add('$relativePath: forbidden term $term');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'platform UI seam must not contain commercial branching:\n'
                '${violations.join('\n')}',
    );
  });

  test('legacy root lib duplicates stay removed', () {
    expect(
      File(
        '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}data${Platform.pathSeparator}models${Platform.pathSeparator}shortcut.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        '${repoRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}data${Platform.pathSeparator}models${Platform.pathSeparator}user_setting.dart',
      ).existsSync(),
      isFalse,
    );
  });
}
