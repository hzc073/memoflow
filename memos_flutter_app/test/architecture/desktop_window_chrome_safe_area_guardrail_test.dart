import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop window chrome safe-area seam stays lower-layer safe', () async {
    final helper = File('lib/core/desktop/window_chrome_safe_area.dart');
    expect(helper.existsSync(), isTrue);

    final contents = await helper.readAsString();
    const forbiddenImports = <String>[
      'package:memos_flutter_app/features/',
      'package:memos_flutter_app/state/',
      'package:memos_flutter_app/application/',
      'package:memos_flutter_app/data/',
      '../../features/',
      '../../state/',
      '../../application/',
      '../../data/',
      '../features/',
      '../state/',
      '../application/',
      '../data/',
    ];

    final violations = <String>[];
    for (final line in contents.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('import ')) continue;
      final match = RegExp(
        r"""^import ['"]([^'"]+)['"];$""",
      ).firstMatch(trimmed);
      if (match == null) continue;
      final importPath = match.group(1)!;
      if (forbiddenImports.any(importPath.startsWith)) {
        violations.add(importPath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'window chrome safe-area seam must not import higher layers:\n'
                '${violations.join('\n')}',
    );
  });

  test('macOS shell and settings window reuse chrome safe-area seam', () async {
    final shell = await File(
      'lib/features/home/desktop/apple_macos_page_shell.dart',
    ).readAsString();
    final settingsWindow = await File(
      'lib/features/settings/desktop_settings_window_app.dart',
    ).readAsString();
    final memoTitleBar = await File(
      'lib/features/memos/widgets/memos_list_macos_desktop_title_bar.dart',
    ).readAsString();

    expect(shell.contains('window_chrome_safe_area.dart'), isTrue);
    expect(
      shell.contains('resolveDesktopWindowChromeInsets') &&
          shell.contains('resolveMacosTrafficLightCompensation'),
      isTrue,
    );
    expect(settingsWindow.contains('window_chrome_safe_area.dart'), isTrue);
    expect(settingsWindow.contains('resolveDesktopWindowChromeInsets'), isTrue);
    expect(memoTitleBar.contains('window_chrome_safe_area.dart'), isTrue);
    expect(
      memoTitleBar.contains(
        'const double kMemosListMacosTrafficLightSafeInset = 92',
      ),
      isFalse,
    );
  });
}
