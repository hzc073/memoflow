import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('platform adaptive ui seams exist and keep higher layers out', () async {
    const requiredAdaptiveSeams = <String>[
      'lib/platform/widgets/platform_action_sheet.dart',
      'lib/platform/widgets/platform_adaptive_layout.dart',
      'lib/platform/widgets/platform_controls.dart',
      'lib/platform/widgets/platform_dialog.dart',
      'lib/platform/widgets/platform_list_section.dart',
      'lib/platform/widgets/platform_picker.dart',
      'lib/platform/widgets/platform_popover_or_sheet.dart',
      'lib/platform/widgets/platform_primary_action.dart',
      'lib/platform/platform_experience.dart',
    ];

    final missingSeams = requiredAdaptiveSeams
        .where((path) => !File(path).existsSync())
        .toList();
    expect(
      missingSeams,
      isEmpty,
      reason: missingSeams.isEmpty
          ? null
          : 'adaptive platform seam files are missing:\n'
                '${missingSeams.join('\n')}',
    );

    final platformRoots = <Directory>[Directory('lib/platform')];

    const forbiddenLayerPrefixes = <String>[
      'package:memos_flutter_app/features/',
      'package:memos_flutter_app/state/',
      'package:memos_flutter_app/application/',
      'package:memos_flutter_app/data/',
      '../features/',
      '../../features/',
      '../state/',
      '../../state/',
      '../application/',
      '../../application/',
      '../data/',
      '../../data/',
    ];

    const forbiddenTerms = <String>[
      'Store'
          'Kit',
      'productId',
      'receipt',
      'buyout',
      'subscription',
      'paywall',
      'entitlement',
      'AccessDecision.source',
    ];

    final violations = <String>[];
    for (final root in platformRoots) {
      if (!root.existsSync()) continue;

      await for (final entry in root.list(
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

        for (final line in contents.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('import ')) continue;
          final match = RegExp(
            r"""^import ['"]([^'"]+)['"];$""",
          ).firstMatch(trimmed);
          if (match == null) continue;
          final importPath = match.group(1)!;
          if (forbiddenLayerPrefixes.any(importPath.startsWith)) {
            violations.add('$relativePath: forbidden import $importPath');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'platform UI seam must stay free of higher-layer imports and '
                'commercial branching:\n${violations.join('\n')}',
    );
  });

  test('apple mobile setup input stays on platform seams', () async {
    final platformControls = await File(
      'lib/platform/widgets/platform_controls.dart',
    ).readAsString();
    final settingsUi = await File(
      'lib/features/settings/settings_ui.dart',
    ).readAsString();
    final localModeSetup = await File(
      'lib/features/settings/local_mode_setup_screen.dart',
    ).readAsString();

    expect(platformControls, contains('CupertinoTextField('));
    expect(platformControls, contains('resolvePlatformTarget(context)'));
    expect(settingsUi, contains('class SettingsFieldBlock'));
    expect(settingsUi, contains('PlatformTextField('));
    expect(localModeSetup, contains('buildPlatformPageRoute'));
    expect(localModeSetup, contains('showTopToast(context, message)'));

    final violations = <String>[];
    if (localModeSetup.contains('ScaffoldMessenger.of(')) {
      violations.add(
        'local_mode_setup_screen.dart: validation feedback uses ScaffoldMessenger',
      );
    }
    if (localModeSetup.contains('MaterialPageRoute<LocalModeSetupResult>')) {
      violations.add(
        'local_mode_setup_screen.dart: setup route bypasses platform route seam',
      );
    }
    if (RegExp(r'\bMaterial\s*\(').hasMatch(localModeSetup)) {
      violations.add(
        'local_mode_setup_screen.dart: local Material wrapper hides input seam regression',
      );
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Apple mobile setup input must stay on platform/settings seams:\n'
                '${violations.join('\n')}',
    );
  });
}
