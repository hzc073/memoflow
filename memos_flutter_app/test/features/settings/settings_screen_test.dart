// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/access_boundary/access_boundary.dart';
import 'package:memos_flutter_app/access_boundary/access_decision.dart';
import 'package:memos_flutter_app/access_boundary/app_capability.dart';
import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/api/memos_api.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/server_setting.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/data/repositories/webdav_vault_state_repository.dart';
import 'package:memos_flutter_app/features/home/home_entry_screen.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/features/settings/account_security_screen.dart';
import 'package:memos_flutter_app/features/settings/about_us_screen.dart';
import 'package:memos_flutter_app/features/settings/customize_home_shortcuts_screen.dart';
import 'package:memos_flutter_app/features/settings/feedback_screen.dart';
import 'package:memos_flutter_app/features/settings/laboratory_screen.dart';
import 'package:memos_flutter_app/features/settings/navigation_mode_screen.dart';
import 'package:memos_flutter_app/features/settings/password_lock_screen.dart';
import 'package:memos_flutter_app/features/settings/server_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/features/settings/user_general_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/webdav_sync_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/module_boundary/settings_entry_contribution.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/platform/widgets/platform_list_section.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle_provider.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_provider.dart';
import 'package:memos_flutter_app/state/settings/app_lock_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/server_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/user_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/notifications_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_settings_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_vault_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
  });

  tearDown(() {
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
  });

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'dev.memoflow.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  Widget buildTestApp({
    PrivateExtensionBundle? bundle,
    Widget home = const SettingsScreen(),
    LocalLibrary? currentLocalLibrary,
    List<Override> overrides = const [],
  }) {
    LocaleSettings.setLocale(AppLocale.en);
    return ProviderScope(
      overrides: [
        appSessionProvider.overrideWith((ref) => _TestSessionController()),
        appPreferencesProvider.overrideWith(
          (ref) => _TestAppPreferencesController(ref),
        ),
        currentWorkspacePreferencesProvider.overrideWith(
          (ref) => _TestWorkspacePreferencesController(ref),
        ),
        currentLocalLibraryProvider.overrideWith((ref) => currentLocalLibrary),
        if (bundle != null)
          privateExtensionBundleProvider.overrideWithValue(bundle),
        ...overrides,
      ],
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
  }

  testWidgets('keeps donation entry and removes crown UI by default', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final donationFinder = find.byIcon(Icons.bolt_outlined);
    await tester.scrollUntilVisible(
      donationFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(donationFinder, findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(find.text('Private Entry'), findsNothing);
  });

  testWidgets('settings home keeps semantic entry seams and core entries', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(SettingsHomeProfileEntry), findsOneWidget);
    expect(find.byType(SettingsHomeShortcutTile), findsNWidgets(3));
    expect(find.byType(SettingsNavigationRow), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('API & Plugins'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);

    final componentsFinder = find.text('Components');
    await tester.scrollUntilVisible(
      componentsFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(componentsFinder, findsOneWidget);
  });

  testWidgets('settings home uses mobile hierarchy seams on phone', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      debugPlatformTargetOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsScreen));
    final tokens = settingsPageTokens(context);
    final home = tokens.homeHierarchy;

    expect(home.usesLayeredCards, isTrue);
    expect(find.byType(SettingsHomeProfileEntry), findsOneWidget);
    expect(find.byType(SettingsHomeShortcutTile), findsNWidgets(3));
    expect(find.byType(SettingsHomeSection), findsAtLeastNWidgets(5));

    final firstHomeSection = tester.widget<PlatformListSection>(
      find.descendant(
        of: find.byType(SettingsHomeSection).first,
        matching: find.byType(PlatformListSection),
      ),
    );
    expect(firstHomeSection.style?.sectionColor, home.cardBackground);
    expect(firstHomeSection.style?.borderColor, home.border);
    expect(firstHomeSection.style?.dividerColor, home.divider);
    expect(
      firstHomeSection.style?.borderRadius,
      BorderRadius.circular(home.sectionRadius),
    );
    expect(firstHomeSection.style?.boxShadow, home.sectionShadow);

    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('API & Plugins'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('feedback screen uses settings semantic rows', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const FeedbackScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsOneWidget);
    expect(find.byType(SettingsNavigationRow), findsNWidgets(3));
    expect(find.text('Export Logs'), findsOneWidget);
    expect(find.text('Self Repair'), findsOneWidget);
    expect(find.text('How to report?'), findsOneWidget);
  });

  testWidgets(
    'about screen keeps identity and support entries on settings seams',
    (tester) async {
      await tester.pumpWidget(buildTestApp(home: const AboutUsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(SettingsSection), findsOneWidget);
      expect(find.byType(SettingsNavigationRow), findsNWidgets(7));
      expect(find.text('MemoFlow'), findsOneWidget);
      expect(find.text('Version: v1.0.0 (1)'), findsOneWidget);
      expect(find.text('Official Website'), findsOneWidget);
      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('Contributors'), findsOneWidget);
    },
  );

  testWidgets('account security screen uses settings semantic rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const AccountSecurityScreen(),
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(hasAccount: true),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsProfileSummary), findsOneWidget);
    expect(find.byType(SettingsSection), findsWidgets);
    expect(find.byType(SettingsNavigationRow), findsNWidgets(5));
    expect(find.byType(SettingsSelectableItemRow), findsOneWidget);
    expect(find.text('Add Account'), findsOneWidget);
    expect(find.text('Add local library'), findsOneWidget);
    expect(find.text('User General Settings'), findsOneWidget);
    expect(find.text('Server Settings'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
  });

  testWidgets('password lock screen uses settings semantic rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const PasswordLockScreen(),
        overrides: [
          appLockProvider.overrideWith(
            (ref) => _FakeAppLockController(
              const AppLockState(
                enabled: true,
                autoLockTime: AutoLockTime.after5Min,
                hasPassword: true,
                locked: false,
                loaded: true,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsNWidgets(3));
    expect(find.byType(SettingsToggleRow), findsOneWidget);
    expect(find.byType(SettingsNavigationRow), findsNWidgets(2));
    expect(find.byType(SettingsInfoRow), findsOneWidget);
    expect(find.text('App Lock'), findsOneWidget);
    expect(find.text('Enable App Lock'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Auto-lock time'), findsOneWidget);
  });

  testWidgets('vault security status screen uses settings semantic rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const VaultSecurityStatusScreen(),
        overrides: [
          desktopSyncFacadeProvider.overrideWithValue(
            _VaultStatusSyncFacade(
              meta: const WebDavSyncMeta(
                schemaVersion: 1,
                deviceId: 'device-a',
                updatedAt: '2026-06-02T00:00:00Z',
                files: <String, WebDavFileMeta>{},
                deprecatedFiles: <String>['legacy.json'],
              ),
              exportStatus: const WebDavExportStatus(
                webDavConfigured: true,
                encSignature: null,
                plainSignature: null,
                plainDetected: true,
                plainDeprecated: true,
                plainDetectedAt: null,
                plainRemindAfter: null,
                lastExportSuccessAt: '2026-06-01T10:00:00Z',
                lastUploadSuccessAt: '2026-06-01T10:05:00Z',
              ),
            ),
          ),
          webDavSettingsProvider.overrideWith(
            (ref) => _FakeWebDavSettingsController(
              WebDavSettings.defaults.copyWith(
                vaultEnabled: true,
                vaultKeepPlainCache: true,
                backupMirrorRootPath: '/tmp/memoflow-backup',
              ),
            ),
          ),
          webDavVaultStateRepositoryProvider.overrideWithValue(
            _FakeWebDavVaultStateRepository(
              const WebDavVaultState(recoveryVerified: true),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsNWidgets(2));
    expect(find.byType(SettingsToggleRow), findsOneWidget);
    expect(find.byType(SettingsAction), findsNWidgets(5));
    expect(find.text('Vault security status'), findsOneWidget);
    expect(find.text('Vault enabled'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Recovery code'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Remote plaintext'), findsOneWidget);
    expect(find.text('1 detected'), findsOneWidget);
    expect(find.text('Local plaintext cache'), findsOneWidget);
    expect(find.text('Possible'), findsOneWidget);
    expect(find.text('Export plaintext'), findsOneWidget);
    expect(find.text('Detected (legacy)'), findsOneWidget);
    expect(find.text('View recovery code'), findsOneWidget);
    expect(find.text('Clean remote plaintext'), findsOneWidget);
    expect(find.text('Backup restore test'), findsOneWidget);
  });

  testWidgets(
    'renders bundle supplied settings entries without capability checks',
    (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          bundle: _FakePrivateExtensionBundle(onTap: () => tapped = true),
        ),
      );
      await tester.pumpAndSettle();

      final donationFinder = find.byIcon(Icons.bolt_outlined);
      await tester.scrollUntilVisible(
        donationFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Private Entry'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(donationFinder, findsOneWidget);
      expect(find.text('Private Entry'), findsOneWidget);
      expect(find.text('Bundle supplied entry'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);

      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text('Private Entry'),
              matching: find.byType(ListTile),
            ),
          )
          .onTap
          ?.call();
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets('customize quick entries screen shows three slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(home: const CustomizeHomeShortcutsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Entry 1'), findsOneWidget);
    expect(find.text('Quick Entry 2'), findsOneWidget);
    expect(find.text('Quick Entry 3'), findsOneWidget);
  });

  testWidgets(
    'customize quick entries shows local-only candidates and disables used actions',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(home: const CustomizeHomeShortcutsScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Entry 1'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Explore'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadioListTile<HomeQuickAction>,
        ),
        findsWidgets,
      );
      final dialogFinder = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialogFinder, matching: find.text('AI Summary')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.text('Collections')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.text('Random Review')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: dialogFinder, matching: find.text('AI Summary')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Attachments'));
      await tester.pumpAndSettle();

      expect(find.text('Attachments'), findsOneWidget);
    },
  );

  testWidgets('customize quick entries exposes Explore for signed-in users', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const CustomizeHomeShortcutsScreen(),
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(hasAccount: true),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(
              ref,
              initial: AppPreferences.defaultsForLanguage(AppLanguage.en),
            ),
          ),
          currentWorkspacePreferencesProvider.overrideWith(
            (ref) => _TestWorkspacePreferencesController(
              ref,
              initial: WorkspacePreferences.defaults,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick Entry 1'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(AlertDialog);
    expect(dialogFinder, findsOneWidget);
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Explore')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Collections')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RadioListTile<HomeQuickAction>,
      ),
      findsWidgets,
    );

    await tester.tap(
      find.descendant(of: dialogFinder, matching: find.text('Explore')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('laboratory screen exposes navigation mode entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(home: const LaboratoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Navigation Mode'), findsOneWidget);

    await tester.tap(find.text('Navigation Mode'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationModeScreen), findsOneWidget);
  });

  testWidgets('server settings screen disables unavailable fields', (
    tester,
  ) async {
    late _FakeServerSettingsController controller;

    await tester.pumpWidget(
      buildTestApp(
        home: const ServerSettingsScreen(),
        overrides: [
          serverSettingsProvider.overrideWith((ref) {
            controller = _FakeServerSettingsController(
              ref,
              const ServerSettingsState(
                snapshot: AsyncValue.data(
                  ServerSettingsSnapshot(
                    memoContentLimitBytes: ServerSettingValue<int>.known(
                      value: 2048,
                      source: ServerSettingSource.instanceMemoRelatedSetting,
                    ),
                    attachmentUploadLimitMiB:
                        ServerSettingValue<int>.unavailable(
                          unavailableReason:
                              ServerSettingUnavailableReason.permissionDenied,
                        ),
                  ),
                ),
              ),
            );
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsNWidgets(2));
    expect(find.byType(SettingsInputRow), findsNWidgets(2));
    expect(find.text('Memo maximum bytes'), findsOneWidget);
    expect(find.text('Attachment maximum capacity'), findsOneWidget);
    expect(
      find.text(
        'The current account does not have permission for this setting.',
      ),
      findsOneWidget,
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(2));
    expect(fields[0].enabled, isTrue);
    expect(fields[0].decoration?.hintText, 'Allowed range: 1-2147483647 bytes');
    expect(fields[1].enabled, isFalse);
    expect(fields[1].decoration?.hintText, isNull);
    expect(controller.memoSaveCount, 0);
    expect(controller.attachmentSaveCount, 0);
  });

  testWidgets('server settings screen shows empty-field hints', (tester) async {
    late _FakeServerSettingsController controller;

    await tester.pumpWidget(
      buildTestApp(
        home: const ServerSettingsScreen(),
        overrides: [
          serverSettingsProvider.overrideWith((ref) {
            controller = _FakeServerSettingsController(
              ref,
              const ServerSettingsState(
                snapshot: AsyncValue.data(
                  ServerSettingsSnapshot(
                    memoContentLimitBytes: ServerSettingValue<int>.known(
                      value: 2048,
                      source: ServerSettingSource.instanceMemoRelatedSetting,
                    ),
                    attachmentUploadLimitMiB: ServerSettingValue<int>.known(
                      value: 64,
                      source: ServerSettingSource.instanceStorageSetting,
                    ),
                  ),
                ),
              ),
            );
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final memoField = find.byType(TextField).at(0);
    final attachmentField = find.byType(TextField).at(1);

    await tester.enterText(memoField, '');
    await tester.pump();

    expect(find.text('Allowed range: 1-2147483647 bytes'), findsOneWidget);
    expect(controller.memoSaveCount, 0);
    expect(controller.attachmentSaveCount, 0);

    await tester.enterText(memoField, '3000');
    await tester.pump();

    expect(tester.widget<TextField>(memoField).controller?.text, '3000');
    expect(controller.memoSaveCount, 0);
    expect(controller.attachmentSaveCount, 0);

    await tester.enterText(attachmentField, '');
    await tester.pump();

    expect(find.text('Current server limit: 64 MiB'), findsOneWidget);

    await tester.enterText(attachmentField, '128');
    await tester.pump();

    expect(tester.widget<TextField>(attachmentField).controller?.text, '128');
    expect(controller.memoSaveCount, 0);
    expect(controller.attachmentSaveCount, 0);
  });

  testWidgets('server settings screen restores empty focused fields on blur', (
    tester,
  ) async {
    late _FakeServerSettingsController controller;

    await tester.pumpWidget(
      buildTestApp(
        home: const ServerSettingsScreen(),
        overrides: [
          serverSettingsProvider.overrideWith((ref) {
            controller = _FakeServerSettingsController(
              ref,
              const ServerSettingsState(
                snapshot: AsyncValue.data(
                  ServerSettingsSnapshot(
                    memoContentLimitBytes: ServerSettingValue<int>.known(
                      value: 2048,
                      source: ServerSettingSource.instanceMemoRelatedSetting,
                    ),
                    attachmentUploadLimitMiB: ServerSettingValue<int>.known(
                      value: 64,
                      source: ServerSettingSource.instanceStorageSetting,
                    ),
                  ),
                ),
              ),
            );
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final memoField = find.byType(TextField).at(0);
    await tester.enterText(memoField, '');
    await tester.pump();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller?.text, '2048');
    expect(controller.memoSaveCount, 0);
    expect(controller.attachmentSaveCount, 0);
  });

  testWidgets('server settings screen rejects non-positive input locally', (
    tester,
  ) async {
    late _FakeServerSettingsController controller;

    await tester.pumpWidget(
      buildTestApp(
        home: const ServerSettingsScreen(),
        overrides: [
          serverSettingsProvider.overrideWith((ref) {
            controller = _FakeServerSettingsController(
              ref,
              const ServerSettingsState(
                snapshot: AsyncValue.data(
                  ServerSettingsSnapshot(
                    memoContentLimitBytes: ServerSettingValue<int>.known(
                      value: 2048,
                      source: ServerSettingSource.instanceMemoRelatedSetting,
                    ),
                    attachmentUploadLimitMiB: ServerSettingValue<int>.known(
                      value: 64,
                      source: ServerSettingSource.instanceStorageSetting,
                    ),
                  ),
                ),
              ),
            );
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(find.text('Enter an integer greater than 0.'), findsOneWidget);
    expect(controller.memoSaveCount, 0);
    expect(controller.attachmentSaveCount, 0);
  });

  test(
    'server settings provider reloads and saves against current account after switch',
    () async {
      final serverA = await _ScopedServerSettingsServer.start(
        memoContentLimitBytes: 2048,
        attachmentUploadLimitMiB: 64,
      );
      final serverB = await _ScopedServerSettingsServer.start(
        memoContentLimitBytes: 4096,
        attachmentUploadLimitMiB: 128,
      );

      await HttpOverrides.runWithHttpOverrides(() async {
        final accountA = _serverSettingsAccount('account-a', serverA.baseUrl);
        final accountB = _serverSettingsAccount('account-b', serverB.baseUrl);
        final sessionController = _TestSessionController(
          accounts: [accountA, accountB],
          currentKey: accountA.key,
        );
        final container = ProviderContainer(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            currentLocalLibraryProvider.overrideWith((ref) => null),
            memosApiProvider.overrideWith((ref) {
              final account = ref.watch(
                appSessionProvider.select(
                  (state) => state.valueOrNull?.currentAccount,
                ),
              );
              if (account == null) {
                throw StateError('Not authenticated');
              }
              return MemosApi.authenticated(
                baseUrl: account.baseUrl,
                personalAccessToken: account.personalAccessToken,
                strictRouteLock: true,
                strictServerVersion: '0.27.0',
                instanceProfile: account.instanceProfile,
              );
            }),
          ],
        );
        final subscription = container.listen<ServerSettingsState>(
          serverSettingsProvider,
          (_, _) {},
          fireImmediately: true,
        );

        try {
          await _waitForServerSettingsMemoLimit(container, 2048);

          await sessionController.switchAccount(accountB.key);
          await Future<void>.delayed(Duration.zero);
          expect(
            container
                .read(serverSettingsProvider)
                .snapshot
                .valueOrNull
                ?.memoContentLimitBytes
                .value,
            isNot(2048),
          );
          await _waitForServerSettingsMemoLimit(container, 4096);

          final saveResult = await container
              .read(serverSettingsProvider.notifier)
              .updateMemoContentLimitBytes(5000);

          expect(saveResult.isSaved, isTrue);
          expect(serverA.memoPatchCount, 0);
          expect(serverB.memoPatchCount, 1);
          expect(serverB.memoContentLimitBytes, 5000);
        } finally {
          subscription.close();
          container.dispose();
        }
      }, _PassthroughHttpOverrides());

      await serverA.close();
      await serverB.close();
    },
  );

  test(
    'server settings local library mode does not read the remote API',
    () async {
      var apiRead = false;
      final account = _serverSettingsAccount(
        'account-local',
        Uri.parse('http://127.0.0.1:1/'),
      );
      final sessionController = _TestSessionController(
        accounts: [account],
        currentKey: account.key,
      );
      final container = ProviderContainer(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          currentLocalLibraryProvider.overrideWith(
            (ref) => const LocalLibrary(
              key: 'local-test',
              name: 'Local',
              storageKind: LocalLibraryStorageKind.managedPrivate,
              rootPath: 'local-test',
            ),
          ),
          memosApiProvider.overrideWith((ref) {
            apiRead = true;
            throw StateError('memosApiProvider should not be read');
          }),
        ],
      );
      final subscription = container.listen<ServerSettingsState>(
        serverSettingsProvider,
        (_, _) {},
        fireImmediately: true,
      );

      try {
        await _waitUntil(() {
          final snapshot = container
              .read(serverSettingsProvider)
              .snapshot
              .valueOrNull;
          return snapshot?.memoContentLimitBytes.unavailableReason ==
                  ServerSettingUnavailableReason.localLibrary &&
              snapshot?.attachmentUploadLimitMiB.unavailableReason ==
                  ServerSettingUnavailableReason.localLibrary;
        });

        expect(apiRead, isFalse);
      } finally {
        subscription.close();
        container.dispose();
      }
    },
  );

  testWidgets('user general settings does not render server-wide controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const UserGeneralSettingsScreen(),
        overrides: [
          userGeneralSettingProvider.overrideWith(
            (ref) async => const UserGeneralSetting(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsOneWidget);
    expect(find.byType(SettingsValueRow), findsNWidgets(2));
    expect(find.text('Locale'), findsOneWidget);
    expect(find.text('Default visibility'), findsOneWidget);
    expect(find.text('Memo maximum bytes'), findsNothing);
    expect(find.text('Attachment maximum capacity'), findsNothing);
    expect(find.text('Server Settings'), findsNothing);
  });

  testWidgets('embedded settings uses drawer menu instead of close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: SettingsScreen(
          presentation: HomeScreenPresentation.embeddedBottomNav,
          embeddedNavigationHost: _TestEmbeddedNavigationHost(),
        ),
        overrides: [
          unreadNotificationCountProvider.overrideWith((ref) => 0),
          syncQueuePendingCountProvider.overrideWith(
            (ref) => Stream<int>.value(0),
          ),
          syncQueueAttentionCountProvider.overrideWith(
            (ref) => Stream<int>.value(0),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('drawer-menu-button')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
    'windows settings fallback uses desktop shell rail on compact widths',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          home: Theme(
            data: ThemeData(platform: TargetPlatform.windows),
            child: MediaQuery(
              data: MediaQueryData(size: Size(1100, 900)),
              child: SettingsScreen(
                presentation: HomeScreenPresentation.embeddedBottomNav,
                embeddedNavigationHost: _TestEmbeddedNavigationHost(),
              ),
            ),
          ),
          overrides: [
            unreadNotificationCountProvider.overrideWith((ref) => 0),
            syncQueuePendingCountProvider.overrideWith(
              (ref) => Stream<int>.value(0),
            ),
            syncQueueAttentionCountProvider.overrideWith(
              (ref) => Stream<int>.value(0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('desktop-navigation-rail')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('drawer-menu-button')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('windows-desktop-command-bar')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'standalone settings close returns to home entry respecting bottom nav mode',
    (tester) async {
      HomeEntryScreen.debugClassicScreenBuilderOverride = (_) =>
          const Text('classic-home');
      HomeEntryScreen.debugBottomNavShellBuilderOverride = (_) =>
          const Text('bottom-nav-home');

      await tester.pumpWidget(
        buildTestApp(
          home: const SettingsScreen(),
          overrides: [
            currentWorkspacePreferencesProvider.overrideWith(
              (ref) => _TestWorkspacePreferencesController(
                ref,
                initial: WorkspacePreferences.defaults.copyWith(
                  homeNavigationPreferences: HomeNavigationPreferences.defaults
                      .copyWith(mode: HomeNavigationMode.bottomBar),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('bottom-nav-home'), findsOneWidget);
      expect(find.text('classic-home'), findsNothing);
    },
  );
}

Account _serverSettingsAccount(String key, Uri baseUrl) {
  return Account(
    key: key,
    baseUrl: baseUrl,
    personalAccessToken: 'token-$key',
    user: User(
      name: 'users/$key',
      username: key,
      displayName: key,
      avatarUrl: '',
      description: '',
    ),
    instanceProfile: const InstanceProfile(
      version: '0.27.0',
      mode: '',
      instanceUrl: '',
      owner: '',
    ),
    serverVersionOverride: '0.27.0',
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 40; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(predicate(), isTrue);
}

Future<void> _waitForServerSettingsMemoLimit(
  ProviderContainer container,
  int bytes,
) async {
  await _waitUntil(() {
    return container
            .read(serverSettingsProvider)
            .snapshot
            .valueOrNull
            ?.memoContentLimitBytes
            .value ==
        bytes;
  });
}

class _CapturedScopedServerSettingsRequest {
  const _CapturedScopedServerSettingsRequest({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> body;
}

class _ScopedServerSettingsServer {
  _ScopedServerSettingsServer._({
    required HttpServer server,
    required this.memoContentLimitBytes,
    required this.attachmentUploadLimitMiB,
  }) : _server = server;

  final HttpServer _server;
  int memoContentLimitBytes;
  int attachmentUploadLimitMiB;
  final requests = <_CapturedScopedServerSettingsRequest>[];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  int get memoPatchCount => requests
      .where(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/api/v1/instance/settings/MEMO_RELATED',
      )
      .length;

  static Future<_ScopedServerSettingsServer> start({
    required int memoContentLimitBytes,
    required int attachmentUploadLimitMiB,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.idleTimeout = null;
    final harness = _ScopedServerSettingsServer._(
      server: server,
      memoContentLimitBytes: memoContentLimitBytes,
      attachmentUploadLimitMiB: attachmentUploadLimitMiB,
    );
    server.listen(harness._handleRequest);
    return harness;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    final rawBody = await utf8.decoder.bind(request).join();
    final body = _decodeJsonMap(rawBody);
    requests.add(
      _CapturedScopedServerSettingsRequest(
        method: request.method,
        path: request.uri.path,
        body: body,
      ),
    );

    if (request.uri.path == '/api/v1/instance/settings/MEMO_RELATED') {
      if (request.method == 'GET') {
        await _writeJson(request.response, _memoPayload());
        return;
      }
      if (request.method == 'PATCH') {
        final setting = _readMap(
          body['memoRelatedSetting'] ?? body['memo_related_setting'],
        );
        final value = _readInt(
          setting?['contentLengthLimit'] ??
              setting?['content_length_limit'] ??
              memoContentLimitBytes,
        );
        memoContentLimitBytes = value;
        await _writeJson(request.response, body);
        return;
      }
    }

    if (request.uri.path == '/api/v1/instance/settings/STORAGE') {
      if (request.method == 'GET') {
        await _writeJson(request.response, _storagePayload());
        return;
      }
      if (request.method == 'PATCH') {
        final setting = _readMap(
          body['storageSetting'] ?? body['storage_setting'],
        );
        attachmentUploadLimitMiB = _readInt(
          setting?['uploadSizeLimitMb'] ??
              setting?['upload_size_limit_mb'] ??
              attachmentUploadLimitMiB,
        );
        await _writeJson(request.response, body);
        return;
      }
    }

    await _writeJson(request.response, const <String, Object?>{
      'error': 'Unhandled route',
    }, statusCode: HttpStatus.notFound);
  }

  Map<String, Object?> _memoPayload() {
    return <String, Object?>{
      'name': 'instance/settings/MEMO_RELATED',
      'memoRelatedSetting': <String, Object?>{
        'contentLengthLimit': memoContentLimitBytes,
        'displayWithUpdateTime': false,
        'enableDoubleClickEdit': true,
      },
    };
  }

  Map<String, Object?> _storagePayload() {
    return <String, Object?>{
      'name': 'instance/settings/STORAGE',
      'storageSetting': <String, Object?>{
        'storageType': 'DATABASE',
        'filepathTemplate': '{{filename}}',
        'uploadSizeLimitMb': attachmentUploadLimitMiB,
      },
    };
  }
}

Map<String, dynamic> _decodeJsonMap(String raw) {
  if (raw.trim().isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return decoded.cast<String, dynamic>();
  return <String, dynamic>{};
}

Map<String, dynamic>? _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

Future<void> _writeJson(
  HttpResponse response,
  Object payload, {
  int statusCode = HttpStatus.ok,
}) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(payload));
  await response.close();
}

class _PassthroughHttpOverrides extends HttpOverrides {}

class _FakePrivateExtensionBundle implements PrivateExtensionBundle {
  _FakePrivateExtensionBundle({required this.onTap});

  final VoidCallback onTap;

  @override
  AccessBoundary get diagnosticsAccessBoundary =>
      const _DisabledAccessBoundary();

  @override
  Future<void> onAppReady(WidgetRef ref) async {}

  @override
  List<SettingsEntryContribution> settingsEntries(
    BuildContext context,
    WidgetRef ref,
  ) {
    return [
      SettingsEntryContribution(
        id: 'private-entry',
        order: 10,
        icon: Icons.extension,
        titleBuilder: (_) => 'Private Entry',
        subtitleBuilder: (_) => 'Bundle supplied entry',
        onTap: onTap,
      ),
    ];
  }
}

class _DisabledAccessBoundary implements AccessBoundary {
  const _DisabledAccessBoundary();

  @override
  AccessDecision decisionFor(AppCapability capability) {
    return const AccessDecision.disabled('test');
  }
}

class _FakeServerSettingsController extends ServerSettingsController {
  _FakeServerSettingsController(super.ref, ServerSettingsState initial)
    : super(api: null) {
    state = initial;
  }

  int memoSaveCount = 0;
  int attachmentSaveCount = 0;

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<ServerSettingSaveResult> updateMemoContentLimitBytes(int bytes) async {
    memoSaveCount++;
    return const ServerSettingSaveResult.saved();
  }

  @override
  Future<ServerSettingSaveResult> updateAttachmentUploadLimitMiB(
    int mebibytes,
  ) async {
    attachmentSaveCount++;
    return const ServerSettingSaveResult.saved();
  }
}

class _FakeAppLockController extends StateNotifier<AppLockState>
    implements AppLockController {
  _FakeAppLockController(super.state);

  @override
  void setEnabled(bool v) {
    state = state.copyWith(enabled: v, locked: v ? state.locked : false);
  }

  @override
  void setAutoLockTime(AutoLockTime v) {
    state = state.copyWith(autoLockTime: v);
  }

  @override
  Future<void> setPassword(String password) async {
    state = state.copyWith(hasPassword: true);
  }

  @override
  Future<bool> verifyPassword(String password) async {
    state = state.copyWith(locked: false, clearLastBackgroundAt: true);
    return true;
  }

  @override
  void lock() {
    if (!state.enabled || !state.hasPassword) return;
    state = state.copyWith(locked: true);
  }

  @override
  void recordBackgrounded() {}

  @override
  void handleAppResumed() {}

  @override
  Future<void> setSnapshot(
    AppLockSnapshot snapshot, {
    bool triggerSync = true,
  }) async {
    state = state.copyWith(
      enabled: snapshot.settings.enabled,
      autoLockTime: snapshot.settings.autoLockTime,
      hasPassword: snapshot.passwordRecord != null,
      locked: snapshot.settings.enabled && snapshot.passwordRecord != null,
      loaded: true,
      clearLastBackgroundAt: true,
    );
  }
}

class _FakeWebDavSettingsController extends StateNotifier<WebDavSettings>
    implements WebDavSettingsController {
  _FakeWebDavSettingsController(super.settings);

  @override
  void setEnabled(bool value) => state = state.copyWith(enabled: value);

  @override
  void setAutoSyncAllowed(bool value) =>
      state = state.copyWith(autoSyncAllowed: value);

  @override
  void setServerUrl(String value) => state = state.copyWith(serverUrl: value);

  @override
  void setUsername(String value) => state = state.copyWith(username: value);

  @override
  void setPassword(String value) => state = state.copyWith(password: value);

  @override
  void setAuthMode(WebDavAuthMode mode) =>
      state = state.copyWith(authMode: mode);

  @override
  void setIgnoreTlsErrors(bool value) =>
      state = state.copyWith(ignoreTlsErrors: value);

  @override
  void setRootPath(String value) => state = state.copyWith(rootPath: value);

  @override
  void setVaultEnabled(bool value) =>
      state = state.copyWith(vaultEnabled: value);

  @override
  void setRememberVaultPassword(bool value) =>
      state = state.copyWith(rememberVaultPassword: value);

  @override
  void setVaultKeepPlainCache(bool value) =>
      state = state.copyWith(vaultKeepPlainCache: value);

  @override
  void setBackupEnabled(bool value) =>
      state = state.copyWith(backupEnabled: value);

  @override
  void setBackupConfigScope(WebDavBackupConfigScope scope) =>
      state = state.copyWith(backupConfigScope: scope);

  @override
  void setBackupContentMemos(bool value) =>
      state = state.copyWith(backupContentMemos: value);

  @override
  void setBackupEncryptionMode(WebDavBackupEncryptionMode mode) =>
      state = state.copyWith(backupEncryptionMode: mode);

  @override
  void setBackupSchedule(WebDavBackupSchedule schedule) =>
      state = state.copyWith(backupSchedule: schedule);

  @override
  void setBackupRetentionCount(int value) =>
      state = state.copyWith(backupRetentionCount: value);

  @override
  void setRememberBackupPassword(bool value) =>
      state = state.copyWith(rememberBackupPassword: value);

  @override
  void setBackupExportEncrypted(bool value) =>
      state = state.copyWith(backupExportEncrypted: value);

  @override
  void setBackupMirrorLocation({String? treeUri, String? rootPath}) {
    state = state.copyWith(
      backupMirrorTreeUri: treeUri,
      backupMirrorRootPath: rootPath,
    );
  }

  @override
  void setAll(WebDavSettings settings) {
    state = settings;
  }
}

class _FakeWebDavVaultStateRepository implements WebDavVaultStateRepository {
  _FakeWebDavVaultStateRepository(this.state);

  WebDavVaultState state;

  @override
  Future<WebDavVaultState> read() async => state;

  @override
  Future<void> write(WebDavVaultState state) async {
    this.state = state;
  }

  @override
  Future<void> clear() async {
    state = WebDavVaultState.defaults;
  }
}

class _VaultStatusSyncFacade extends DesktopSyncFacade {
  _VaultStatusSyncFacade({required this.meta, required this.exportStatus})
    : super(SyncCoordinatorState.initial);

  final WebDavSyncMeta? meta;
  final WebDavExportStatus exportStatus;

  @override
  Future<WebDavSyncMeta?> fetchWebDavSyncMeta() async => meta;

  @override
  Future<WebDavExportStatus> fetchWebDavExportStatus() async => exportStatus;

  @override
  Future<WebDavSyncMeta?> cleanWebDavDeprecatedPlainFiles() async => null;

  @override
  Future<WebDavExportCleanupStatus> cleanWebDavPlainExport() async =>
      WebDavExportCleanupStatus.notFound;

  @override
  Future<SyncRunResult> requestSync(SyncRequest request) async {
    return const SyncRunStarted();
  }

  @override
  Future<SyncRunResult> requestWebDavBackup({
    required SyncRequestReason reason,
    String? password,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    return const SyncRunStarted();
  }

  @override
  Future<WebDavConnectionTestResult> testWebDavConnection({
    required WebDavSettings settings,
  }) async {
    return const WebDavConnectionTestResult.success();
  }

  @override
  Future<SyncError?> verifyWebDavBackup({
    required String password,
    required bool deep,
  }) async {
    return null;
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listWebDavBackupSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return const <WebDavBackupSnapshotInfo>[];
  }

  @override
  Future<String> recoverWebDavBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    return '';
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> resolveLocalScanConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> retryPending() async {}
}

class _TestSessionController extends AppSessionController {
  _TestSessionController({
    bool hasAccount = false,
    List<Account>? accounts,
    String? currentKey,
  }) : super(
         AsyncValue.data(
           _initialState(
             hasAccount: hasAccount,
             accounts: accounts,
             currentKey: currentKey,
           ),
         ),
       );

  static AppSessionState _initialState({
    required bool hasAccount,
    required List<Account>? accounts,
    required String? currentKey,
  }) {
    final resolvedAccounts =
        accounts ?? (hasAccount ? [_testAccount] : const <Account>[]);
    return AppSessionState(
      accounts: resolvedAccounts,
      currentKey:
          currentKey ??
          (resolvedAccounts.isNotEmpty ? resolvedAccounts.first.key : null),
    );
  }

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
  Future<void> switchAccount(String accountKey) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.accounts.any((account) => account.key == accountKey)) {
      return;
    }
    state = AsyncValue.data(
      AppSessionState(accounts: current.accounts, currentKey: accountKey),
    );
  }

  @override
  Future<void> setCurrentKey(String? key) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      AppSessionState(accounts: current.accounts, currentKey: key),
    );
  }

  @override
  Future<void> switchWorkspace(String workspaceKey) async {
    await setCurrentKey(workspaceKey);
  }

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
  _TestAppPreferencesRepository(this._stored)
    : super(const FlutterSecureStorage(), accountKey: null);

  AppPreferences _stored;

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<AppPreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(AppPreferences prefs) async {
    _stored = prefs;
  }

  @override
  Future<void> clear() async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref, {AppPreferences? initial})
    : super(
        ref,
        _TestAppPreferencesRepository(
          initial ?? AppPreferences.defaultsForLanguage(AppLanguage.en),
        ),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      ) {
    state = initial ?? AppPreferences.defaultsForLanguage(AppLanguage.en);
  }
}

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository(this._stored)
    : super(
        PreferencesMigrationService(const FlutterSecureStorage()),
        workspaceKey: 'test-workspace',
      );

  WorkspacePreferences _stored;

  @override
  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<WorkspacePreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(WorkspacePreferences prefs) async {
    _stored = prefs;
  }
}

class _TestWorkspacePreferencesController
    extends WorkspacePreferencesController {
  _TestWorkspacePreferencesController(Ref ref, {WorkspacePreferences? initial})
    : super(
        ref,
        _TestWorkspacePreferencesRepository(
          initial ?? WorkspacePreferences.defaults,
        ),
        onLoaded: () {
          ref.read(workspacePreferencesLoadedProvider.notifier).state = true;
        },
      ) {
    state = initial ?? WorkspacePreferences.defaults;
  }
}

class _TestEmbeddedNavigationHost implements HomeEmbeddedNavigationHost {
  @override
  void handleBackToPrimaryDestination(BuildContext context) {}

  @override
  void handleDrawerDestination(BuildContext context, destination) {}

  @override
  void handleDrawerTag(BuildContext context, String tag) {}

  @override
  void handleOpenNotifications(BuildContext context) {}

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {}

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {}
}

const _testAccountKey = 'account-1';
final _testAccount = Account(
  key: _testAccountKey,
  baseUrl: Uri.parse('https://example.com'),
  personalAccessToken: 'token',
  user: User.empty(),
  instanceProfile: InstanceProfile.empty(),
);
