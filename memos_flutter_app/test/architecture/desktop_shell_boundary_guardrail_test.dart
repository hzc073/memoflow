import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'feature pages use desktop shell host instead of concrete shell files',
    () async {
      const forbiddenConcreteShellImports = <String>{
        'package:memos_flutter_app/features/home/desktop/apple_macos_page_shell.dart',
        'package:memos_flutter_app/features/home/desktop/windows_desktop_page_shell.dart',
        'package:memos_flutter_app/features/home/desktop/windows_desktop_workspace_shell.dart',
        '../home/desktop/apple_macos_page_shell.dart',
        '../home/desktop/windows_desktop_page_shell.dart',
        '../home/desktop/windows_desktop_workspace_shell.dart',
        '../../home/desktop/apple_macos_page_shell.dart',
        '../../home/desktop/windows_desktop_page_shell.dart',
        '../../home/desktop/windows_desktop_workspace_shell.dart',
        'desktop/apple_macos_page_shell.dart',
        'desktop/windows_desktop_page_shell.dart',
        'desktop/windows_desktop_workspace_shell.dart',
      };

      final violations = <String>[];
      final featuresDir = Directory('lib/features');
      await for (final entry in featuresDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is! File || p.extension(entry.path) != '.dart') continue;
        final relativePath = p
            .relative(entry.path, from: Directory.current.path)
            .replaceAll('\\', '/');
        if (relativePath.startsWith('lib/features/home/desktop/')) {
          continue;
        }

        final contents = await entry.readAsString();
        for (final line in contents.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('import ')) continue;
          final match = RegExp(
            r"""^import ['"]([^'"]+)['"];$""",
          ).firstMatch(trimmed);
          if (match == null) continue;
          final importPath = match.group(1)!;
          if (forbiddenConcreteShellImports.contains(importPath)) {
            violations.add('$relativePath: forbidden import $importPath');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Feature pages must compose desktop UI through '
                  'DesktopShellHost instead of concrete platform shell files:\n'
                  '${violations.join('\n')}',
      );
    },
  );

  test('feature pages do not intercept native window close directly', () async {
    const forbiddenCloseInterceptionPatterns = <String>[
      'onWindowClose(',
      'setPreventClose(',
    ];

    final violations = <String>[];
    final featuresDir = Directory('lib/features');
    await for (final entry in featuresDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is! File || p.extension(entry.path) != '.dart') continue;
      final relativePath = p
          .relative(entry.path, from: Directory.current.path)
          .replaceAll('\\', '/');
      if (relativePath.startsWith('lib/features/home/desktop/')) {
        continue;
      }

      final contents = await entry.readAsString();
      for (final pattern in forbiddenCloseInterceptionPatterns) {
        if (contents.contains(pattern)) {
          violations.add('$relativePath: contains $pattern');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'macOS/native close dispatch must stay in the desktop shell '
                'or application-level close coordinator:\n'
                '${violations.join('\n')}',
    );
  });
}
