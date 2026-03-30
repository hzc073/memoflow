import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/attachment_url.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';

void main() {
  group('attachment url helpers', () {
    test('repairs stale resource links missing filename', () {
      const attachment = Attachment(
        name: 'resources/123',
        filename: 'photo.jpg',
        type: 'image/jpeg',
        size: 42,
        externalLink: '/file/resources/123',
      );

      expect(
        normalizeAttachmentRemoteLink(attachment),
        '/file/resources/123/photo.jpg',
      );
    });

    test('resolves repaired remote links against base url', () {
      const attachment = Attachment(
        name: 'attachments/demo',
        filename: 'clip.mp4',
        type: 'video/mp4',
        size: 42,
        externalLink: '/file/attachments/demo',
      );

      expect(
        resolveAttachmentRemoteUrl(
          Uri.parse('https://memo.example.com'),
          attachment,
        ),
        'https://memo.example.com/file/attachments/demo/clip.mp4',
      );
    });

    test('falls back to attachment name when link is missing', () {
      const attachment = Attachment(
        name: 'resources/123',
        filename: 'doc.pdf',
        type: 'application/pdf',
        size: 42,
        externalLink: '',
      );

      expect(
        resolveAttachmentRemoteUrl(
          Uri.parse('https://memo.example.com/base/'),
          attachment,
        ),
        'https://memo.example.com/base/file/resources/123/doc.pdf',
      );
    });
  });
}
