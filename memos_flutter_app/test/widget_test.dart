// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memos_flutter_app/app.dart';
import 'package:memos_flutter_app/state/session_provider.dart';

void main() {
  testWidgets('Shows login when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('连接 Memos'), findsOneWidget);
  });
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
      : super(
          const AsyncValue.data(
            AppSessionState(accounts: [], currentKey: null),
          ),
        );

  @override
  Future<void> addAccountWithPat({required Uri baseUrl, required String personalAccessToken}) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
  }) async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}
}
