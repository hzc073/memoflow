import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/platform_layout.dart';

void main() {
  group('windows desktop layout helpers', () {
    test('resolveWindowsDesktopLayout maps all width tiers', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        resolveWindowsDesktopLayout(959).tier,
        WindowsDesktopLayoutTier.narrow,
      );
      expect(
        resolveWindowsDesktopLayout(960).tier,
        WindowsDesktopLayoutTier.compact,
      );
      expect(
        resolveWindowsDesktopLayout(1199).tier,
        WindowsDesktopLayoutTier.compact,
      );
      expect(
        resolveWindowsDesktopLayout(1200).tier,
        WindowsDesktopLayoutTier.expanded,
      );
      expect(
        resolveWindowsDesktopLayout(1359).tier,
        WindowsDesktopLayoutTier.expanded,
      );
      expect(
        resolveWindowsDesktopLayout(1360).tier,
        WindowsDesktopLayoutTier.wide,
      );
    });

    test('resolveWindowsDesktopLayout maps nav modes and pane defaults', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final narrow = resolveWindowsDesktopLayout(900);
      final compact = resolveWindowsDesktopLayout(1100);
      final expanded = resolveWindowsDesktopLayout(1280);
      final wide = resolveWindowsDesktopLayout(1600);

      expect(narrow.navMode, WindowsDesktopNavMode.overlay);
      expect(narrow.supportsSecondaryPane, isFalse);
      expect(narrow.defaultSecondaryPaneVisible, isFalse);

      expect(compact.navMode, WindowsDesktopNavMode.rail);
      expect(compact.supportsSecondaryPane, isFalse);
      expect(compact.defaultSecondaryPaneVisible, isFalse);

      expect(expanded.navMode, WindowsDesktopNavMode.expanded);
      expect(expanded.supportsSecondaryPane, isTrue);
      expect(expanded.defaultSecondaryPaneVisible, isFalse);

      expect(wide.navMode, WindowsDesktopNavMode.expanded);
      expect(wide.supportsSecondaryPane, isTrue);
      expect(wide.defaultSecondaryPaneVisible, isTrue);
      expect(wide.defaultSecondaryPaneWidth, 420);
    });

    test('windows nav helpers align with resolved layout', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(shouldUseWindowsOverlayNav(900), isTrue);
      expect(shouldUseWindowsRailNav(900), isFalse);
      expect(shouldUseWindowsExpandedSidebar(900), isFalse);
      expect(shouldUseWindowsSecondaryPane(900), isFalse);

      expect(shouldUseWindowsOverlayNav(1100), isFalse);
      expect(shouldUseWindowsRailNav(1100), isTrue);
      expect(shouldUseWindowsExpandedSidebar(1100), isFalse);
      expect(shouldUseWindowsSecondaryPane(1100), isFalse);

      expect(shouldUseWindowsOverlayNav(1280), isFalse);
      expect(shouldUseWindowsRailNav(1280), isFalse);
      expect(shouldUseWindowsExpandedSidebar(1280), isTrue);
      expect(shouldUseWindowsSecondaryPane(1280), isTrue);
    });

    test('windows helpers are disabled on non-windows platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(shouldUseWindowsOverlayNav(1600), isFalse);
      expect(shouldUseWindowsRailNav(1600), isFalse);
      expect(shouldUseWindowsExpandedSidebar(1600), isFalse);
      expect(shouldUseWindowsSecondaryPane(1600), isFalse);
      expect(resolveWindowsDesktopLayout(1600).supportsSecondaryPane, isFalse);
    });

    test('legacy desktop helpers stay intact during batch 1', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(shouldUseDesktopSidePaneLayout(1099), isFalse);
      expect(shouldUseDesktopSidePaneLayout(1100), isTrue);
      expect(shouldUseDesktopPreviewPaneLayout(1439), isFalse);
      expect(shouldUseDesktopPreviewPaneLayout(1440), isTrue);
    });

    test('desktop preview helper is shared across desktop targets', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(shouldUseDesktopPreviewPaneLayout(1439), isFalse);
      expect(shouldUseDesktopPreviewPaneLayout(1440), isTrue);
      expect(
        shouldUseDesktopPreviewPaneLayout(1440, platform: TargetPlatform.linux),
        isTrue,
      );
      expect(
        shouldUseDesktopPreviewPaneLayout(
          1440,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('inline compose layout uses the shared 760 breakpoint', () {
      expect(shouldUseInlineComposeLayout(759), isFalse);
      expect(shouldUseInlineComposeLayout(760), isTrue);
    });
  });
}
