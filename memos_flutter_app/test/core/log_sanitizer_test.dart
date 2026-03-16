import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/log_sanitizer.dart';

void main() {
  group('LogSanitizer.sanitizeJson', () {
    test('redacts semantic location and search keys with fingerprints', () {
      final sanitized =
          LogSanitizer.sanitizeJson({
                'initialLatitude': 31.230416,
                'initialLongitude': 121.473701,
                'initialPlaceholder': '上海市静安区',
                'query': '人民广场',
                'title': '南京西路',
                'subtitle': '地铁 2 号线附近',
                'city': '上海',
                'reverseGeocodeLabel': '黄浦区人民大道 200 号',
              })
              as Map<String, Object?>;

      expect(
        sanitized['initialLatitude'],
        LogSanitizer.redactSemanticText('31.230416', kind: 'coord'),
      );
      expect(
        sanitized['initialLongitude'],
        LogSanitizer.redactSemanticText('121.473701', kind: 'coord'),
      );
      expect(
        sanitized['initialPlaceholder'],
        LogSanitizer.redactSemanticText('上海市静安区', kind: 'text'),
      );
      expect(
        sanitized['query'],
        LogSanitizer.redactSemanticText('人民广场', kind: 'query'),
      );
      expect(
        sanitized['title'],
        LogSanitizer.redactSemanticText('南京西路', kind: 'title'),
      );
      expect(
        sanitized['subtitle'],
        LogSanitizer.redactSemanticText('地铁 2 号线附近', kind: 'subtitle'),
      );
      expect(
        sanitized['city'],
        LogSanitizer.redactSemanticText('上海', kind: 'city'),
      );
      expect(
        sanitized['reverseGeocodeLabel'],
        LogSanitizer.redactSemanticText('黄浦区人民大道 200 号', kind: 'location'),
      );
    });

    test('redacts session and pagination tokens as opaque values', () {
      final sessionKey = 'https://demo.example.com|alice';
      final pageToken = 'next-page-token-123';
      final sanitized =
          LogSanitizer.sanitizeJson({
                'sessionKey': sessionKey,
                'currentKey': sessionKey,
                'previousKey': sessionKey,
                'nextKey': sessionKey,
                'pendingWorkspaceKey': sessionKey,
                'locationKey':
                    'tree:content://com.example/tree/primary%3AMemos',
                'pageToken': pageToken,
                'nextPageToken': pageToken,
              })
              as Map<String, Object?>;

      expect(sanitized['sessionKey'], LogSanitizer.redactOpaque(sessionKey));
      expect(sanitized['currentKey'], LogSanitizer.redactOpaque(sessionKey));
      expect(sanitized['previousKey'], LogSanitizer.redactOpaque(sessionKey));
      expect(sanitized['nextKey'], LogSanitizer.redactOpaque(sessionKey));
      expect(
        sanitized['pendingWorkspaceKey'],
        LogSanitizer.redactOpaque(sessionKey),
      );
      expect(
        sanitized['locationKey'],
        LogSanitizer.redactOpaque(
          'tree:content://com.example/tree/primary%3AMemos',
        ),
      );
      expect(sanitized['pageToken'], LogSanitizer.redactOpaque(pageToken));
      expect(sanitized['nextPageToken'], LogSanitizer.redactOpaque(pageToken));
    });

    test('redacts path and filename shaped values', () {
      final sanitized =
          LogSanitizer.sanitizeJson({
                'path': r'C:\Users\alice\Videos\clip.mp4',
                'file_path': r'C:\Users\alice\Pictures\memo.png',
                'rootPath': r'C:\Users\alice\MemoFlow',
                'treeUri':
                    'content://com.android.externalstorage.documents/tree/primary%3AMemos',
                'filename': 'family-trip.png',
                'fileName': 'holiday.mov',
              })
              as Map<String, Object?>;

      expect(
        sanitized['path'],
        LogSanitizer.redactPathLike(r'C:\Users\alice\Videos\clip.mp4'),
      );
      expect(
        sanitized['file_path'],
        LogSanitizer.redactPathLike(r'C:\Users\alice\Pictures\memo.png'),
      );
      expect(
        sanitized['rootPath'],
        LogSanitizer.redactPathLike(r'C:\Users\alice\MemoFlow'),
      );
      expect(
        sanitized['treeUri'],
        LogSanitizer.redactPathLike(
          'content://com.android.externalstorage.documents/tree/primary%3AMemos',
        ),
      );
      expect(
        sanitized['filename'],
        LogSanitizer.redactWithFingerprint('family-trip.png', kind: 'file'),
      );
      expect(
        sanitized['fileName'],
        LogSanitizer.redactWithFingerprint('holiday.mov', kind: 'file'),
      );
    });

    test('distinguishes benign and sensitive source values', () {
      final benign =
          LogSanitizer.sanitizeJson({'source': 'system_hotkey'})
              as Map<String, Object?>;
      final sensitive =
          LogSanitizer.sanitizeJson({
                'source': '123|2048|https://cdn.example.com/private/video.mp4',
              })
              as Map<String, Object?>;

      expect(benign['source'], 'system_hotkey');
      expect(
        sensitive['source'],
        LogSanitizer.redactWithFingerprint(
          '123|2048|https://cdn.example.com/private/video.mp4',
          kind: 'source',
        ),
      );
    });

    test('recursively sanitizes nested maps and lists', () {
      final sanitized =
          LogSanitizer.sanitizeJson({
                'items': [
                  {
                    'query': '人民广场',
                    'pageToken': 'cursor-1',
                    'file_path': r'C:\Users\alice\memo.txt',
                  },
                ],
              })
              as Map<String, Object?>;

      final items = sanitized['items'] as List<Object?>;
      final first = items.first as Map<String, Object?>;
      expect(
        first['query'],
        LogSanitizer.redactSemanticText('人民广场', kind: 'query'),
      );
      expect(first['pageToken'], LogSanitizer.redactOpaque('cursor-1'));
      expect(
        first['file_path'],
        LogSanitizer.redactPathLike(r'C:\Users\alice\memo.txt'),
      );
    });
  });

  group('LogSanitizer.sanitizeText', () {
    test('redacts embedded paths workspace keys coordinates tokens and urls', () {
      const workspaceKey = 'https://demo.example.com|alice';
      const windowsPath = r'C:\Users\alice\Documents\memo.txt';
      const fileUri =
          'content://com.android.externalstorage.documents/tree/primary%3AMemos';
      const coords = '31.230416, 121.473701';
      const raw =
          'workspace=$workspaceKey path=$windowsPath file=$fileUri coords=$coords token=abcd123456 https://demo.example.com/api/v1/memos?token=abcd123456';

      final sanitized = LogSanitizer.sanitizeText(raw);

      expect(sanitized, contains(LogSanitizer.redactOpaque(workspaceKey)));
      expect(sanitized, contains(LogSanitizer.redactPathLike(windowsPath)));
      expect(sanitized, contains(LogSanitizer.redactPathLike(fileUri)));
      expect(
        sanitized,
        contains(LogSanitizer.redactSemanticText(coords, kind: 'location')),
      );
      expect(sanitized, contains('token=abcd****56'));
      expect(sanitized, isNot(contains(workspaceKey)));
      expect(sanitized, isNot(contains(windowsPath)));
      expect(sanitized, isNot(contains(fileUri)));
      expect(sanitized, isNot(contains(coords)));
    });
  });
}
