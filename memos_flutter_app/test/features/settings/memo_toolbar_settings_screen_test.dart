import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/memo_toolbar_preferences.dart';
import 'package:memos_flutter_app/features/settings/memo_toolbar_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/preferences_settings_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/system/system_fonts_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens toolbar settings from preferences screen', (tester) async {
    final container = _createContainer(includeSession: true);
    addTearDown(container.dispose);

    await _pumpPreferencesScreen(tester, container: container);

    final toolbarEntry = find.byKey(
      const ValueKey('preferences-editor-toolbar-entry'),
    );
    await tester.scrollUntilVisible(
      toolbarEntry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(toolbarEntry);
    tester.widget<InkWell>(toolbarEntry).onTap?.call();
    await tester.pumpAndSettle();

    expect(find.byType(MemoToolbarSettingsScreen), findsOneWidget);
  });

  testWidgets('hides quick-input keyboard toggle and shows exit confirmation', (
    tester,
  ) async {
    final container = _createContainer(includeSession: true);
    addTearDown(container.dispose);

    await _pumpPreferencesScreen(tester, container: container);

    expect(find.text('Auto-open keyboard for Quick Input'), findsNothing);
    expect(find.text('Confirm on Exit'), findsOneWidget);
  });

  testWidgets('launch action opens centered dialog and supports Explore', (
    tester,
  ) async {
    final container = _createContainer(includeSession: true);
    addTearDown(container.dispose);

    await _pumpPreferencesScreen(tester, container: container);

    final launchAction = find.text('Launch Action').first;
    await tester.scrollUntilVisible(
      launchAction,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(launchAction);
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets(
    'removes from toolbar, restores from toolbox, and resets defaults',
    (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await _pumpToolbarSettingsScreen(tester, container: container);

      final removeBold = find.byKey(const ValueKey('memo-toolbar-remove-bold'));
      tester
          .widget<InkResponse>(
            find.descendant(of: removeBold, matching: find.byType(InkResponse)),
          )
          .onTap
          ?.call();
      await tester.pumpAndSettle();

      expect(
        container
            .read(appPreferencesProvider)
            .memoToolbarPreferences
            .hiddenActions,
        contains(MemoToolbarActionId.bold),
      );
      expect(
        find.byKey(const ValueKey('memo-toolbar-toolbox-bold')),
        findsOneWidget,
      );

      final addBold = find.byKey(const ValueKey('memo-toolbar-add-bold'));
      tester
          .widget<InkResponse>(
            find.descendant(of: addBold, matching: find.byType(InkResponse)),
          )
          .onTap
          ?.call();
      await tester.pumpAndSettle();

      expect(
        container
            .read(appPreferencesProvider)
            .memoToolbarPreferences
            .hiddenActions,
        isNot(contains(MemoToolbarActionId.bold)),
      );
      expect(
        find.byKey(const ValueKey('memo-toolbar-editor-bold')),
        findsOneWidget,
      );

      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();

      expect(
        container.read(appPreferencesProvider).memoToolbarPreferences,
        MemoToolbarPreferences.defaults,
      );
    },
  );

  testWidgets('dropping on the left side of a tool inserts before it', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);

    await _pumpToolbarSettingsScreen(tester, container: container);

    final targetFinder = find.byKey(
      const ValueKey('memo-toolbar-target-top-bold'),
    );
    final dropTarget = tester.widget<DragTarget<MemoToolbarItemId>>(
      targetFinder,
    );
    final targetOffset = tester.getTopLeft(targetFinder) + const Offset(2, 12);

    dropTarget.onAcceptWithDetails?.call(
      DragTargetDetails<MemoToolbarItemId>(
        data: MemoToolbarActionId.list.itemId,
        offset: targetOffset,
      ),
    );
    await tester.pumpAndSettle();

    final prefs = container.read(appPreferencesProvider).memoToolbarPreferences;
    expect(prefs.topRow.first, MemoToolbarActionId.list);
    expect(prefs.topRow[1], MemoToolbarActionId.bold);
  });

  testWidgets('dropping on the row end inserts after the last tool', (
    tester,
  ) async {
    final container = _createContainer(
      initialPrefs: MemoToolbarPreferences.defaults
          .setHidden(MemoToolbarActionId.list, true)
          .setHidden(MemoToolbarActionId.underline, true)
          .setHidden(MemoToolbarActionId.undo, true)
          .setHidden(MemoToolbarActionId.redo, true),
    );
    addTearDown(container.dispose);

    await _pumpToolbarSettingsScreen(tester, container: container);

    final dropTarget = tester.widget<DragTarget<MemoToolbarItemId>>(
      find.byKey(const ValueKey('memo-toolbar-drop-end-top')),
    );
    dropTarget.onAcceptWithDetails?.call(
      DragTargetDetails<MemoToolbarItemId>(
        data: MemoToolbarActionId.list.itemId,
        offset: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    final prefs = container.read(appPreferencesProvider).memoToolbarPreferences;
    final visibleTop = prefs.visibleActionsForRow(MemoToolbarRow.top);
    expect(visibleTop.first, MemoToolbarActionId.bold);
    expect(visibleTop.last, MemoToolbarActionId.list);
    expect(prefs.hiddenActions.contains(MemoToolbarActionId.list), isFalse);
  });

  testWidgets('clear button hides all toolbar actions', (tester) async {
    final container = _createContainer();
    addTearDown(container.dispose);

    await _pumpToolbarSettingsScreen(tester, container: container);

    await tester.tap(
      find.byKey(const ValueKey('memo-toolbar-clear-all')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final prefs = container.read(appPreferencesProvider).memoToolbarPreferences;
    expect(prefs.hiddenActions, MemoToolbarActionId.values.toSet());
    expect(
      find.byKey(const ValueKey('memo-toolbar-toolbox-bold')),
      findsOneWidget,
    );
  });

  testWidgets('shows new defaults and toolbox-hidden markdown actions', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);

    await _pumpToolbarSettingsScreen(tester, container: container);

    expect(
      find.byKey(const ValueKey('memo-toolbar-editor-italic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memo-toolbar-editor-heading1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memo-toolbar-toolbox-divider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memo-toolbar-toolbox-cutParagraph')),
      findsOneWidget,
    );
  });

  testWidgets('creates a custom toolbar button into toolbox', (tester) async {
    final container = _createContainer();
    addTearDown(container.dispose);

    await _pumpToolbarSettingsScreen(tester, container: container);

    await tester.tap(find.byKey(const ValueKey('memo-toolbar-create-custom')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'H1');
    await tester.enterText(find.byType(TextField).at(1), '# ');
    await tester.tap(find.byKey(const ValueKey('memo-toolbar-create-save')));
    await tester.pumpAndSettle();

    final prefs = container.read(appPreferencesProvider).memoToolbarPreferences;
    expect(prefs.customButtons, hasLength(1));
    expect(prefs.customButtons.single.label, 'H1');
    expect(
      prefs.hiddenItemIdsInOrder(),
      contains(prefs.customButtons.single.itemId),
    );
  });

  testWidgets('icon picker groups filter the icon grid', (tester) async {
    final container = _createContainer();
    addTearDown(container.dispose);

    await _pumpToolbarSettingsScreen(tester, container: container);

    await tester.tap(find.byKey(const ValueKey('memo-toolbar-create-custom')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('memo-toolbar-icon-option-acorn')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('memo-toolbar-icon-group-u-z')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('memo-toolbar-icon-grid-u-z')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memo-toolbar-icon-option-acorn')),
      findsNothing,
    );
  });
}

ProviderContainer _createContainer({
  bool includeSession = false,
  MemoToolbarPreferences? initialPrefs,
}) {
  final repository = _TestAppPreferencesRepository(initialPrefs: initialPrefs);
  return ProviderContainer(
    overrides: [
      if (includeSession)
        appSessionProvider.overrideWith((ref) => _TestSessionController()),
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref, repository),
      ),
      if (includeSession)
        systemFontsProvider.overrideWith((ref) async => const []),
    ],
  );
}

Future<void> _pumpPreferencesScreen(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  LocaleSettings.setLocale(AppLocale.en);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const PreferencesSettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpToolbarSettingsScreen(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  LocaleSettings.setLocale(AppLocale.en);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const MemoToolbarSettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
      );

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }
}

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository({MemoToolbarPreferences? initialPrefs})
    : _prefs = AppPreferences.defaultsForLanguage(AppLanguage.en).copyWith(
        memoToolbarPreferences: initialPrefs ?? MemoToolbarPreferences.defaults,
      ),
      super(const FlutterSecureStorage(), accountKey: null);

  AppPreferences _prefs;

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<AppPreferences> read() async {
    return _prefs;
  }

  @override
  Future<void> write(AppPreferences prefs) async {
    _prefs = prefs;
  }

  @override
  Future<void> clear() async {
    _prefs = AppPreferences.defaultsForLanguage(AppLanguage.en);
  }
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(super.ref, super.repo)
    : super(
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      );

  @override
  void setMemoToolbarPreferences(MemoToolbarPreferences value) {
    unawaited(
      setAll(state.copyWith(memoToolbarPreferences: value), triggerSync: false),
    );
  }

  @override
  void resetMemoToolbarPreferences() {
    unawaited(
      setAll(
        state.copyWith(memoToolbarPreferences: MemoToolbarPreferences.defaults),
        triggerSync: false,
      ),
    );
  }
}
