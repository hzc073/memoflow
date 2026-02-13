import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/server_api_profile.dart';

void main() {
  group('MemosServerApiProfiles.resolve', () {
    test('prefers manual override over detected version', () {
      final resolved = MemosServerApiProfiles.resolve(
        manualVersionOverride: '0.23.4',
        detectedVersion: '0.26.0',
      );
      expect(resolved.source, MemosVersionSource.manualOverride);
      expect(resolved.effectiveVersion, '0.23.4');
      expect(resolved.profile.flavor, MemosServerFlavor.v0_23);
    });

    test('uses detected version when no manual override', () {
      final resolved = MemosServerApiProfiles.resolve(
        manualVersionOverride: '',
        detectedVersion: '0.24.4',
      );
      expect(resolved.source, MemosVersionSource.detectedProfile);
      expect(resolved.effectiveVersion, '0.24.4');
      expect(resolved.profile.flavor, MemosServerFlavor.v0_24);
    });

    test('falls back to 0.25 profile when no version is available', () {
      final resolved = MemosServerApiProfiles.resolve(
        manualVersionOverride: '',
        detectedVersion: '',
      );
      expect(resolved.source, MemosVersionSource.fallbackDefault);
      expect(resolved.effectiveVersion, MemosServerApiProfiles.fallbackVersion);
      expect(resolved.profile.flavor, MemosServerFlavor.v0_25Plus);
    });
  });

  group('MemosServerApiProfiles.matrix', () {
    test('maps legacy API default by version family', () {
      expect(MemosServerApiProfiles.defaultUseLegacyApi('0.21.0'), isTrue);
      expect(MemosServerApiProfiles.defaultUseLegacyApi('0.22.9'), isTrue);
      expect(MemosServerApiProfiles.defaultUseLegacyApi('0.23.0'), isFalse);
      expect(MemosServerApiProfiles.defaultUseLegacyApi('0.24.4'), isFalse);
      expect(MemosServerApiProfiles.defaultUseLegacyApi('0.25.0'), isFalse);
      expect(MemosServerApiProfiles.defaultUseLegacyApi(''), isFalse);
      expect(MemosServerApiProfiles.defaultUseLegacyApi('unknown'), isFalse);
    });

    test('maps memo state field across versions', () {
      expect(
        MemosServerApiProfiles.byVersionString('0.21.0').memoStateField,
        MemosMemoStateRouteField.rowStatus,
      );
      expect(
        MemosServerApiProfiles.byVersionString('0.22.0').memoStateField,
        MemosMemoStateRouteField.rowStatus,
      );
      expect(
        MemosServerApiProfiles.byVersionString('0.23.0').memoStateField,
        MemosMemoStateRouteField.rowStatus,
      );
      expect(
        MemosServerApiProfiles.byVersionString('0.24.0').memoStateField,
        MemosMemoStateRouteField.state,
      );
      expect(
        MemosServerApiProfiles.byVersionString('0.25.0').memoStateField,
        MemosMemoStateRouteField.state,
      );
    });

    test('keeps 0.23 user stats on legacy memo stats route', () {
      expect(
        MemosServerApiProfiles.byVersionString('0.23.0').defaultUserStatsMode,
        MemosUserStatsRouteMode.legacyMemoStats,
      );
    });
  });

  group('MemosServerApiProfiles.normalizeVersionOverride', () {
    test('normalizes with explicit patch', () {
      expect(
        MemosServerApiProfiles.normalizeVersionOverride('0.22'),
        equals('0.22.0'),
      );
      expect(
        MemosServerApiProfiles.normalizeVersionOverride(' 0.23.7 '),
        equals('0.23.7'),
      );
    });

    test('throws on invalid version syntax', () {
      expect(
        () => MemosServerApiProfiles.normalizeVersionOverride('v0.24'),
        throwsFormatException,
      );
    });
  });
}
