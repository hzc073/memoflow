import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/features/memos/draft_box_media_entries.dart';

void main() {
  test('extracts inline image urls into media entries', () async {
    final tempDir = await Directory.systemTemp.createTemp('draft_media_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final imageFile = File('${tempDir.path}/inline.png');
    await imageFile.writeAsString('not-an-image');

    final snapshot = ComposeDraftSnapshot(
      content: '![](${Uri.file(imageFile.path)})',
      visibility: 'PRIVATE',
    );

    final entries = buildDraftBoxMediaEntries(snapshot);

    expect(entries, hasLength(1));
    expect(entries.single.isImage, isTrue);
    expect(
      entries.single.image?.localFile?.uri.toFilePath(),
      imageFile.uri.toFilePath(),
    );
  });

  test('maps image and video attachments into media entries', () async {
    final tempDir = await Directory.systemTemp.createTemp('draft_media_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final imageFile = File('${tempDir.path}/photo.png');
    final videoFile = File('${tempDir.path}/clip.mp4');
    await imageFile.writeAsString('image');
    await videoFile.writeAsString('video');

    final snapshot = ComposeDraftSnapshot(
      content: '',
      visibility: 'PRIVATE',
      attachments: [
        ComposeDraftAttachment(
          uid: 'img-1',
          filePath: imageFile.path,
          filename: 'photo.png',
          mimeType: 'image/png',
          size: 12,
        ),
        ComposeDraftAttachment(
          uid: 'video-1',
          filePath: videoFile.path,
          filename: 'clip.mp4',
          mimeType: 'video/mp4',
          size: 42,
        ),
      ],
    );

    final entries = buildDraftBoxMediaEntries(snapshot);

    expect(entries, hasLength(2));
    expect(entries.where((entry) => entry.isImage), hasLength(1));
    expect(entries.where((entry) => entry.isVideo), hasLength(1));
  });

  test('deduplicates inline image and matching attachment path', () async {
    final tempDir = await Directory.systemTemp.createTemp('draft_media_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final imageFile = File('${tempDir.path}/duplicate.png');
    await imageFile.writeAsString('duplicate');

    final snapshot = ComposeDraftSnapshot(
      content: '![](${Uri.file(imageFile.path)})',
      visibility: 'PRIVATE',
      attachments: [
        ComposeDraftAttachment(
          uid: 'img-1',
          filePath: imageFile.path,
          filename: 'duplicate.png',
          mimeType: 'image/png',
          size: 12,
        ),
      ],
    );

    final entries = buildDraftBoxMediaEntries(snapshot);

    expect(entries, hasLength(1));
  });

  test('counts non-media attachments separately', () {
    final snapshot = ComposeDraftSnapshot(
      content: '',
      visibility: 'PRIVATE',
      attachments: const [
        ComposeDraftAttachment(
          uid: 'audio-1',
          filePath: '/tmp/audio.m4a',
          filename: 'audio.m4a',
          mimeType: 'audio/mp4',
          size: 12,
        ),
        ComposeDraftAttachment(
          uid: 'file-1',
          filePath: '/tmp/file.pdf',
          filename: 'file.pdf',
          mimeType: 'application/pdf',
          size: 42,
        ),
        ComposeDraftAttachment(
          uid: 'image-1',
          filePath: '/tmp/image.png',
          filename: 'image.png',
          mimeType: 'image/png',
          size: 10,
        ),
      ],
    );

    expect(countDraftNonMediaAttachments(snapshot), 2);
  });
}
