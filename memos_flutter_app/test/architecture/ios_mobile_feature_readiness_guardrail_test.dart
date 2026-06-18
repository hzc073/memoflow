import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS mobile readiness seam stays layer-safe', () async {
    final root = Directory('lib/platform_capabilities');
    expect(root.existsSync(), isTrue);

    final violations = <String>[];
    for (final entry in root.listSync(recursive: true, followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final source = entry.path.replaceAll('\\', '/');
      final contents = await entry.readAsString();
      for (final match in RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(contents)) {
        final importPath = match.group(1)!.replaceAll('\\', '/');
        if (importPath.startsWith('package:memos_flutter_app/features/') ||
            importPath.startsWith('package:memos_flutter_app/state/') ||
            importPath.startsWith('package:memos_flutter_app/application/') ||
            importPath.startsWith('package:memos_flutter_app/data/') ||
            importPath.startsWith('../features/') ||
            importPath.startsWith('../../features/') ||
            importPath.startsWith('../state/') ||
            importPath.startsWith('../../state/') ||
            importPath.startsWith('../application/') ||
            importPath.startsWith('../../application/') ||
            importPath.startsWith('../data/') ||
            importPath.startsWith('../../data/')) {
          violations.add('$source -> $importPath');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'platform_capabilities must not import higher layers:\n'
                '${violations.join('\n')}',
    );
  });
}
