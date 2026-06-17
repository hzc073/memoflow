import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop media preview keeps feature UI out of lower layers', () {
    final channel = File(
      'lib/core/desktop_quick_input_channel.dart',
    ).readAsStringSync();
    final window = File(
      'lib/features/media_preview/desktop_media_preview_window.dart',
    ).readAsStringSync();

    expect(channel.contains('features/media_preview'), isFalse);
    expect(window.contains('application/desktop'), isFalse);
    expect(
      window.contains('features/memos/attachment_gallery_screen.dart'),
      isFalse,
    );
    expect(
      window.contains('features/memos/attachment_video_screen.dart'),
      isFalse,
    );
  });

  test('desktop media entry widgets delegate opening to media presenter', () {
    final files = <String>[
      'lib/features/memos/memo_media_grid.dart',
      'lib/features/memos/memo_video_grid.dart',
      'lib/features/collections/collection_reader_paged_view.dart',
      'lib/features/desktop/quick_input/desktop_quick_input_window.dart',
      'lib/features/resources/resources_screen.dart',
      'lib/features/share/share_clip_screen.dart',
      'lib/features/memos/note_input_sheet.dart',
      'lib/features/explore/explore_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('MediaPreviewLauncher.') ||
            source.contains('ImagePreviewLauncher.open'),
        isTrue,
        reason: '$path should delegate media opening to the shared launcher.',
      );
    }
  });

  test('image preview launcher does not directly push gallery routes', () {
    final source = File(
      'lib/features/image_preview/image_preview_launcher.dart',
    ).readAsStringSync();

    expect(source.contains('Navigator.of'), isFalse);
    expect(source.contains('ImagePreviewGalleryScreen'), isFalse);
    expect(source.contains('MediaPreviewLauncher.openImagePreview'), isTrue);
  });

  test('media viewer chrome uses shared desktop window safe area', () {
    final files = <String>[
      'lib/features/image_preview/widgets/image_preview_gallery_body.dart',
      'lib/features/memos/attachment_gallery_screen.dart',
      'lib/features/memos/attachment_video_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('DesktopWindowChromeSafeArea'),
        isTrue,
        reason: '$path should use the shared desktop chrome safe-area helper.',
      );
      expect(
        source.contains('kMacosTrafficLightReservedWidth'),
        isFalse,
        reason: '$path must not hard-code the macOS traffic-light width.',
      );
    }
  });
}
