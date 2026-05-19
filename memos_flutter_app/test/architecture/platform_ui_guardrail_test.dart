import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('platform ui seam keeps higher layers out', () async {
    final platformDir = Directory('lib/platform');
    if (!platformDir.existsSync()) {
      return;
    }

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

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'platform UI seam must stay free of higher-layer imports and '
                'commercial branching:\n${violations.join('\n')}',
    );
  });
}
