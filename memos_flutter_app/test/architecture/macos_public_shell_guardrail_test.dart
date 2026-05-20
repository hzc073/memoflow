import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = Directory.current.parent;

  String readRepoFile(String relativePath) {
    return File(
      '${repoRoot.path}${Platform.pathSeparator}$relativePath',
    ).readAsStringSync();
  }

  test(
    'macOS public shell keeps system menu semantics and no commercial leakage',
    () {
      final appDelegate = readRepoFile(
        'memos_flutter_app/macos/Runner/AppDelegate.swift',
      );
      final mainFlutterWindow = readRepoFile(
        'memos_flutter_app/macos/Runner/MainFlutterWindow.swift',
      );
      final menuStrings = readRepoFile(
        'memos_flutter_app/macos/Runner/Base.lproj/MainMenu.strings',
      );
      final app = readRepoFile('memos_flutter_app/lib/app.dart');
      final macosTitleBar = readRepoFile(
        'memos_flutter_app/lib/features/memos/widgets/'
        'memos_list_macos_desktop_title_bar.dart',
      );

      expect(appDelegate.contains('NSApp.mainMenu = buildMainMenu()'), isTrue);
      expect(
        appDelegate.contains('applicationShouldTerminateAfterLastWindowClosed'),
        isTrue,
      );
      expect(
        appDelegate.contains('applicationSupportsSecureRestorableState'),
        isTrue,
      );
      expect(appDelegate.contains('windowMenu()'), isTrue);
      expect(appDelegate.contains('performClose'), isTrue);
      expect(appDelegate.contains('performMiniaturize'), isTrue);
      expect(appDelegate.contains('performZoom'), isTrue);
      expect(appDelegate.contains('toggleFullScreen'), isTrue);
      expect(appDelegate.contains('arrangeInFront'), isTrue);

      expect(
        mainFlutterWindow.contains('MemoFlowMenuDispatcher.shared.configure'),
        isTrue,
      );
      expect(
        mainFlutterWindow.contains(
          'MemoFlowMenuBuilder(dispatcher: MemoFlowMenuDispatcher.shared).install()',
        ),
        isTrue,
      );
      expect(
        mainFlutterWindow.contains(
          'FlutterMultiWindowPlugin.setOnWindowCreatedCallback',
        ),
        isTrue,
      );
      expect(
        mainFlutterWindow.contains('RegisterMemoFlowSubWindowPlugins'),
        isTrue,
      );
      expect(mainFlutterWindow.contains('fullSizeContentView'), isTrue);
      expect(
        mainFlutterWindow.contains('titlebarAppearsTransparent = true'),
        isTrue,
      );
      expect(mainFlutterWindow.contains('titleVisibility = .hidden'), isTrue);
      expect(
        mainFlutterWindow.contains(
          'RegisterGeneratedPlugins(registry: controller)',
        ),
        isFalse,
      );
      expect(mainFlutterWindow.contains('import window_manager'), isFalse);
      expect(
        mainFlutterWindow.contains('WindowManagerPlugin.register'),
        isFalse,
      );
      expect(app.contains('macosMenuCommandChannelName'), isTrue);
      expect(app.contains('macosMenuCommandOpenSettingsWindow'), isTrue);

      expect(menuStrings.contains('"window.close" = "Close";'), isTrue);
      expect(
        menuStrings.contains('"window.fullScreen" = "Enter Full Screen";'),
        isTrue,
      );
      expect(menuStrings.contains('"window.minimize" = "Minimize";'), isTrue);
      expect(menuStrings.contains('"window.zoom" = "Zoom";'), isTrue);
      expect(macosTitleBar.contains('MemosListPillRow'), isTrue);
      expect(
        macosTitleBar.contains('kMemosListMacosTrafficLightSafeInset'),
        isTrue,
      );
      expect(macosTitleBar.contains('Icons.minimize_rounded'), isFalse);
      expect(macosTitleBar.contains('Icons.crop_square_rounded'), isFalse);
      expect(macosTitleBar.contains('Icons.filter_none_rounded'), isFalse);
      expect(macosTitleBar.contains('Icons.close_rounded'), isFalse);
      expect(macosTitleBar.contains('onMinimize'), isFalse);
      expect(macosTitleBar.contains('onToggleMaximize'), isFalse);

      const forbiddenPatterns = <String>[
        'StoreKit',
        'SKPayment',
        'subscription',
        'paywall',
        'receipt',
        'buyout',
        'TestFlight',
        'App Store Connect',
        'notarization',
        'signing secret',
      ];

      final violations = <String>[];
      for (final file in <MapEntry<String, String>>[
        MapEntry(
          'memos_flutter_app/macos/Runner/AppDelegate.swift',
          appDelegate,
        ),
        MapEntry(
          'memos_flutter_app/macos/Runner/MainFlutterWindow.swift',
          mainFlutterWindow,
        ),
        MapEntry(
          'memos_flutter_app/macos/Runner/Base.lproj/MainMenu.strings',
          menuStrings,
        ),
        MapEntry('memos_flutter_app/lib/app.dart', app),
        MapEntry(
          'memos_flutter_app/lib/features/memos/widgets/'
          'memos_list_macos_desktop_title_bar.dart',
          macosTitleBar,
        ),
      ]) {
        for (final pattern in forbiddenPatterns) {
          if (file.value.contains(pattern)) {
            violations.add('${file.key}: $pattern');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'macOS public shell must not leak commercial terms:\n'
                  '${violations.join('\n')}',
      );
    },
  );
}
