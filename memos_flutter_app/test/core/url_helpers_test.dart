import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/url.dart';

void main() {
  group('url helpers', () {
    test('isServerVersion024 matches only 0.24.x', () {
      expect(isServerVersion024('0.24.0'), isTrue);
      expect(isServerVersion024('0.24.4'), isTrue);
      expect(isServerVersion024('0.24.4-beta1'), isTrue);
      expect(isServerVersion024('0.23.0'), isFalse);
      expect(isServerVersion024('0.25.0'), isFalse);
      expect(isServerVersion024(''), isFalse);
    });

    test('isSameOriginWithBase treats default HTTP port as same origin', () {
      final base = Uri.parse('http://example.com');
      final same = isSameOriginWithBase(
        base,
        'http://example.com:80/file/resources/1/a.png',
      );
      expect(same, isTrue);
    });

    test('isSameOriginWithBase rejects different host', () {
      final base = Uri.parse('http://example.com:35230');
      final same = isSameOriginWithBase(
        base,
        'http://cdn.example.com:35230/file/resources/1/a.png',
      );
      expect(same, isFalse);
    });

    test('rebaseAbsoluteFileUrlToBase keeps path and query', () {
      final base = Uri.parse('http://192.168.13.13:35230');
      final rebased = rebaseAbsoluteFileUrlToBase(
        base,
        'http://another-host:8080/file/resources/15/clip.mp4?thumbnail=true',
      );
      expect(
        rebased,
        equals(
          'http://192.168.13.13:35230/file/resources/15/clip.mp4?thumbnail=true',
        ),
      );
    });

    test('rebaseAbsoluteFileUrlToBase ignores non-file urls', () {
      final base = Uri.parse('http://192.168.13.13:35230');
      final rebased = rebaseAbsoluteFileUrlToBase(
        base,
        'https://example.com/assets/video.mp4',
      );
      expect(rebased, isNull);
    });
  });
}
