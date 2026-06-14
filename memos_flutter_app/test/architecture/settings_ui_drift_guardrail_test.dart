import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('migrated settings pages stay on settings UI seams', () async {
    const legacyAllowlist = <String>{
      // Shrink this list as settings pages migrate to SettingsPage,
      // SettingsSection, SettingsToggleRow, and related semantic seams.
    };

    const migratedFiles = <String>{
      'lib/features/settings/account_security_screen.dart',
      'lib/features/settings/bottom_navigation_mode_settings_screen.dart',
      'lib/features/settings/components_settings_screen.dart',
      'lib/features/settings/customize_drawer_screen.dart',
      'lib/features/settings/customize_home_shortcuts_screen.dart',
      'lib/features/settings/desktop_settings_screen.dart',
      'lib/features/settings/desktop_settings_window_app.dart',
      'lib/features/settings/desktop_shortcuts_overview_screen.dart',
      'lib/features/settings/desktop_shortcuts_settings_screen.dart',
      'lib/features/settings/about_us_screen.dart',
      'lib/features/settings/ai_provider_logo.dart',
      'lib/features/settings/ai_provider_settings_screen.dart',
      'lib/features/settings/ai_proxy_settings_screen.dart',
      'lib/features/settings/ai_route_settings_screen.dart',
      'lib/features/settings/ai_service_detail_screen.dart',
      'lib/features/settings/ai_service_model_screen.dart',
      'lib/features/settings/ai_service_wizard_screen.dart',
      'lib/features/settings/ai_settings_screen.dart',
      'lib/features/settings/ai_user_profile_screen.dart',
      'lib/features/settings/api_plugins_screen.dart',
      'lib/features/settings/export_memos_screen.dart',
      'lib/features/settings/export_logs_screen.dart',
      'lib/features/settings/feedback_screen.dart',
      'lib/features/settings/image_bed_settings_screen.dart',
      'lib/features/settings/image_compression_settings_screen.dart',
      'lib/features/settings/import_export_screen.dart',
      'lib/features/settings/laboratory_screen.dart',
      'lib/features/settings/local_network_migration_screen.dart',
      'lib/features/settings/local_mode_setup_screen.dart',
      'lib/features/settings/location_settings_screen.dart',
      'lib/features/settings/location_settings_navigation.dart',
      'lib/features/settings/memoflow_bridge_screen.dart',
      'lib/features/settings/memo_toolbar_settings_screen.dart',
      'lib/features/settings/migration/memoflow_migration_receiver_screen.dart',
      'lib/features/settings/migration/memoflow_migration_result_screen.dart',
      'lib/features/settings/migration/memoflow_migration_role_screen.dart',
      'lib/features/settings/migration/memoflow_migration_send_method_screen.dart',
      'lib/features/settings/migration/memoflow_migration_sender_screen.dart',
      'lib/features/settings/navigation_mode_screen.dart',
      'lib/features/settings/password_lock_screen.dart',
      'lib/features/settings/placeholder_settings_screen.dart',
      'lib/features/settings/preferences_settings_screen.dart',
      'lib/features/settings/quick_qr_action.dart',
      'lib/features/settings/server_settings_screen.dart',
      'lib/features/settings/self_repair_screen.dart',
      'lib/features/settings/settings_screen.dart',
      'lib/features/settings/settings_ui.dart',
      'lib/features/settings/shortcut_editor_screen.dart',
      'lib/features/settings/shortcuts_settings_screen.dart',
      'lib/features/settings/storage_space_screen.dart',
      'lib/features/settings/support_memoflow_screen.dart',
      'lib/features/settings/template_settings_screen.dart',
      'lib/features/settings/user_general_settings_screen.dart',
      'lib/features/settings/user_guide_screen.dart',
      'lib/features/settings/vault_security_status_screen.dart',
      'lib/features/settings/webdav_sync_screen.dart',
      'lib/features/settings/webhooks_settings_screen.dart',
      'lib/features/settings/widgets_screen.dart',
    };

    final files = await Directory('lib/features/settings')
        .list(recursive: true, followLinks: false)
        .where((entry) => entry is File && p.extension(entry.path) == '.dart')
        .cast<File>()
        .toList();

    final settingsFiles = files
        .map((file) => p.relative(file.path, from: Directory.current.path))
        .map((path) => path.replaceAll('\\', '/'))
        .toSet();
    final uncovered = settingsFiles
        .difference(legacyAllowlist)
        .difference(migratedFiles);
    expect(
      uncovered,
      isEmpty,
      reason: uncovered.isEmpty
          ? null
          : 'New settings files must be migrated or explicitly allowlisted:\n'
                '${uncovered.join('\n')}',
    );

    final violations = <String>[];
    for (final relativePath in migratedFiles) {
      final source = await File(relativePath).readAsString();
      final allowances = _allowancesFor(relativePath);
      for (final rule in _rules) {
        final count = rule.pattern.allMatches(source).length;
        final allowed = allowances[rule.id] ?? 0;
        if (count > allowed) {
          violations.add(
            '$relativePath: ${rule.description} count $count exceeds '
            'allowed $allowed',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Migrated settings files must keep visual/platform decisions in '
                'settings UI seams:\n${violations.join('\n')}',
    );
  });

  test(
    'settings row surfaces stay centralized without app button theme drift',
    () async {
      final settingsUi = await File(
        'lib/features/settings/settings_ui.dart',
      ).readAsString();
      final settingsScreen = await File(
        'lib/features/settings/settings_screen.dart',
      ).readAsString();
      final platformListSection = await File(
        'lib/platform/widgets/platform_list_section.dart',
      ).readAsString();
      final appTheme = await File('lib/core/app_theme.dart').readAsString();

      expect(
        settingsUi,
        contains('PlatformListSectionStyle get listSectionStyle'),
      );
      expect(
        settingsUi,
        contains('PlatformListSectionStyle get homeListSectionStyle'),
      );
      expect(settingsUi, contains('class SettingsHomeHierarchyTokens'));
      expect(settingsUi, contains('class SettingsHomeSection'));
      expect(settingsUi, contains('class _SettingsSectionSurface'));
      expect(settingsUi, contains('class _SettingsRowShell'));
      expect(settingsUi, contains('class SettingsCustomRow'));
      expect(settingsUi, contains('_settingsSectionHeaderFontSize'));
      expect(settingsUi, contains('_settingsMobileRowMinHeight'));
      expect(settingsUi, contains('navigationRowMinHeight'));
      expect(settingsUi, contains('class _SettingsHomeDensityScope'));
      expect(settingsUi, contains('ListTileTheme.merge'));
      expect(platformListSection, contains('class PlatformListSectionStyle'));
      expect(platformListSection, contains('mobileMinTileHeight'));
      expect(
        platformListSection,
        contains('tileColor: sectionStyle?.rowColor'),
      );
      expect(platformListSection, contains('boxShadow: style?.boxShadow'));

      for (final forbidden in const [
        'MemoFlowPalette.',
        'BoxShadow(',
        'BorderRadius.circular(',
        'elevation:',
        'minTileHeight:',
      ]) {
        expect(
          settingsScreen,
          isNot(contains(forbidden)),
          reason: 'Settings home hierarchy must stay in settings UI seams.',
        );
      }

      for (final forbidden in const [
        'filledButtonTheme',
        'elevatedButtonTheme',
        'outlinedButtonTheme',
        'textButtonTheme',
      ]) {
        expect(
          appTheme,
          isNot(contains(forbidden)),
          reason: 'This change must not fix app-wide true button colors.',
        );
      }
    },
  );

  test('batch A settings subpages keep migrated controls on seams', () async {
    const migratedControlFiles = <String, List<String>>{
      'lib/features/settings/location_settings_screen.dart': [
        'SettingsOptionChoiceRow<LocationPrecision>',
      ],
      'lib/features/settings/bottom_navigation_mode_settings_screen.dart': [
        'showSettingsSingleChoicePicker<HomeRootDestination>',
      ],
      'lib/features/settings/customize_home_shortcuts_screen.dart': [
        'showSettingsSingleChoicePicker<HomeQuickAction>',
      ],
    };

    const forbiddenControls = <String>[
      'ChoiceChip(',
      'FilterChip(',
      'ActionChip(',
      'InputChip(',
      'DropdownButton<',
      'RadioGroup<',
      'RadioListTile<',
      'CheckboxListTile(',
      'MaterialPageRoute<',
      'showDialog<HomeRootDestination>',
      'showDialog<HomeQuickAction>',
    ];

    final violations = <String>[];
    for (final entry in migratedControlFiles.entries) {
      final source = await File(entry.key).readAsString();
      for (final seam in entry.value) {
        if (!source.contains(seam)) {
          violations.add('${entry.key}: missing migrated seam $seam');
        }
      }
      for (final forbidden in forbiddenControls) {
        if (source.contains(forbidden)) {
          violations.add('${entry.key}: forbidden migrated control $forbidden');
        }
      }
    }

    final components = await File(
      'lib/features/settings/components_settings_screen.dart',
    ).readAsString();
    for (final requiredSeam in const [
      'buildPlatformPageRoute<void>',
      'showSettingsConfirmationDialog(',
      'showPlatformDialog<bool>',
      'SettingsMultiChoiceRow<String>',
    ]) {
      if (!components.contains(requiredSeam)) {
        violations.add(
          'lib/features/settings/components_settings_screen.dart: '
          'missing migrated seam $requiredSeam',
        );
      }
    }
    for (final forbidden in const [
      'CheckboxListTile(',
      'MaterialPageRoute<',
      'showDialog<bool>',
    ]) {
      if (components.contains(forbidden)) {
        violations.add(
          'lib/features/settings/components_settings_screen.dart: '
          'forbidden migrated control $forbidden',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Batch A migrated settings subpages must keep high-risk controls '
                'on settings/platform seams:\n${violations.join('\n')}',
    );
  });

  test('batch B settings subpages keep migrated controls on seams', () async {
    const requiredSeams = <String, List<String>>{
      'lib/features/settings/memo_toolbar_settings_screen.dart': [
        'showPlatformDialog<MemoToolbarCustomButton>',
        'SettingsOptionChipGroup<_CustomIconGroup>',
        'SettingsFormDialog',
        'SettingsDialogTextField',
      ],
      'lib/features/settings/shortcut_editor_screen.dart': [
        'showPlatformPicker<Set<String>>',
        'SettingsRemovableChip',
        'SettingsMultiChoiceList<String>',
      ],
      'lib/features/settings/template_settings_screen.dart': [
        'showPlatformDialog<MemoTemplate>',
        'showPlatformDialog<MemoTemplateVariableSettings>',
        'showSettingsConfirmationDialog(',
        'SettingsFormDialog',
        'SettingsDialogTextField',
      ],
    };

    const forbiddenByFile = <String, List<String>>{
      'lib/features/settings/memo_toolbar_settings_screen.dart': [
        'ChoiceChip(',
        'showDialog<MemoToolbarCustomButton>',
        'AlertDialog(',
      ],
      'lib/features/settings/shortcut_editor_screen.dart': [
        'InputChip(',
        'CheckboxListTile(',
        'showModalBottomSheet<Set<String>>',
      ],
      'lib/features/settings/template_settings_screen.dart': [
        'showDialog<',
        'AlertDialog(',
      ],
    };

    final rawTextField = RegExp(r'(^|[^A-Za-z0-9_])TextField\s*\(');
    final violations = <String>[];
    for (final entry in requiredSeams.entries) {
      final source = await File(entry.key).readAsString();
      for (final seam in entry.value) {
        if (!source.contains(seam)) {
          violations.add('${entry.key}: missing migrated seam $seam');
        }
      }
      for (final forbidden in forbiddenByFile[entry.key] ?? const <String>[]) {
        if (source.contains(forbidden)) {
          violations.add('${entry.key}: forbidden migrated control $forbidden');
        }
      }
      if (rawTextField.hasMatch(source)) {
        violations.add('${entry.key}: forbidden raw TextField');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Batch B migrated settings subpages must keep high-risk controls '
                'on settings/platform seams:\n${violations.join('\n')}',
    );
  });

  test(
    'batch C AI settings subpages keep migrated controls on seams',
    () async {
      const requiredSeams = <String, List<String>>{
        'lib/features/settings/ai_route_settings_screen.dart': [
          'showSettingsSingleChoicePicker<AiSelectableRouteOption>',
        ],
        'lib/features/settings/ai_service_wizard_screen.dart': [
          'showPlatformDialog<AiProviderTemplate>',
          'buildPlatformPageRoute<void>',
          'SettingsDialogTextField',
          'SettingsActionPill',
          'SettingsMultiChoiceList<AiCapability>',
          'SettingsToggleRow',
        ],
        'lib/features/settings/ai_service_model_screen.dart': [
          'showPlatformDialog<AiModelEntry>',
          'showSettingsSingleChoicePicker<_ModelSourceFilter>',
          'showSettingsSingleChoicePicker<_ModelSortMode>',
          'showSettingsConfirmationDialog(',
          'SettingsActionPill',
          'SettingsMultiChoiceList<AiCapability>',
          'SettingsToggleRow',
        ],
        'lib/features/settings/ai_service_detail_screen.dart': [
          'showPlatformAlertDialog<_AiServiceUnsavedCloseAction>',
          'showSettingsConfirmationDialog(',
          'buildPlatformPageRoute<void>',
          'SettingsDialogTextField',
          'SettingsToggleRow',
        ],
        'lib/features/settings/ai_provider_settings_screen.dart': [
          'showPlatformDialog<String>',
          'showPlatformDialog<String?>',
          'SettingsFormDialog',
          'SettingsDialogTextField',
          'SettingsActionPill',
        ],
      };

      const forbiddenControls = <String>[
        'ChoiceChip(',
        'FilterChip(',
        'ActionChip(',
        'InputChip(',
        'SwitchListTile',
        'TextFormField(',
        'showDialog<',
        'showModalBottomSheet',
        'AlertDialog(',
        'MaterialPageRoute<',
        'PopupMenuButton',
        'TextButton(',
        'FilledButton(',
        'OutlinedButton(',
        'ElevatedButton(',
        'ScaffoldMessenger',
        'SnackBar(',
      ];

      final rawTextField = RegExp(r'(^|[^A-Za-z0-9_])TextField\s*\(');
      final violations = <String>[];
      for (final entry in requiredSeams.entries) {
        final source = await File(entry.key).readAsString();
        for (final seam in entry.value) {
          if (!source.contains(seam)) {
            violations.add('${entry.key}: missing migrated seam $seam');
          }
        }
        for (final forbidden in forbiddenControls) {
          if (source.contains(forbidden)) {
            violations.add(
              '${entry.key}: forbidden migrated control $forbidden',
            );
          }
        }
        if (rawTextField.hasMatch(source)) {
          violations.add('${entry.key}: forbidden raw TextField');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Batch C AI settings subpages must keep high-risk controls on '
                  'settings/platform seams:\n${violations.join('\n')}',
      );
    },
  );

  test(
    'batch D WebDAV and utility settings keep migrated controls on seams',
    () async {
      const requiredSeams = <String, List<String>>{
        'lib/features/settings/webdav_sync_screen.dart': [
          'showSettingsSingleChoicePicker<WebDavAuthMode>',
          'showSettingsSingleChoicePicker<WebDavBackupSchedule>',
          'showSettingsSingleChoicePicker<WebDavBackupEncryptionMode>',
          'showPlatformDialog<bool>',
          'showPlatformDialog<Set<WebDavBackupConfigType>>',
          'showSettingsConfirmationDialog',
          'SettingsFormDialog',
          'SettingsDialogTextField',
          'SettingsMultiChoiceRow',
          'SettingsSingleChoiceList<bool>',
          'PlatformProgress',
          'PlatformPrimaryAction',
        ],
        'lib/features/settings/vault_security_status_screen.dart': [
          'showSettingsConfirmationDialog',
          'showPlatformDialog<bool>',
          'showSettingsSingleChoicePicker<_BackupTestMode>',
          'SettingsFormDialog',
          'SettingsDialogTextField',
          'PlatformProgress',
          'showTopToast',
        ],
        'lib/features/settings/account_security_screen.dart': [
          'showSettingsConfirmationDialog',
          'showTopToast',
        ],
        'lib/features/settings/storage_space_screen.dart': [
          'showSettingsConfirmationDialog',
          'PlatformProgress',
          'showTopToast',
        ],
        'lib/features/settings/self_repair_screen.dart': [
          'showSettingsConfirmationDialog',
          'PlatformProgress',
          'showTopToast',
        ],
      };

      const forbiddenControls = <String>[
        'SegmentedButton',
        'CheckboxListTile(',
        'RadioListTile<',
        'DropdownButton<',
        'ChoiceChip(',
        'FilterChip(',
        'ActionChip(',
        'InputChip(',
        'SwitchListTile',
        'TextFormField(',
        'showDialog<',
        'showDialog(',
        'showModalBottomSheet',
        'AlertDialog(',
        'MaterialPageRoute<',
        'LinearProgressIndicator',
        'CircularProgressIndicator',
        'PopupMenuButton',
        'TextButton(',
        'FilledButton(',
        'OutlinedButton(',
        'ElevatedButton(',
        'ScaffoldMessenger',
        'SnackBar(',
      ];

      final rawTextField = RegExp(r'(^|[^A-Za-z0-9_])TextField\s*\(');
      final violations = <String>[];
      for (final entry in requiredSeams.entries) {
        final source = await File(entry.key).readAsString();
        for (final seam in entry.value) {
          if (!source.contains(seam)) {
            violations.add('${entry.key}: missing migrated seam $seam');
          }
        }
        for (final forbidden in forbiddenControls) {
          if (source.contains(forbidden)) {
            violations.add(
              '${entry.key}: forbidden migrated control $forbidden',
            );
          }
        }
        if (rawTextField.hasMatch(source)) {
          violations.add('${entry.key}: forbidden raw TextField');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Batch D settings subpages must keep high-risk controls on '
                  'settings/platform seams:\n${violations.join('\n')}',
      );
    },
  );

  test('batch E settings subpages keep migrated controls on seams', () async {
    const requiredSeams = <String, List<String>>{
      'lib/features/settings/migration/memoflow_migration_sender_screen.dart': [
        'SettingsMultiChoiceRow<MemoFlowMigrationConfigType>',
        'SettingsProgressRow',
        'buildPlatformPageRoute<void>',
      ],
      'lib/features/settings/migration/memoflow_migration_receiver_screen.dart':
          [
            'SettingsSingleChoiceList<MemoFlowMigrationReceiveMode>',
            'SettingsMultiChoiceRow<MemoFlowMigrationConfigType>',
            'SettingsProgressRow',
            'buildPlatformPageRoute<void>',
          ],
      'lib/features/settings/migration/memoflow_migration_role_screen.dart': [
        'buildPlatformPageRoute<void>',
      ],
      'lib/features/settings/migration/memoflow_migration_send_method_screen.dart':
          [
            'showPlatformDialog<_ManualReceiverConnectRequest>',
            'SettingsFormDialog',
            'SettingsDialogTextField',
            'SettingsProgressRow',
            'buildPlatformPageRoute<String>',
            'buildPlatformPageRoute<void>',
          ],
      'lib/features/settings/local_network_migration_screen.dart': [
        'buildPlatformPageRoute<void>',
      ],
      'lib/features/settings/support_memoflow_screen.dart': ['showTopToast'],
      'lib/features/settings/user_general_settings_screen.dart': [
        'showTopToast',
        'SettingsProgressRow',
      ],
      'lib/features/settings/export_logs_screen.dart': [
        'showSettingsConfirmationDialog',
        'SettingsMultilineFieldRow',
        'IconButton',
      ],
      'lib/features/settings/export_memos_screen.dart': [
        'showPlatformAlertDialog<bool>',
        'PlatformProgress',
        'showTopToast',
      ],
      'lib/features/settings/api_plugins_screen.dart': [
        'showSettingsSingleChoicePicker<_TokenExpiration>',
        'showPlatformDialog<void>',
        'SettingsDialogTextField',
        'SettingsProgressRow',
        'PlatformProgress',
      ],
      'lib/features/settings/webhooks_settings_screen.dart': [
        'showPlatformDialog<_WebhookDraft>',
        'showSettingsConfirmationDialog',
        'SettingsDialogTextField',
        'SettingsProgressRow',
      ],
      'lib/features/settings/password_lock_screen.dart': [
        'showPlatformDialog<String?>',
        'showSettingsSingleChoicePicker<AutoLockTime>',
        'SettingsDialogTextField',
        'SettingsFeedbackRow',
      ],
      'lib/features/settings/desktop_shortcuts_settings_screen.dart': [
        'showPlatformDialog<DesktopShortcutBinding>',
        'SettingsFormDialog',
        'SettingsFeedbackRow',
      ],
    };

    const forbiddenControls = <String>[
      'SegmentedButton',
      'CheckboxListTile(',
      'RadioListTile<',
      'DropdownButton<',
      'ChoiceChip(',
      'FilterChip(',
      'ActionChip(',
      'InputChip(',
      'TextFormField(',
      'showDialog<',
      'showModalBottomSheet',
      'AlertDialog(',
      'MaterialPageRoute<',
      'LinearProgressIndicator',
      'CircularProgressIndicator',
      'PopupMenuButton',
      'TextButton(',
      'FilledButton(',
      'OutlinedButton(',
      'ElevatedButton(',
      'ScaffoldMessenger',
      'SnackBar(',
    ];

    final rawTextField = RegExp(r'(^|[^A-Za-z0-9_])TextField\s*\(');
    final violations = <String>[];
    for (final entry in requiredSeams.entries) {
      final source = await File(entry.key).readAsString();
      for (final seam in entry.value) {
        if (!source.contains(seam)) {
          violations.add('${entry.key}: missing migrated seam $seam');
        }
      }
      for (final forbidden in forbiddenControls) {
        if (source.contains(forbidden)) {
          violations.add('${entry.key}: forbidden migrated control $forbidden');
        }
      }
      if (rawTextField.hasMatch(source)) {
        violations.add('${entry.key}: forbidden raw TextField');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Batch E settings subpages must keep high-risk controls on '
                'settings/platform seams:\n${violations.join('\n')}',
    );
  });

  test('settings form ergonomics targets stay on semantic seams', () async {
    const requiredSeams = <String, List<String>>{
      'lib/features/settings/settings_ui.dart': [
        'class SettingsInlineTextFieldRow',
        'class SettingsNumericInlineFieldRow',
        'class SettingsFormFieldRow',
        'class SettingsMultilineFieldRow',
        'class SettingsFieldBlock',
        'class SettingsLongValueRow',
        'Future<DateTime?> showSettingsDatePicker',
        'Future<TimeOfDay?> showSettingsTimePicker',
        'Future<DateTime?> showSettingsDateTimePicker',
      ],
      'lib/features/settings/webdav_sync_screen.dart': [
        'SettingsFieldBlock',
        'SettingsNumericInlineFieldRow',
        'SettingsNavigationRow',
      ],
      'lib/features/settings/ai_proxy_settings_screen.dart': [
        'SettingsInlineTextFieldRow',
        'SettingsNumericInlineFieldRow',
        'SettingsFormFieldRow',
      ],
      'lib/features/settings/image_bed_settings_screen.dart': [
        'SettingsInlineTextFieldRow',
        'SettingsNumericInlineFieldRow',
        'SettingsFormFieldRow',
      ],
      'lib/features/settings/location_settings_screen.dart': [
        'SettingsFormFieldRow',
      ],
      'lib/features/settings/memoflow_bridge_screen.dart': [
        'SettingsInlineTextFieldRow',
        'SettingsNumericInlineFieldRow',
      ],
      'lib/features/settings/shortcut_editor_screen.dart': [
        'SettingsInlineTextFieldRow',
        'SettingsNumericInlineFieldRow',
      ],
      'lib/features/settings/server_settings_screen.dart': [
        'SettingsNumericInlineFieldRow',
      ],
      'lib/features/settings/ai_user_profile_screen.dart': [
        'SettingsMultilineFieldRow',
      ],
      'lib/features/settings/export_logs_screen.dart': [
        'SettingsMultilineFieldRow',
      ],
      'lib/features/reminders/reminder_settings_screen.dart': [
        'SettingsPage',
        'SettingsToggleRow',
        'SettingsNavigationRow',
        'SettingsActionPill',
        'showSettingsTimePicker',
      ],
      'lib/features/reminders/memo_reminder_editor_screen.dart': [
        'SettingsPage',
        'showSettingsDateTimePicker',
        'SettingsOptionChipGroup<ReminderMode>',
        'SettingsActionPill',
      ],
      'lib/features/reminders/custom_notification_screen.dart': [
        'SettingsPage',
        'SettingsInlineTextFieldRow',
        'SettingsMultilineFieldRow',
      ],
    };

    const formTargetFiles = <String>{
      'lib/features/settings/webdav_sync_screen.dart',
      'lib/features/settings/ai_proxy_settings_screen.dart',
      'lib/features/settings/image_bed_settings_screen.dart',
      'lib/features/settings/location_settings_screen.dart',
      'lib/features/settings/memoflow_bridge_screen.dart',
      'lib/features/settings/shortcut_editor_screen.dart',
      'lib/features/settings/server_settings_screen.dart',
      'lib/features/settings/ai_user_profile_screen.dart',
      'lib/features/settings/export_logs_screen.dart',
      'lib/features/reminders/reminder_settings_screen.dart',
      'lib/features/reminders/memo_reminder_editor_screen.dart',
      'lib/features/reminders/custom_notification_screen.dart',
    };

    const forbiddenInTargets = <String>[
      'PlatformTextField(',
      'InputBorder.none',
      'showDatePicker(',
      'showTimePicker(',
      'OutlinedButton.styleFrom',
      'BorderRadius.circular(22)',
      'class _InputRow',
      'class _InlineInputRow',
      'class _FieldBlock',
      'class _FieldSurface',
      'class _InputCard',
    ];

    final rawTextField = RegExp(
      r'(^|[^A-Za-z0-9_])(?:TextField|TextFormField|CupertinoTextField)\s*\(',
    );
    final pageLocalFieldWrapper = RegExp(
      r'\bclass\s+_[A-Za-z0-9]*(?:Field|Input)[A-Za-z0-9]*(?:Row|Block|Card|Surface)\b',
    );
    final violations = <String>[];
    for (final entry in requiredSeams.entries) {
      final source = await File(entry.key).readAsString();
      for (final seam in entry.value) {
        if (!source.contains(seam)) {
          violations.add('${entry.key}: missing ergonomic seam $seam');
        }
      }
      if (formTargetFiles.contains(entry.key) &&
          pageLocalFieldWrapper.hasMatch(source)) {
        violations.add('${entry.key}: forbidden page-local field wrapper');
      }
    }

    for (final relativePath in formTargetFiles) {
      final source = await File(relativePath).readAsString();
      for (final forbidden in forbiddenInTargets) {
        if (source.contains(forbidden)) {
          violations.add(
            '$relativePath: forbidden form ergonomics regression $forbidden',
          );
        }
      }
      if (rawTextField.hasMatch(source)) {
        violations.add('$relativePath: forbidden raw TextField');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Settings form ergonomics targets must stay on semantic seams:\n'
                '${violations.join('\n')}',
    );
  });
}

class _DriftRule {
  const _DriftRule(this.id, this.pattern, this.description);

  final String id;
  final RegExp pattern;
  final String description;
}

final _rules = <_DriftRule>[
  _DriftRule(
    'scaffold',
    RegExp(r'\breturn\s+Scaffold\s*\('),
    'direct Scaffold',
  ),
  _DriftRule(
    'toggle_card',
    RegExp(r'\bclass\s+_ToggleCard\b'),
    'private _ToggleCard',
  ),
  _DriftRule('switch', RegExp(r'(^|[^A-Za-z0-9_])Switch\s*\('), 'bare Switch'),
  _DriftRule(
    'switch_adaptive',
    RegExp(r'(^|[^A-Za-z0-9_])Switch\.adaptive\s*\('),
    'bare Switch.adaptive',
  ),
  _DriftRule(
    'style_from',
    RegExp(r'\bstyleFrom\s*\('),
    'page-local button styleFrom',
  ),
  _DriftRule(
    'palette',
    RegExp(r'\bMemoFlowPalette\.'),
    'direct MemoFlowPalette',
  ),
  _DriftRule(
    'platform_list_section',
    RegExp(r'\bPlatformListSection\s*\('),
    'direct PlatformListSection outside settings surface seam',
  ),
  _DriftRule(
    'platform_list_section_row',
    RegExp(r'\bPlatformListSectionRow\s*\('),
    'direct PlatformListSectionRow outside settings row seam',
  ),
  _DriftRule(
    'platform_list_tile',
    RegExp(r'\bPlatformListTile\s*\('),
    'direct PlatformListTile outside settings row seam',
  ),
  _DriftRule(
    'material_list_tile',
    RegExp(r'\bListTile\s*\('),
    'direct Material ListTile outside settings row seam',
  ),
  _DriftRule(
    'cupertino_list_tile',
    RegExp(r'\bCupertinoListTile\s*\('),
    'direct CupertinoListTile outside settings row seam',
  ),
];

Map<String, int> _allowancesFor(String relativePath) {
  if (relativePath == 'lib/features/settings/settings_ui.dart') {
    return const {
      // Settings UI owns settings row/section surface tokens and delegates them
      // to its own row/section shells. It also owns the mobile settings home
      // hierarchy section seam.
      'palette': 8,
      'platform_list_section': 1,
    };
  }
  if (relativePath ==
      'lib/features/settings/preferences_settings_screen.dart') {
    return const {
      // Custom color/surface editors intentionally preview and edit palette
      // values locally until those editor-specific controls are extracted.
      'palette': 8,
      'style_from': 4,
    };
  }
  if (relativePath ==
      'lib/features/settings/desktop_settings_window_app.dart') {
    return const {
      // Independent settings-window composition root applies persisted theme
      // color before building its MaterialApp; no other palette usage allowed.
      'palette': 1,
    };
  }
  return const {};
}
