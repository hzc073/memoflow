import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/tags.dart';
import 'package:memos_flutter_app/core/theme_colors.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/resolved_app_settings.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';

void main() {
  group('DevicePreferences', () {
    test('falls back to defaults for missing and invalid values', () {
      final prefs = DevicePreferences.fromJson(<String, dynamic>{
        'language': 'not-a-language',
        'themeMode': 'not-a-theme-mode',
        'launchAction': 'not-a-launch-action',
      });

      expect(prefs.language, DevicePreferences.defaults.language);
      expect(prefs.themeMode, DevicePreferences.defaults.themeMode);
      expect(prefs.launchAction, DevicePreferences.defaults.launchAction);
      expect(prefs.macosCloseToMenuBar, isTrue);
    });

    test('round-trips json and preserves nullable fields via copyWith', () {
      final customTheme = CustomThemeSettings.defaults.copyWith(
        mode: CustomThemeMode.manual,
        autoLight: const Color(0xFF123456),
        manualLight: const Color(0xFF234567),
        manualDark: const Color(0xFF345678),
      );
      final prefs = DevicePreferences.defaults.copyWith(
        language: AppLanguage.ja,
        hasSelectedLanguage: true,
        onboardingMode: AppOnboardingMode.server,
        fontSize: AppFontSize.large,
        lineHeight: AppLineHeight.relaxed,
        fontFamily: 'Inter',
        fontFile: 'fonts/Inter.ttf',
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.cypressGreen,
        customTheme: customTheme,
        launchAction: LaunchAction.quickInput,
        quickInputAutoFocus: false,
        thirdPartyShareEnabled: true,
        windowsCloseToTray: false,
        macosCloseToMenuBar: false,
        lastSeenAppVersion: '1.2.3',
        skippedUpdateVersion: '1.2.4',
        lastSeenAnnouncementVersion: '5',
        lastSeenAnnouncementId: 42,
        lastSeenNoticeHash: 'notice-hash',
        seenNoticeRevisions: {'notice-1': 2},
      );

      expect(DevicePreferences.fromJson(prefs.toJson()), prefs);

      final cleared = prefs.copyWith(
        onboardingMode: null,
        fontFamily: null,
        fontFile: null,
      );
      expect(cleared.onboardingMode, isNull);
      expect(cleared.fontFamily, isNull);
      expect(cleared.fontFile, isNull);
    });

    test('keeps macOS close-to-menu-bar independent from Windows tray', () {
      final prefs = DevicePreferences.fromJson(<String, dynamic>{
        ...DevicePreferences.defaults.toJson(),
        'windowsCloseToTray': false,
      });

      expect(prefs.windowsCloseToTray, isFalse);
      expect(prefs.macosCloseToMenuBar, isTrue);

      final disabled = DevicePreferences.fromJson(<String, dynamic>{
        ...DevicePreferences.defaults.toJson(),
        'windowsCloseToTray': true,
        'macosCloseToMenuBar': false,
      });

      expect(disabled.windowsCloseToTray, isTrue);
      expect(disabled.macosCloseToMenuBar, isFalse);
      expect(disabled.toJson()['macosCloseToMenuBar'], isFalse);
    });
  });

  group('WorkspacePreferences', () {
    test(
      'falls back to defaults for invalid quick actions and theme override',
      () {
        final prefs = WorkspacePreferences.fromJson(<String, dynamic>{
          'homeQuickActionPrimary': 'not-an-action',
          'homeQuickActionSecondary': 'still-not-an-action',
          'homeQuickActionTertiary': 'nope',
          'themeColorOverride': 'bad-theme',
        });

        expect(
          prefs.homeQuickActionPrimary,
          WorkspacePreferences.defaults.homeQuickActionPrimary,
        );
        expect(
          prefs.homeQuickActionSecondary,
          WorkspacePreferences.defaults.homeQuickActionSecondary,
        );
        expect(
          prefs.homeQuickActionTertiary,
          WorkspacePreferences.defaults.homeQuickActionTertiary,
        );
        expect(prefs.themeColorOverride, isNull);
      },
    );

    test('round-trips json and can clear workspace-only overrides', () {
      final customTheme = CustomThemeSettings.defaults.copyWith(
        mode: CustomThemeMode.manual,
        autoLight: const Color(0xFF0F1E2D),
        manualLight: const Color(0xFF102030),
        manualDark: const Color(0xFF203040),
      );
      final prefs = WorkspacePreferences.defaults.copyWith(
        collapseLongContent: false,
        collapseReferences: false,
        showMemoEngagement: true,
        autoSyncOnStartAndResume: false,
        defaultUseLegacyApi: false,
        showDrawerExplore: false,
        showDrawerDailyReview: false,
        showDrawerAiSummary: false,
        showDrawerDraftBox: false,
        showDrawerResources: false,
        showDrawerArchive: false,
        homeQuickActionPrimary: HomeQuickAction.explore,
        homeQuickActionSecondary: HomeQuickAction.resources,
        homeQuickActionTertiary: HomeQuickAction.archived,
        aiSummaryAllowPrivateMemos: true,
        themeColorOverride: AppThemeColor.duskPurple,
        customThemeOverride: customTheme,
      );

      expect(WorkspacePreferences.fromJson(prefs.toJson()), prefs);

      final cleared = prefs.copyWith(
        themeColorOverride: null,
        customThemeOverride: null,
      );
      expect(cleared.themeColorOverride, isNull);
      expect(cleared.customThemeOverride, isNull);

      final legacy = prefs.toLegacyAppPreferences(workspaceKey: 'workspace-1');
      expect(WorkspacePreferences.defaults.showDrawerDraftBox, isTrue);
      expect(
        WorkspacePreferences.fromJson(const {}).showDrawerDraftBox,
        isTrue,
      );
      expect(AppPreferences.fromJson(const {}).showDrawerDraftBox, isTrue);
      expect(
        AppPreferences.fromJson(prefs.toJson()).showDrawerDraftBox,
        isFalse,
      );
      expect(
        WorkspacePreferences.fromJson(prefs.toJson()).showDrawerDraftBox,
        isFalse,
      );
      expect(
        legacy.accountThemeColors['workspace-1'],
        AppThemeColor.duskPurple,
      );
      expect(legacy.showDrawerDraftBox, isFalse);
      expect(legacy.accountCustomThemes['workspace-1'], customTheme);
      expect(legacy.language, AppPreferences.defaults.language);
      expect(prefs.showMemoEngagement, isTrue);
      expect(legacy.showMemoEngagement, isTrue);
      expect(
        legacy.hasSelectedLanguage,
        AppPreferences.defaults.hasSelectedLanguage,
      );
    });

    test('reads new memo engagement key with legacy fallback', () {
      expect(
        WorkspacePreferences.fromJson(const {
          'showMemoEngagement': true,
        }).showMemoEngagement,
        isTrue,
      );
      expect(
        WorkspacePreferences.fromJson(const {
          'showEngagementInAllMemoDetails': true,
        }).showMemoEngagement,
        isTrue,
      );
      expect(
        WorkspacePreferences.fromJson(const {
          'showMemoEngagement': false,
          'showEngagementInAllMemoDetails': true,
        }).showMemoEngagement,
        isFalse,
      );
    });

    test(
      'tag recognition policy defaults to strict for new and legacy json',
      () {
        expect(
          WorkspacePreferences.defaults.tagRecognitionPolicy,
          TagRecognitionPolicy.memoflowStrict,
        );
        expect(
          WorkspacePreferences.fromJson(const {}).tagRecognitionPolicy,
          TagRecognitionPolicy.memoflowStrict,
        );
        expect(
          WorkspacePreferences.fromJson(const {
            'tagRecognitionPolicy': 'unknown-policy',
          }).tagRecognitionPolicy,
          TagRecognitionPolicy.memoflowStrict,
        );
        expect(
          WorkspacePreferences.fromJson(const {
            'tagRecognitionPolicy': {'kind': 'unknown-policy'},
          }).tagRecognitionPolicy,
          TagRecognitionPolicy.memoflowStrict,
        );
      },
    );

    test('tag recognition policy round trips presets and custom options', () {
      final compatible = WorkspacePreferences.defaults.copyWith(
        tagRecognitionPolicy: TagRecognitionPolicy.memosCompatible,
      );
      expect(
        WorkspacePreferences.fromJson(compatible.toJson()).tagRecognitionPolicy,
        TagRecognitionPolicy.memosCompatible,
      );

      final customPolicy = TagRecognitionPolicy.custom(
        const TagRecognitionCustomOptions(
          strictFirstLine: false,
          strictLastLine: true,
          strictAnyLine: true,
          inlineBodyTags: true,
          numericOnlyTags: false,
          hierarchicalTags: false,
          emojiAndSymbolTags: false,
          remoteTagHandling: RemoteTagHandling.mergeRemote,
        ),
      );
      final custom = WorkspacePreferences.defaults.copyWith(
        tagRecognitionPolicy: customPolicy,
      );

      expect(WorkspacePreferences.fromJson(custom.toJson()), custom);
      expect(
        WorkspacePreferences.fromJson(custom.toJson()).tagRecognitionPolicy,
        customPolicy,
      );
    });
  });

  group('ResolvedAppSettings', () {
    test(
      'prefers workspace theme overrides and composes legacy preferences',
      () {
        final device = DevicePreferences.defaults.copyWith(
          language: AppLanguage.de,
          hasSelectedLanguage: true,
          themeColor: AppThemeColor.ochre,
          launchAction: LaunchAction.sync,
        );
        final workspace = WorkspacePreferences.defaults.copyWith(
          homeQuickActionPrimary: HomeQuickAction.explore,
          themeColorOverride: AppThemeColor.cypressGreen,
        );
        final settings = ResolvedAppSettings(
          device: device,
          workspace: workspace,
          workspaceKey: 'workspace-1',
          hasWorkspace: true,
          hasRemoteAccount: true,
        );

        expect(settings.resolvedThemeColor, AppThemeColor.cypressGreen);
        expect(settings.resolvedCustomTheme, device.customTheme);

        final legacy = settings.toLegacyAppPreferences();
        expect(legacy.language, AppLanguage.de);
        expect(legacy.hasSelectedLanguage, isTrue);
        expect(legacy.launchAction, LaunchAction.sync);
        expect(legacy.homeQuickActionPrimary, HomeQuickAction.explore);
        expect(
          legacy.accountThemeColors['workspace-1'],
          AppThemeColor.cypressGreen,
        );
      },
    );

    test(
      'resolves memo engagement through remote and local workspace gates',
      () {
        final workspace = WorkspacePreferences.defaults.copyWith(
          showMemoEngagement: true,
        );

        expect(
          ResolvedAppSettings(
            device: DevicePreferences.defaults,
            workspace: workspace,
            workspaceKey: 'remote',
            hasWorkspace: true,
            hasRemoteAccount: true,
          ).effectiveShowMemoEngagement,
          isTrue,
        );
        expect(
          ResolvedAppSettings(
            device: DevicePreferences.defaults,
            workspace: workspace,
            workspaceKey: 'local',
            hasWorkspace: true,
            hasRemoteAccount: false,
            isLocalLibraryMode: true,
          ).effectiveShowMemoEngagement,
          isFalse,
        );
        expect(
          ResolvedAppSettings(
            device: DevicePreferences.defaults,
            workspace: workspace.copyWith(showMemoEngagement: false),
            workspaceKey: 'remote',
            hasWorkspace: true,
            hasRemoteAccount: true,
          ).effectiveShowMemoEngagement,
          isFalse,
        );
      },
    );
  });
}
