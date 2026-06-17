import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/image_preview/image_preview_edit_result.dart';
import 'package:memos_flutter_app/features/image_preview/image_preview_item.dart';
import 'package:memos_flutter_app/features/image_preview/image_preview_open_request.dart';
import 'package:memos_flutter_app/features/media_preview/desktop_media_preview_request.dart';
import 'package:memos_flutter_app/features/media_preview/desktop_media_preview_window.dart';
import 'package:memos_flutter_app/features/memos/attachment_gallery_screen.dart';
import 'package:memos_flutter_app/features/memos/memo_video_grid.dart';

void main() {
  test('desktop media preview window is macOS gated', () {
    expect(
      supportsDesktopMediaPreviewWindow(platform: TargetPlatform.macOS),
      isTrue,
    );
    expect(
      supportsDesktopMediaPreviewWindow(platform: TargetPlatform.windows),
      isFalse,
    );
    expect(
      supportsDesktopMediaPreviewWindow(platform: TargetPlatform.linux),
      isFalse,
    );
    expect(
      isDesktopMediaPreviewSurfacePlatform(platform: TargetPlatform.windows),
      isTrue,
    );
    expect(
      isDesktopMediaPreviewSurfacePlatform(platform: TargetPlatform.linux),
      isTrue,
    );
  });

  test(
    'image request codec preserves renderable sources and headers',
    () async {
      final temp = await File(
        '${Directory.systemTemp.path}/desktop_media_preview_request_test.png',
      ).create();
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete();
        }
      });

      final request = DesktopMediaPreviewRequest.fromImagePreviewOpenRequest(
        ImagePreviewOpenRequest(
          items: <ImagePreviewItem>[
            ImagePreviewItem(
              id: 'local',
              title: 'Local.png',
              mimeType: 'image/png',
              localFile: temp,
              headers: const <String, String>{'Authorization': 'Bearer token'},
              width: 10,
              height: 20,
            ),
            const ImagePreviewItem(
              id: 'stale',
              title: 'Missing.png',
              mimeType: 'image/png',
              localFile: null,
            ),
          ],
          initialIndex: 0,
          enableDownload: false,
        ),
      );

      final decoded = DesktopMediaPreviewRequest.fromJson(request.toJson());
      final retained = decoded.retainAvailableItems();

      expect(retained, isNotNull);
      expect(retained!.items, hasLength(1));
      expect(retained.items.single.id, 'local');
      expect(retained.items.single.headers, contains('Authorization'));
      expect(retained.toImagePreviewOpenRequest().enableDownload, isFalse);
    },
  );

  test('image request codec keeps pending and private remote metadata', () {
    final request = DesktopMediaPreviewRequest.fromImagePreviewOpenRequest(
      const ImagePreviewOpenRequest(
        items: <ImagePreviewItem>[
          ImagePreviewItem(
            id: 'pending:local',
            title: 'Pending.png',
            mimeType: 'image/png',
            fullUrl: 'https://example.test/private.png',
            headers: <String, String>{'Authorization': 'Bearer private'},
          ),
        ],
        initialIndex: 0,
      ),
    );

    final decoded = DesktopMediaPreviewRequest.fromJson(request.toJson());
    final retained = decoded.retainAvailableItems();

    expect(decoded.allowReplaceResult, isFalse);
    expect(retained, isNotNull);
    expect(retained!.items.single.id, startsWith('pending:'));
    expect(retained.items.single.headers, contains('Authorization'));
  });

  test('empty or stale request has no desktop-window payload', () {
    final empty = DesktopMediaPreviewRequest.fromImagePreviewOpenRequest(
      const ImagePreviewOpenRequest(
        items: <ImagePreviewItem>[],
        initialIndex: 0,
      ),
    );
    final stale = DesktopMediaPreviewRequest.fromImagePreviewOpenRequest(
      ImagePreviewOpenRequest(
        items: <ImagePreviewItem>[
          ImagePreviewItem(
            id: 'missing',
            title: 'Missing.png',
            mimeType: 'image/png',
            localFile: File('/definitely/missing/memoflow-preview.png'),
          ),
        ],
        initialIndex: 0,
      ),
    );

    expect(empty.retainAvailableItems(), isNull);
    expect(stale.retainAvailableItems(), isNull);
  });

  test('mixed attachment request round trips image and video items', () {
    final request = DesktopMediaPreviewRequest.fromAttachmentGallery(
      items: <AttachmentGalleryItem>[
        const AttachmentGalleryItem.image(
          AttachmentImageSource(
            id: 'image',
            title: 'Image',
            mimeType: 'image/png',
            imageUrl: 'https://example.test/image.png',
          ),
        ),
        const AttachmentGalleryItem.video(
          MemoVideoEntry(
            id: 'video',
            title: 'Video',
            mimeType: 'video/mp4',
            size: 42,
            videoUrl: 'https://example.test/video.mp4',
          ),
        ),
      ],
      initialIndex: 1,
      enableDownload: true,
      albumName: 'Album',
      allowReplaceResult: false,
    );

    final decoded = DesktopMediaPreviewRequest.fromJson(request.toJson());
    final items = decoded.toAttachmentGalleryItems();

    expect(decoded.safeInitialIndex, 1);
    expect(items, hasLength(2));
    expect(items.first.isImage, isTrue);
    expect(items.last.isVideo, isTrue);
    expect(items.last.video!.videoUrl, 'https://example.test/video.mp4');
  });

  test('replace result codec preserves edit result payload', () {
    const editResult = ImagePreviewEditResult(
      sourceId: 'source',
      filePath: '/tmp/edited.jpg',
      filename: 'edited.jpg',
      mimeType: 'image/jpeg',
      size: 123,
    );

    final result = DesktopMediaPreviewResult.replace(
      requestId: 'request',
      result: editResult,
    );
    final decoded = DesktopMediaPreviewResult.fromJson(result.toJson());

    expect(decoded.requestId, 'request');
    expect(decoded.toImagePreviewEditResult().filePath, editResult.filePath);
    expect(decoded.toImagePreviewEditResult().size, editResult.size);
  });
}
