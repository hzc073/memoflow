import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/desktop/desktop_settings_window.dart';

void main() {
  test('supports desktop settings window on macOS, Windows, and Linux', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      final previousPlatformOverride = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = platform;
      try {
        expect(supportsDesktopSettingsWindow(), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatformOverride;
      }
    }
  });

  test('reports unsupported on non-desktop settings platforms', () async {
    final previousPlatformOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final result = await openDesktopSettingsWindow();

      expect(result.status, DesktopSettingsWindowOpenStatus.unsupported);
      expect(result.shouldFallback, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatformOverride;
    }
  });
}
