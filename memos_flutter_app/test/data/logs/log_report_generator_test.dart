import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/log_sanitizer.dart';
import 'package:memos_flutter_app/data/logs/log_report_generator.dart';

void main() {
  group('LogReportGenerator.formatPaginationTokenForLog', () {
    test('redacts non-empty pagination tokens', () {
      const token = 'next-page-token-123';

      expect(
        LogReportGenerator.formatPaginationTokenForLog(token),
        LogSanitizer.redactOpaque(token),
      );
    });

    test('keeps null and empty token markers stable', () {
      expect(LogReportGenerator.formatPaginationTokenForLog(null), '-');
      expect(LogReportGenerator.formatPaginationTokenForLog(''), '""');
    });
  });
}
