import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/desktop_window_policy.dart';
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

  test(
    'direct window manager close calls stay in approved lifecycle paths',
    () async {
      const approvedDirectCloseFiles = <String>{
        'lib/application/desktop/desktop_exit_coordinator.dart',
        'lib/application/desktop/desktop_tray_controller.dart',
        'lib/features/desktop/quick_input/desktop_quick_input_window.dart',
        'lib/features/settings/desktop_settings_window_app.dart',
      };

      final violations = <String>[];
      final libDir = Directory('lib');
      await for (final entry in libDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is! File || p.extension(entry.path) != '.dart') continue;
        final relativePath = p
            .relative(entry.path, from: Directory.current.path)
            .replaceAll('\\', '/');
        final contents = await entry.readAsString();
        if (!contents.contains('windowManager.close(')) continue;
        if (approvedDirectCloseFiles.contains(relativePath)) continue;

        violations.add('$relativePath: contains windowManager.close(');
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'User-facing desktop shell close controls must route through '
                  'DesktopExitCoordinator.requestClose or an injected close '
                  'command. Direct windowManager.close calls are reserved for '
                  'approved lifecycle termination or documented subwindow '
                  'fallbacks:\n${violations.join('\n')}',
      );
    },
  );

  test('macOS close-to-menu-bar stays in desktop lifecycle seams', () async {
    final coordinator = await File(
      'lib/application/desktop/desktop_exit_coordinator.dart',
    ).readAsString();
    final trayController = await File(
      'lib/application/desktop/desktop_tray_controller.dart',
    ).readAsString();
    final desktopSettings = await File(
      'lib/features/settings/desktop_settings_screen.dart',
    ).readAsString();

    expect(coordinator, contains('macosCloseToMenuBar'));
    expect(coordinator, contains('_resolveMacosCloseRequestAction('));
    expect(coordinator, contains('DesktopCloseRequestAction.hideToMenuBar'));
    expect(coordinator, contains('DesktopCloseRequestAction.fullExit'));
    expect(
      coordinator,
      contains('DesktopTrayController.instance.hideToStatusArea()'),
    );
    expect(coordinator, contains('Platform.isMacOS'));
    expect(coordinator, contains('windowManager.destroy()'));
    expect(trayController, contains('Future<void> hideToStatusArea()'));
    expect(trayController, contains('Future<void> showFromStatusArea()'));
    expect(desktopSettings, contains('setMacosCloseToMenuBar'));
    expect(desktopSettings, isNot(contains('windowManager.')));
    expect(desktopSettings, isNot(contains('DesktopTrayController')));
  });

  test(
    'main window minimum-size policy is applied in Dart and native runners',
    () async {
      final mainDart = await File('lib/main.dart').readAsString();
      final windowsRunner = await File(
        'windows/runner/main.cpp',
      ).readAsString();
      final macosRunner = await File(
        'macos/Runner/MainFlutterWindow.swift',
      ).readAsString();
      final initialWidth = kMemoFlowDesktopMainWindowInitialSize.width.toInt();
      final initialHeight = kMemoFlowDesktopMainWindowInitialSize.height
          .toInt();
      final minimumWidth = kMemoFlowDesktopMainWindowMinimumSize.width.toInt();
      final minimumHeight = kMemoFlowDesktopMainWindowMinimumSize.height
          .toInt();

      expect(mainDart, contains('resolveDesktopMainWindowPolicy('));
      expect(mainDart, contains('minimumSize: mainWindowPolicy.minimumSize'));
      expect(
        windowsRunner,
        contains('Win32Window::Size size($initialWidth, $initialHeight)'),
      );
      expect(
        windowsRunner,
        contains('Win32Window::Size($minimumWidth, $minimumHeight)'),
      );
      expect(
        macosRunner,
        contains('NSSize(width: $initialWidth, height: $initialHeight)'),
      );
      expect(
        macosRunner,
        contains('NSSize(width: $minimumWidth, height: $minimumHeight)'),
      );
    },
  );

  test('desktop platform shells consume shared surface policy', () async {
    final files = <String, List<String>>{
      'lib/features/home/desktop/windows_desktop_workspace_shell.dart': [
        'resolveDesktopSurfacePolicy(',
        'surfacePolicy.secondaryPane',
        'surfacePolicy.modalSurface',
      ],
      'lib/features/home/desktop/apple_macos_page_shell.dart': [
        'resolveDesktopSurfacePolicy(',
        'surfacePolicy.secondaryPane',
        'surfacePolicy.modalSurface',
      ],
    };

    final violations = <String>[];
    for (final entry in files.entries) {
      final contents = await File(entry.key).readAsString();
      for (final requiredPattern in entry.value) {
        if (!contents.contains(requiredPattern)) {
          violations.add('${entry.key}: missing $requiredPattern');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Desktop platform shells accept secondary pane and modal surface '
                'inputs, so they must consume the shared desktop surface '
                'policy instead of silently ignoring policy fields:\n'
                '${violations.join('\n')}',
    );
  });

  test('pure desktop policy files keep higher layers out', () async {
    const forbiddenImportPrefixes = <String>{
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
    };

    final violations = <String>[];
    final desktopPolicyDir = Directory('lib/core/desktop');
    await for (final entry in desktopPolicyDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is! File || p.extension(entry.path) != '.dart') continue;
      final relativePath = p
          .relative(entry.path, from: Directory.current.path)
          .replaceAll('\\', '/');
      final contents = await entry.readAsString();
      for (final line in contents.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import ')) continue;
        final match = RegExp(
          r"""^import ['"]([^'"]+)['"];$""",
        ).firstMatch(trimmed);
        if (match == null) continue;
        final importPath = match.group(1)!.replaceAll('\\', '/');
        if (forbiddenImportPrefixes.any(importPath.startsWith)) {
          violations.add('$relativePath: forbidden import $importPath');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Pure desktop policy files must stay in the common layer and '
                'must not import features, state, application, data, or API '
                'code:\n${violations.join('\n')}',
    );
  });

  test(
    'desktop shell files consume shared layout and surface policies',
    () async {
      final requiredPatterns = <String, List<String>>{
        'lib/features/home/desktop/apple_macos_page_shell.dart': [
          'resolveDesktopLayoutPolicy(',
          'resolveDesktopSurfacePolicy(',
          'surfacePolicy.secondaryPane',
          'surfacePolicy.modalSurface',
        ],
        'lib/features/home/desktop/windows_desktop_page_shell.dart': [
          'resolveDesktopLayoutPolicy(',
          'WindowsDesktopWorkspaceShell(',
        ],
        'lib/features/home/desktop/windows_desktop_workspace_shell.dart': [
          'resolveDesktopSurfacePolicy(',
          'surfacePolicy.secondaryPane',
          'surfacePolicy.modalSurface',
        ],
      };

      final forbiddenPatterns = <String, List<String>>{
        'lib/features/home/desktop/apple_macos_page_shell.dart': [
          'resolveWindowsDesktopLayout(',
          'shouldUseDesktopSidePaneLayout(',
        ],
        'lib/features/home/desktop/windows_desktop_page_shell.dart': [
          'resolveWindowsDesktopLayout(',
          'shouldUseDesktopSidePaneLayout(',
        ],
      };

      final violations = <String>[];
      for (final entry in requiredPatterns.entries) {
        final contents = await File(entry.key).readAsString();
        for (final requiredPattern in entry.value) {
          if (!contents.contains(requiredPattern)) {
            violations.add('${entry.key}: missing $requiredPattern');
          }
        }
      }
      for (final entry in forbiddenPatterns.entries) {
        final contents = await File(entry.key).readAsString();
        for (final forbiddenPattern in entry.value) {
          if (contents.contains(forbiddenPattern)) {
            violations.add('${entry.key}: contains $forbiddenPattern');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Desktop shell files must consume shared desktop layout/surface '
                  'policies instead of duplicating platform-local breakpoint '
                  'or kernel decisions:\n${violations.join('\n')}',
      );
    },
  );

  test('feature desktop kernel behavior branches stay documented or migrated', () async {
    const legacyExceptions = <String>{
      // Existing destination pages still use the legacy side-pane helper
      // while they are being migrated onto DesktopDestinationShell/kernel
      // presentation models.
      'lib/features/about/about_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/collections/collections_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/explore/explore_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/memos/draft_box_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/memos/recycle_bin_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/notifications/notifications_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/resources/resources_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/review/ai_summary_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/review/daily_review_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/settings/settings_screen.dart:shouldUseDesktopSidePaneLayout(',
      'lib/features/tags/tags_screen.dart:shouldUseDesktopSidePaneLayout(',
      // Explore still owns a legacy Windows preview-pane mapping until its
      // utility view is migrated to the shared surface/layout kernel.
      'lib/features/explore/explore_screen.dart:resolveWindowsDesktopLayout(',
      // Route delegate still needs to know whether a drawer shortcut should
      // open an overlay drawer or report that the desktop pane is pinned.
      'lib/features/memos/memos_list_route_delegate.dart:shouldUseDesktopSidePaneLayout(',
      // Documented subwindow final-close exceptions.
      'lib/features/desktop/quick_input/desktop_quick_input_window.dart:windowManager.close(',
      'lib/features/settings/desktop_settings_window_app.dart:windowManager.close(',
    };

    const forbiddenKernelPatterns = <String>[
      'shouldUseDesktopSidePaneLayout(',
      'shouldUseDesktopPreviewPaneLayout(',
      'resolveWindowsDesktopLayout(',
      'WindowsDesktopLayoutTier',
      'WindowsDesktopLayoutSpec',
      'openWindowsHeaderSearch',
      'closeWindowsHeaderSearch',
      'toggleWindowsHeaderSearch',
      'showWindowsDesktopNoteInput',
      '_showWindowsDesktop',
      'buildDesktopSharedAxisRoute(',
      'windowManager.close(',
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
      for (final pattern in forbiddenKernelPatterns) {
        if (!contents.contains(pattern)) continue;
        final key = '$relativePath:$pattern';
        if (legacyExceptions.contains(key)) continue;
        violations.add(key);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Feature pages must not add Windows/macOS desktop kernel '
                'branches for route motion, layout, surface, search, '
                'compose, preview, or main-window close without a '
                'documented exception:\n${violations.join('\n')}',
    );
  });
}
