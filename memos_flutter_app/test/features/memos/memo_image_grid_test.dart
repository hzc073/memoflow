import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/features/memos/memo_image_grid.dart';

void main() {
  test('collectMemoImageEntries resolves html memos resource urls', () {
    final entries = collectMemoImageEntries(
      content: '<p>hello</p><img src="/file/resources/demo/image.jpg">',
      attachments: const [],
      baseUrl: Uri.parse('http://example.com:5230'),
      authHeader: 'Bearer token',
    );

    expect(entries, hasLength(1));
    expect(
      entries.first.fullUrl,
      'http://example.com:5230/file/resources/demo/image.jpg',
    );
    expect(
      entries.first.previewUrl,
      'http://example.com:5230/file/resources/demo/image.jpg?thumbnail=true',
    );
    expect(entries.first.headers, {'Authorization': 'Bearer token'});
  });

  test('collectMemoImageEntries prefers local files for inline html images', () {
    final localUrl = Uri.file(
      '${Directory.systemTemp.path}${Platform.pathSeparator}memo-inline-image.jpg',
    ).toString();

    final entries = collectMemoImageEntries(
      content: '<img src="$localUrl">',
      attachments: const [],
      baseUrl: null,
      authHeader: null,
    );

    expect(entries, hasLength(1));
    expect(entries.first.localFile, isNotNull);
    expect(entries.first.fullUrl, isNull);
    expect(entries.first.previewUrl, isNull);
  });

  test(
    'collectMemoImageEntries ignores html image examples in fenced code',
    () {
      final entries = collectMemoImageEntries(
        content: '```html\n<img src="https://example.com/in-code.png">\n```',
        attachments: const [],
        baseUrl: Uri.parse('https://example.com'),
        authHeader: null,
      );

      expect(entries, isEmpty);
    },
  );

  test(
    'attachment image entries preserve intrinsic dimensions for gallery',
    () {
      final entries = collectMemoImageEntries(
        content: '',
        attachments: const [
          Attachment(
            name: 'attachments/demo',
            filename: 'demo.jpg',
            type: 'image/jpeg',
            size: 1024,
            externalLink: '',
            width: 1080,
            height: 2400,
          ),
        ],
        baseUrl: Uri.parse('https://example.com'),
        authHeader: null,
      );

      expect(entries, hasLength(1));
      final source = entries.first.toGallerySource();
      expect(source.width, 1080);
      expect(source.height, 2400);
    },
  );
}
