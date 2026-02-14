import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/server_api_profile.dart';
import 'package:memos_flutter_app/data/api/server_route_adapter.dart';

void main() {
  group('MemosRouteAdapters.resolve', () {
    test('0.23 requires full memo view and row_status state routing', () {
      final profile = MemosServerApiProfiles.byVersionString('0.23.0');
      final adapter = MemosRouteAdapters.resolve(
        profile: profile,
        parsedVersion: MemosServerApiProfiles.tryParseVersion('0.23.0'),
      );

      expect(adapter.profile.flavor, MemosServerFlavor.v0_23);
      expect(adapter.requiresMemoFullView, isTrue);
      expect(adapter.sendsStateInListMemos, isFalse);
      expect(adapter.usesRowStatusMemoStateField, isTrue);
      expect(adapter.requiresCreatorScopedListMemos, isTrue);
    });

    test('0.24 keeps state query and supports memo parent query', () {
      final profile = MemosServerApiProfiles.byVersionString('0.24.4');
      final adapter = MemosRouteAdapters.resolve(
        profile: profile,
        parsedVersion: MemosServerApiProfiles.tryParseVersion('0.24.4'),
      );

      expect(adapter.profile.flavor, MemosServerFlavor.v0_24);
      expect(adapter.requiresMemoFullView, isFalse);
      expect(adapter.sendsStateInListMemos, isTrue);
      expect(adapter.usesRowStatusMemoStateField, isFalse);
      expect(adapter.supportsMemoParentQuery, isTrue);
    });

    test('0.25 uses auth session current as current-user route', () {
      final profile = MemosServerApiProfiles.byVersionString('0.25.0');
      final adapter = MemosRouteAdapters.resolve(
        profile: profile,
        parsedVersion: MemosServerApiProfiles.tryParseVersion('0.25.0'),
      );

      expect(adapter.profile.flavor, MemosServerFlavor.v0_25Plus);
      expect(
        adapter.currentUserRoutes.first,
        MemosCurrentUserRoute.authSessionCurrent,
      );
    });

    test('0.26 prefers auth me first', () {
      final profile = MemosServerApiProfiles.byVersionString('0.26.0');
      final adapter = MemosRouteAdapters.resolve(
        profile: profile,
        parsedVersion: MemosServerApiProfiles.tryParseVersion('0.26.0'),
      );

      expect(adapter.profile.flavor, MemosServerFlavor.v0_25Plus);
      expect(adapter.currentUserRoutes.first, MemosCurrentUserRoute.authMe);
    });
  });
}
