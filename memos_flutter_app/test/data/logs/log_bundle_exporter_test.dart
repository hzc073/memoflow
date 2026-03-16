import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/logs/log_bundle_exporter.dart';

void main() {
  group('extractAiExportLogLines', () {
    test('keeps ai settings and adapter lines only', () {
      final lines = <String>[
        '[2026-03-11T11:00:00.000Z] INFO App: AI settings loaded | ctx={}',
        '[2026-03-11T11:00:01.000Z] INFO App: Sync started | ctx={}',
        '[2026-03-11T11:00:02.000Z] WARN App: AI adapter request failed | ctx={}',
        '[2026-03-11T11:00:03.000Z] INFO App: AI settings model sync finished | ctx={}',
      ];

      expect(
        extractAiExportLogLines(lines),
        equals(<String>[
          '[2026-03-11T11:00:00.000Z] INFO App: AI settings loaded | ctx={}',
          '[2026-03-11T11:00:02.000Z] WARN App: AI adapter request failed | ctx={}',
          '[2026-03-11T11:00:03.000Z] INFO App: AI settings model sync finished | ctx={}',
        ]),
      );
    });
  });

  group('sanitizeJsonLineForExport', () {
    test('keeps exported json lines redacted', () {
      const raw =
          '{"time":"2026-03-11T11:00:00.000Z","pageToken":"cursor-123","sessionKey":"https://demo.example.com|alice","query":"Times Square","file_path":"C:\\\\Users\\\\alice\\\\memo.png"}';

      final sanitized = LogBundleExporter.sanitizeJsonLineForExport(raw);

      expect(sanitized, contains('<opaque_redacted:'));
      expect(sanitized, contains('<query_redacted:'));
      expect(sanitized, contains('<path_redacted:'));
      expect(sanitized, isNot(contains('cursor-123')));
      expect(sanitized, isNot(contains('https://demo.example.com|alice')));
      expect(sanitized, isNot(contains('Times Square')));
      expect(sanitized, isNot(contains(r'C:\Users\alice\memo.png')));
    });
  });
}
