import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/features/home/app_drawer_menu_button.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_provider.dart';
import 'package:memos_flutter_app/state/system/notifications_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    required int unreadCount,
    required int attentionCount,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadNotificationCountProvider.overrideWith((ref) => unreadCount),
          syncQueueAttentionCountProvider.overrideWith(
            (ref) => Stream<int>.value(attentionCount),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              drawer: const Drawer(
                child: Center(child: Text('drawer content')),
              ),
              appBar: AppBar(
                leading: const AppDrawerMenuButton(
                  tooltip: 'Toggle sidebar',
                  iconColor: Colors.black,
                  badgeBorderColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hides badge when no unread or attention items', (tester) async {
    await pumpButton(tester, unreadCount: 0, attentionCount: 0);

    expect(find.byKey(const ValueKey('drawer-menu-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-menu-badge')), findsNothing);
  });

  testWidgets('shows badge when unread notifications exist', (tester) async {
    await pumpButton(tester, unreadCount: 2, attentionCount: 0);

    expect(find.byKey(const ValueKey('drawer-menu-badge')), findsOneWidget);
  });

  testWidgets('shows badge when attention items exist', (tester) async {
    await pumpButton(tester, unreadCount: 0, attentionCount: 1);

    expect(find.byKey(const ValueKey('drawer-menu-badge')), findsOneWidget);
  });

  testWidgets('still renders a single badge when both signals exist', (
    tester,
  ) async {
    await pumpButton(tester, unreadCount: 3, attentionCount: 4);

    expect(find.byKey(const ValueKey('drawer-menu-badge')), findsOneWidget);
  });

  testWidgets('opens the scaffold drawer when tapped', (tester) async {
    await pumpButton(tester, unreadCount: 0, attentionCount: 0);

    expect(find.text('drawer content'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('drawer-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('drawer content'), findsOneWidget);
  });
}
