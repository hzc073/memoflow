import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/desktop_titlebar_navigation_policy.dart';

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

  test('desktop secondary task surface seam stays lower-layer safe', () async {
    final helper = File(
      'lib/platform/widgets/platform_secondary_task_surface.dart',
    );
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
          : 'secondary task surface seam must not import higher layers:\n'
                '${violations.join('\n')}',
    );
    expect(
      contents.contains('kMacosTrafficLightReservedWidth'),
      isFalse,
      reason: 'task surfaces should use dialog geometry, not magic padding.',
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
    final platformPage = await File(
      'lib/platform/widgets/platform_page.dart',
    ).readAsString();
    final shareTaskWindow = await File(
      'lib/features/share/desktop_share_task_window_app.dart',
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
    expect(platformPage.contains('window_chrome_safe_area.dart'), isTrue);
    expect(
      platformPage.contains('desktopWindowChromeSafeArea') &&
          platformPage.contains('resolveDesktopWindowChromeInsets'),
      isTrue,
    );
    expect(
      shareTaskWindow.contains('desktopWindowChromeSafeArea: true'),
      isTrue,
    );
    expect(
      shareTaskWindow.contains('kMacosTrafficLightReservedWidth'),
      isFalse,
    );
  });

  test('desktop secondary pages consume shared chrome safe-area seam', () async {
    final consumers = <String, String>{
      'stats screen': 'lib/features/stats/stats_screen.dart',
      'sync queue screen': 'lib/features/sync/sync_queue_screen.dart',
      'notifications screen':
          'lib/features/notifications/notifications_screen.dart',
    };

    for (final entry in consumers.entries) {
      final source = await File(entry.value).readAsString();
      expect(
        source.contains('desktopWindowChromeSafeArea: true'),
        isTrue,
        reason:
            '${entry.key} should opt into the shared desktop chrome safe-area.',
      );
      expect(
        source.contains('kMacosTrafficLightReservedWidth'),
        isFalse,
        reason:
            '${entry.key} must not use page-local macOS traffic-light padding.',
      );
    }
  });

  test('collection reader overlay uses shared chrome safe-area seam', () async {
    final overlay = await File(
      'lib/features/collections/collection_reader_overlay.dart',
    ).readAsString();

    expect(overlay.contains('window_chrome_safe_area.dart'), isTrue);
    expect(overlay.contains('DesktopWindowChromeSafeArea'), isTrue);
    expect(
      overlay.contains('contentExtendsIntoTitleBar: true'),
      isTrue,
      reason:
          'reader overlay top controls should avoid macOS traffic lights through the shared seam.',
    );
    expect(
      overlay.contains('kMacosTrafficLightReservedWidth'),
      isFalse,
      reason: 'reader overlay must not hardcode traffic-light padding.',
    );
  });

  test(
    'collection reader layout policy centralizes desktop chrome calculations',
    () async {
      final policy = await File(
        'lib/features/collections/collection_reader_layout_policy.dart',
      ).readAsString();
      final shell = await File(
        'lib/features/collections/collection_reader_shell.dart',
      ).readAsString();

      expect(policy.contains('window_chrome_safe_area.dart'), isTrue);
      expect(policy.contains('resolveDesktopWindowChromeInsets'), isTrue);
      expect(policy.contains('kMacosTrafficLightReservedWidth'), isFalse);
      expect(shell.contains('collection_reader_layout_policy.dart'), isTrue);
      expect(shell.contains('resolveCollectionReaderLayout'), isTrue);
      expect(shell.contains('window_chrome_safe_area.dart'), isFalse);
      expect(shell.contains('resolveDesktopWindowChromeInsets'), isFalse);
      expect(shell.contains('kMacosTrafficLightReservedWidth'), isFalse);
    },
  );

  test(
    'collection reader files do not hardcode macOS traffic-light layout',
    () async {
      final readerFiles = Directory('lib/features/collections')
          .listSync()
          .whereType<File>()
          .where((file) {
            final name = file.uri.pathSegments.last;
            return name.startsWith('collection_reader') &&
                name.endsWith('.dart');
          });
      final violations = <String>[];

      for (final file in readerFiles) {
        final source = await file.readAsString();
        if (source.contains('kMacosTrafficLightReservedWidth')) {
          violations.add(file.path);
        }
        if (source.contains('resolveDesktopWindowChromeInsets') &&
            !file.path.endsWith('collection_reader_layout_policy.dart')) {
          violations.add('${file.path} bypasses reader layout policy');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'reader layout must route chrome geometry through the shared seam '
                  'and feature-local policy:\n${violations.join('\n')}',
      );
    },
  );

  test(
    'collection reader layout policy has no lower-layer reverse imports',
    () async {
      final policy = await File(
        'lib/features/collections/collection_reader_layout_policy.dart',
      ).readAsString();
      const forbiddenPolicyImports = <String>[
        'package:memos_flutter_app/state/',
        'package:memos_flutter_app/application/',
        'package:memos_flutter_app/features/',
        '../../state/',
        '../../application/',
        '../../features/',
        '../state/',
        '../application/',
        '../features/',
      ];
      final policyImportViolations = <String>[];

      for (final line in policy.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import ')) continue;
        final match = RegExp(
          r"""^import ['"]([^'"]+)['"];$""",
        ).firstMatch(trimmed);
        if (match == null) continue;
        final importPath = match.group(1)!;
        if (forbiddenPolicyImports.any(importPath.startsWith)) {
          policyImportViolations.add(importPath);
        }
      }

      expect(
        policyImportViolations,
        isEmpty,
        reason: policyImportViolations.isEmpty
            ? null
            : 'layout policy must stay feature-local and pure:\n'
                  '${policyImportViolations.join('\n')}',
      );

      final lowerLayerViolations = <String>[];
      for (final root in <String>['lib/state', 'lib/application', 'lib/core']) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = await entity.readAsString();
          if (source.contains('collection_reader_layout_policy.dart')) {
            lowerLayerViolations.add(entity.path);
          }
        }
      }

      expect(
        lowerLayerViolations,
        isEmpty,
        reason: lowerLayerViolations.isEmpty
            ? null
            : 'state/application/core must not import collection reader policy:\n'
                  '${lowerLayerViolations.join('\n')}',
      );
    },
  );

  test('desktop secondary routes keep app-level back controls visible', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        debugDesktopRouteDismissalControlPolicy(
          platform: platform,
          navigationContext: DesktopTitlebarNavigationContext.secondaryTask,
        ),
        'visible',
      );
    }
  });

  test('migrated collections task flows use shared task surface helpers', () async {
    final collectionEditor = await File(
      'lib/features/collections/collection_editor_screen.dart',
    ).readAsString();
    final manualManage = await File(
      'lib/features/collections/manual_collection_manage_screen.dart',
    ).readAsString();

    expect(collectionEditor.contains('openCollectionEditor'), isTrue);
    expect(collectionEditor.contains('PlatformSecondaryTaskFrame'), isTrue);
    expect(
      collectionEditor.contains('showPlatformSecondaryTaskSurface'),
      isTrue,
    );
    expect(
      collectionEditor.contains('kMacosTrafficLightReservedWidth'),
      isFalse,
    );
    expect(manualManage.contains('openManualCollectionManage'), isTrue);
    expect(manualManage.contains('PlatformSecondaryTaskFrame'), isTrue);
    expect(manualManage.contains('kMacosTrafficLightReservedWidth'), isFalse);

    final migratedEntries = <String, String>{
      'collections screen': 'lib/features/collections/collections_screen.dart',
      'add to collection sheet':
          'lib/features/collections/add_to_collection_sheet.dart',
      'collection reader screen':
          'lib/features/collections/collection_reader_screen.dart',
      'collection reader shell':
          'lib/features/collections/collection_reader_shell.dart',
      'collection article flow':
          'lib/features/collections/collection_article_flow_screen.dart',
    };

    for (final entry in migratedEntries.entries) {
      final source = await File(entry.value).readAsString();
      expect(
        source.contains('openCollectionEditor'),
        isTrue,
        reason: '${entry.key} should use the shared editor presenter.',
      );
      expect(
        source.contains('CollectionEditorScreen('),
        isFalse,
        reason:
            '${entry.key} must not directly push the editor as a page-local AppBar flow.',
      );
    }

    final shell = await File(
      'lib/features/collections/collection_reader_shell.dart',
    ).readAsString();
    expect(shell.contains('openManualCollectionManage'), isTrue);
    expect(
      shell.contains('ManualCollectionManageScreen('),
      isFalse,
      reason:
          'reader shell must not directly push manual collection management as a page-local AppBar flow.',
    );
  });

  test('migrated settings task flows use shared task surface helpers', () async {
    final shortcutEditor = await File(
      'lib/features/settings/shortcut_editor_screen.dart',
    ).readAsString();
    final aiWizard = await File(
      'lib/features/settings/ai_service_wizard_screen.dart',
    ).readAsString();

    expect(shortcutEditor.contains('openShortcutEditor'), isTrue);
    expect(shortcutEditor.contains('PlatformSecondaryTaskFrame'), isTrue);
    expect(shortcutEditor.contains('showPlatformSecondaryTaskSurface'), isTrue);
    expect(shortcutEditor.contains('kMacosTrafficLightReservedWidth'), isFalse);

    expect(aiWizard.contains('openAiServiceWizard'), isTrue);
    expect(aiWizard.contains('PlatformSecondaryTaskFrame'), isTrue);
    expect(aiWizard.contains('showPlatformSecondaryTaskSurface'), isTrue);
    expect(aiWizard.contains('kMacosTrafficLightReservedWidth'), isFalse);
    expect(
      aiWizard.contains('AiProxySettingsScreen'),
      isTrue,
      reason:
          'The wizard proxy settings route is intentionally outside this migration.',
    );

    final migratedEntries =
        <String, ({String path, String helper, String direct})>{
          'shortcuts settings': (
            path: 'lib/features/settings/shortcuts_settings_screen.dart',
            helper: 'openShortcutEditor',
            direct: 'ShortcutEditorScreen(',
          ),
          'memos route delegate': (
            path: 'lib/features/memos/memos_list_route_delegate.dart',
            helper: 'openShortcutEditor',
            direct: 'ShortcutEditorScreen(',
          ),
          'AI settings': (
            path: 'lib/features/settings/ai_settings_screen.dart',
            helper: 'openAiServiceWizard',
            direct: 'AiServiceWizardScreen(',
          ),
        };

    for (final entry in migratedEntries.entries) {
      final source = await File(entry.value.path).readAsString();
      expect(
        source.contains(entry.value.helper),
        isTrue,
        reason: '${entry.key} should use the shared task presenter.',
      );
      expect(
        source.contains(entry.value.direct),
        isFalse,
        reason:
            '${entry.key} must not directly push the task page as a page-local AppBar flow.',
      );
    }

    final lowerLayerViolations = <String>[];
    for (final root in <String>['lib/state', 'lib/application', 'lib/core']) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = await entity.readAsString();
        if (source.contains('features/settings/shortcut_editor_screen.dart') ||
            source.contains(
              'features/settings/ai_service_wizard_screen.dart',
            ) ||
            source.contains('openShortcutEditor(') ||
            source.contains('openAiServiceWizard(')) {
          lowerLayerViolations.add(entity.path);
        }
      }
    }

    expect(
      lowerLayerViolations,
      isEmpty,
      reason: lowerLayerViolations.isEmpty
          ? null
          : 'state/application/core must not import settings task presenters:\n'
                '${lowerLayerViolations.join('\n')}',
    );
  });

  test('desktop settings app-owned close stays platform gated', () async {
    final settingsWindow = await File(
      'lib/features/settings/desktop_settings_window_app.dart',
    ).readAsString();

    expect(settingsWindow.contains('showAppCloseButton'), isTrue);
    expect(settingsWindow.contains('TargetPlatform.macOS'), isTrue);
    expect(settingsWindow.contains('if (showAppCloseButton)'), isTrue);
  });
}
