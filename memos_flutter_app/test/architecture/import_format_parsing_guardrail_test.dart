import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('import format parsing rules stay outside import screens', () async {
    final screenFile = File('lib/features/import/import_flow_screens.dart');
    final screenContents = await screenFile.readAsString();

    const forbiddenScreenPatterns = <String>[
      'ZipDecoder(',
      'ArchiveFile',
      '_markdownImagePattern',
      '_markdownLinkPattern',
      '_htmlResourcePattern',
      '_genericMarkdownEntries',
      '_parseMarkdownFrontMatter',
    ];

    final violations = forbiddenScreenPatterns
        .where(screenContents.contains)
        .toList(growable: false);

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Import parsing rules should stay out of '
                'import_flow_screens.dart:\n${violations.join('\n')}',
    );
  });

  test('touched import controllers do not depend on features layer', () async {
    const controllerPaths = <String>[
      'lib/state/memos/flomo_import_controller.dart',
      'lib/state/memos/generic_markdown_import_controller.dart',
    ];
    final violations = <String>[];
    final featureImportPattern = RegExp(
      r'''import\s+['"][^'"]*features/[^'"]*['"]''',
    );

    for (final path in controllerPaths) {
      final contents = await File(path).readAsString();
      for (final match in featureImportPattern.allMatches(contents)) {
        violations.add('$path: ${match.group(0)}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Import controllers must not depend on features/*:\n'
                '${violations.join('\n')}',
    );
  });
}
