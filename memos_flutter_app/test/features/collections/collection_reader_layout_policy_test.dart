import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_layout_policy.dart';

void main() {
  test('desktop wide viewport uses centered standard readable width', () {
    final layout = resolveCollectionReaderLayout(
      platform: TargetPlatform.windows,
      viewportSize: const Size(1440, 900),
      contentWidthMode: CollectionReaderContentWidthMode.standard,
    );

    expect(layout.isDesktop, isTrue);
    expect(layout.contentWidth, kCollectionReaderStandardContentWidth);
    expect(layout.readableViewportSize, const Size(820, 900));
    expect(layout.horizontalGutter, 310);
    expect(layout.controlMaxWidth, 980);
  });

  test('desktop narrow viewport falls back to available width', () {
    final layout = resolveCollectionReaderLayout(
      platform: TargetPlatform.linux,
      viewportSize: const Size(620, 760),
      contentWidthMode: CollectionReaderContentWidthMode.standard,
    );

    expect(layout.contentWidth, 620);
    expect(layout.readableViewportSize, const Size(620, 760));
    expect(layout.horizontalGutter, 0);
    expect(layout.controlMaxWidth, 620);
  });

  test('mobile viewport keeps full available width', () {
    final layout = resolveCollectionReaderLayout(
      platform: TargetPlatform.android,
      viewportSize: const Size(390, 820),
      contentWidthMode: CollectionReaderContentWidthMode.narrow,
    );

    expect(layout.isDesktop, isFalse);
    expect(layout.contentWidth, 390);
    expect(layout.readableViewportSize, const Size(390, 820));
    expect(layout.horizontalGutter, 0);
    expect(layout.controlMaxWidth, 390);
  });

  test('full width mode follows desktop window width', () {
    final layout = resolveCollectionReaderLayout(
      platform: TargetPlatform.windows,
      viewportSize: const Size(1440, 900),
      contentWidthMode: CollectionReaderContentWidthMode.full,
    );

    expect(layout.contentWidth, 1440);
    expect(layout.readableViewportSize, const Size(1440, 900));
    expect(layout.horizontalGutter, 0);
    expect(layout.controlMaxWidth, 1440);
  });

  test('macOS layout subtracts titlebar chrome from readable height', () {
    final layout = resolveCollectionReaderLayout(
      platform: TargetPlatform.macOS,
      viewportSize: const Size(1200, 900),
      contentWidthMode: CollectionReaderContentWidthMode.standard,
    );

    expect(layout.topChromeInset, kMacosTitleBarHeight);
    expect(
      layout.readableViewportSize,
      const Size(820, 900 - kMacosTitleBarHeight),
    );
    expect(layout.horizontalGutter, 190);
  });
}
