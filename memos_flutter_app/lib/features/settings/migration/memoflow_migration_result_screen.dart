import 'package:flutter/material.dart';

import '../../../application/sync/migration/memoflow_migration_models.dart';
import '../../../core/app_localization.dart';
import '../../../i18n/strings.g.dart';

class MemoFlowMigrationResultScreen extends StatelessWidget {
  const MemoFlowMigrationResultScreen({
    super.key,
    required this.result,
    required this.title,
  });

  final MemoFlowMigrationResult result;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tr = context.t.strings.legacy;
    final applied = result.appliedConfigTypes
        .map((type) => _configTypeLabel(context, type))
        .join('、');
    final skipped = result.skippedConfigTypes
        .map((type) => _configTypeLabel(context, type))
        .join('、');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.sourceDeviceName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: tr.msg_memoflow_migration_notes,
                    value: '${result.memoCount}',
                  ),
                  _InfoRow(
                    label: tr.msg_attachment,
                    value: '${result.attachmentCount}',
                  ),
                  _InfoRow(
                    label: context.tr(zh: '草稿', en: 'Drafts'),
                    value: '${result.draftCount}',
                  ),
                  _InfoRow(
                    label: context.tr(zh: '草稿附件', en: 'Draft attachments'),
                    value: '${result.draftAttachmentCount}',
                  ),
                  _InfoRow(
                    label: tr.msg_memoflow_migration_receive_mode,
                    value:
                        result.receiveMode ==
                            MemoFlowMigrationReceiveMode.newWorkspace
                        ? tr.msg_memoflow_migration_receive_as_new_workspace
                        : tr.msg_memoflow_migration_overwrite_current_workspace,
                  ),
                  if ((result.workspaceName ?? '').trim().isNotEmpty)
                    _InfoRow(
                      label: tr.msg_memoflow_migration_workspace_name,
                      value: result.workspaceName!,
                    ),
                  if (applied.isNotEmpty)
                    _InfoRow(
                      label: tr.msg_memoflow_migration_applied_configs,
                      value: applied,
                    ),
                  if (skipped.isNotEmpty)
                    _InfoRow(
                      label: tr.msg_memoflow_migration_skipped_configs,
                      value: skipped,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
