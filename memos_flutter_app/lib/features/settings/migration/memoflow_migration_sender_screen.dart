import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/sync/migration/memoflow_migration_models.dart';
import '../../../core/app_localization.dart';
import '../../../i18n/strings.g.dart';
import '../../../platform/platform_route.dart';
import '../../../platform/widgets/platform_primary_action.dart';
import '../../../state/migration/memoflow_migration_providers.dart';
import '../../../state/migration/memoflow_migration_sender_controller.dart';
import '../../../state/migration/memoflow_migration_state.dart';
import '../settings_ui.dart';
import 'memoflow_migration_result_screen.dart';
import 'memoflow_migration_send_method_screen.dart';

class MemoFlowMigrationSenderScreen extends ConsumerWidget {
  const MemoFlowMigrationSenderScreen({
    super.key,
    this.initialReceiverQrPayload,
  });

  final String? initialReceiverQrPayload;

  Future<void> _prepareAndContinue(
    BuildContext context,
    WidgetRef ref,
    MemoFlowMigrationSenderController controller,
  ) async {
    await controller.buildPackage();
    if (!context.mounted) return;
    final nextState = ref.read(memoFlowMigrationSenderControllerProvider);
    if (nextState.packageResult == null) return;
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoFlowMigrationSendMethodScreen(
          initialReceiverQrPayload: initialReceiverQrPayload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoFlowMigrationSenderControllerProvider);
    final controller = ref.read(
      memoFlowMigrationSenderControllerProvider.notifier,
    );
    final tr = context.t.strings.legacy;

    return SettingsPage(
      title: Text(tr.msg_memoflow_migration_sender),
      children: [
        if (!state.isLocalLibraryMode) ...[
          SettingsSection(
            children: [
              SettingsWarningRow(
                message: tr.msg_memoflow_migration_sender_only_local_mode,
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        SettingsSection(
          header: Text(tr.msg_memoflow_migration_select_content),
          children: [
            SettingsMultiChoiceRow<String>(
              option: SettingsChoiceOption<String>(
                value: 'memos',
                label: tr.msg_memoflow_migration_notes,
                description: tr.msg_memoflow_migration_notes_desc,
                disabledDescription:
                    tr.msg_memoflow_migration_sender_only_local_mode,
              ),
              selected: state.includeMemos,
              enabled: state.isLocalLibraryMode,
              onChanged: controller.setIncludeMemos,
            ),
            SettingsMultiChoiceRow<String>(
              option: SettingsChoiceOption<String>(
                value: 'settings',
                label: tr.msg_memoflow_migration_settings,
                description: tr.msg_memoflow_migration_settings_desc,
              ),
              selected: state.includeSettings,
              onChanged: controller.setIncludeSettings,
            ),
          ],
        ),
        if (state.includeSettings) ...[
          const SizedBox(height: 14),
          SettingsSection(
            header: Text(tr.msg_memoflow_migration_safe_config),
            children: [
              ...memoFlowMigrationSafeConfigDefaults.map(
                (type) => SettingsMultiChoiceRow<MemoFlowMigrationConfigType>(
                  option: SettingsChoiceOption<MemoFlowMigrationConfigType>(
                    value: type,
                    label: _configTypeLabel(context, type),
                  ),
                  selected: state.selectedConfigTypes.contains(type),
                  onChanged: (value) =>
                      controller.toggleConfigType(type, value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsSection(
            header: Text(tr.msg_memoflow_migration_sensitive_config),
            children: [
              ...memoFlowMigrationSensitiveConfigDefaults.map(
                (type) => SettingsMultiChoiceRow<MemoFlowMigrationConfigType>(
                  option: SettingsChoiceOption<MemoFlowMigrationConfigType>(
                    value: type,
                    label: _configTypeLabel(context, type),
                  ),
                  selected: state.selectedConfigTypes.contains(type),
                  onChanged: (value) =>
                      controller.toggleConfigType(type, value),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SettingsAction(
            onPressed: state.canBuildPackage
                ? () => _prepareAndContinue(context, ref, controller)
                : null,
            icon: const Icon(Icons.send_outlined),
            label: Text(tr.msg_memoflow_migration_prepare_send),
          ),
        ),
        if (state.phase == MemoFlowMigrationSenderPhase.buildingPackage) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [
              SettingsProgressRow(
                label: state.statusMessage?.trim().isNotEmpty == true
                    ? state.statusMessage!.trim()
                    : tr.msg_memoflow_migration_prepare_send,
              ),
            ],
          ),
        ],
        if ((state.errorMessage ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [SettingsWarningRow(message: state.errorMessage!)],
          ),
        ],
        if (state.result != null) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [
              SettingsInfoRow(description: tr.msg_memoflow_migration_completed),
              if ((state.statusMessage ?? '').isNotEmpty)
                SettingsInfoRow(description: state.statusMessage!),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: () {
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => MemoFlowMigrationResultScreen(
                      result: state.result!,
                      title: tr.msg_memoflow_migration_result,
                    ),
                  ),
                );
              },
              variant: PlatformPrimaryActionVariant.tonal,
              label: Text(tr.msg_memoflow_migration_view_result),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: tr.msg_memoflow_migration_foreground_notice,
            ),
          ],
        ),
      ],
    );
  }

  String _configTypeLabel(
    BuildContext context,
    MemoFlowMigrationConfigType type,
  ) {
    final tr = context.t.strings.legacy;
    return switch (type) {
      MemoFlowMigrationConfigType.preferences => tr.msg_preferences,
      MemoFlowMigrationConfigType.reminderSettings => tr.msg_reminder_settings,
      MemoFlowMigrationConfigType.templateSettings => tr.msg_template,
      MemoFlowMigrationConfigType.locationSettings => tr.msg_location,
      MemoFlowMigrationConfigType.imageCompressionSettings =>
        tr.msg_restore_config_item_image_compression,
      MemoFlowMigrationConfigType.draftBox => context.tr(
        zh: '草稿箱',
        en: 'Draft box',
      ),
      MemoFlowMigrationConfigType.aiSettings => tr.msg_restore_config_item_ai,
      MemoFlowMigrationConfigType.imageBedSettings =>
        tr.msg_restore_config_item_image_bed,
      MemoFlowMigrationConfigType.appLock =>
        tr.msg_restore_config_item_app_lock,
      MemoFlowMigrationConfigType.webdavSettings =>
        tr.msg_restore_config_item_webdav,
    };
  }
}
