import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../application/sync/migration/memoflow_migration_models.dart';
import '../../../core/app_localization.dart';
import '../../../i18n/strings.g.dart';
import '../../../platform/platform_route.dart';
import '../../../platform/widgets/platform_primary_action.dart';
import '../../../state/migration/memoflow_migration_providers.dart';
import '../../../state/migration/memoflow_migration_state.dart';
import '../settings_ui.dart';
import 'memoflow_migration_result_screen.dart';

class MemoFlowMigrationReceiverScreen extends ConsumerWidget {
  const MemoFlowMigrationReceiverScreen({super.key});

  static const double _kQrMaxSize = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoFlowMigrationReceiverControllerProvider);
    final controller = ref.read(
      memoFlowMigrationReceiverControllerProvider.notifier,
    );
    final tr = context.t.strings.legacy;
    final proposal = state.proposal;
    final sensitiveTypes =
        proposal?.manifest.configTypes
            .where((type) => type.isSensitive)
            .toList(growable: false) ??
        const <MemoFlowMigrationConfigType>[];

    return SettingsPage(
      title: Text(tr.msg_memoflow_migration_receiver),
      children: [
        if (state.phase == MemoFlowMigrationReceiverPhase.idle ||
            state.phase == MemoFlowMigrationReceiverPhase.startingSession) ...[
          SettingsSection(
            children: [
              SettingsInfoRow(
                description: tr.msg_memoflow_migration_receiver_desc,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed:
                  state.phase == MemoFlowMigrationReceiverPhase.startingSession
                  ? null
                  : controller.startSession,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(tr.msg_memoflow_migration_start_receive),
            ),
          ),
        ],
        if (state.sessionDescriptor != null &&
            (state.phase == MemoFlowMigrationReceiverPhase.waitingProposal ||
                state.phase ==
                    MemoFlowMigrationReceiverPhase.reviewingProposal ||
                state.phase == MemoFlowMigrationReceiverPhase.receiving)) ...[
          const SizedBox(height: 14),
          SettingsSection(
            header: Text(state.sessionDescriptor!.receiverDeviceName),
            children: [
              if ((state.qrPayload ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final qrSize = constraints.maxWidth > _kQrMaxSize
                          ? _kQrMaxSize
                          : constraints.maxWidth;
                      return Center(
                        child: SizedBox.square(
                          dimension: qrSize,
                          child: PrettyQrView.data(
                            data: state.qrPayload!,
                            decoration: const PrettyQrDecoration(),
                            errorCorrectLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SettingsInfoRow(
                description:
                    state.statusMessage ??
                    tr.msg_memoflow_migration_waiting_receiver,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        state.sessionDescriptor!.address,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        '${tr.msg_bridge_pair_code_label}: '
                        '${state.sessionDescriptor!.pairingCode}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        if (proposal != null &&
            state.phase ==
                MemoFlowMigrationReceiverPhase.reviewingProposal) ...[
          const SizedBox(height: 14),
          SettingsSection(
            header: Text(tr.msg_memoflow_migration_review_proposal),
            children: [
              _InfoRow(
                label: tr.msg_memoflow_migration_sender_device,
                value: proposal.senderDeviceName,
              ),
              _InfoRow(
                label: tr.msg_memoflow_migration_notes,
                value: '${proposal.manifest.memoCount}',
              ),
              _InfoRow(
                label: tr.msg_attachment,
                value: '${proposal.manifest.attachmentCount}',
              ),
              _InfoRow(
                label: context.tr(zh: '草稿', en: 'Drafts'),
                value: '${proposal.manifest.draftCount}',
              ),
              _InfoRow(
                label: context.tr(zh: '草稿附件', en: 'Draft attachments'),
                value: '${proposal.manifest.draftAttachmentCount}',
              ),
              _InfoRow(
                label: tr.msg_memoflow_migration_size,
                value: _formatBytes(proposal.manifest.totalBytes),
              ),
              if (proposal.manifest.includeMemos)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.msg_memoflow_migration_receive_mode),
                      const SizedBox(height: 8),
                      SettingsSingleChoiceList<MemoFlowMigrationReceiveMode>(
                        value: state.selectedReceiveMode,
                        options: [
                          SettingsChoiceOption<MemoFlowMigrationReceiveMode>(
                            value: MemoFlowMigrationReceiveMode.newWorkspace,
                            label: tr
                                .msg_memoflow_migration_receive_as_new_workspace,
                          ),
                          if (state.canOverwriteCurrentWorkspace)
                            SettingsChoiceOption<MemoFlowMigrationReceiveMode>(
                              value:
                                  MemoFlowMigrationReceiveMode.overwriteCurrent,
                              label: tr
                                  .msg_memoflow_migration_overwrite_current_workspace,
                            ),
                        ],
                        onChanged: controller.setReceiveMode,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (sensitiveTypes.isNotEmpty) ...[
            const SizedBox(height: 14),
            SettingsSection(
              header: Text(tr.msg_memoflow_migration_sensitive_config_confirm),
              children: [
                ...sensitiveTypes.map(
                  (type) => SettingsMultiChoiceRow<MemoFlowMigrationConfigType>(
                    option: SettingsChoiceOption<MemoFlowMigrationConfigType>(
                      value: type,
                      label: _configTypeLabel(context, type),
                    ),
                    selected: state.acceptedSensitiveConfigTypes.contains(type),
                    onChanged: (value) =>
                        controller.toggleSensitiveConfigType(type, value),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: controller.acceptProposal,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(tr.msg_memoflow_migration_accept),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: controller.rejectProposal,
              icon: const Icon(Icons.cancel_outlined),
              variant: PlatformPrimaryActionVariant.outlined,
              label: Text(tr.msg_memoflow_migration_reject),
            ),
          ),
        ],
        if (state.phase == MemoFlowMigrationReceiverPhase.receiving &&
            state.latestStatus != null) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [
              SettingsProgressRow(
                label: state.latestStatus!.message?.trim().isNotEmpty == true
                    ? state.latestStatus!.message!.trim()
                    : tr.msg_memoflow_migration_receiver,
                value: _resolveProgress(proposal, state.latestStatus),
              ),
              if ((state.latestStatus?.receivedBytes ?? 0) > 0)
                SettingsInfoRow(
                  description: tr.msg_memoflow_migration_received_bytes(
                    size: _formatBytes(state.latestStatus!.receivedBytes!),
                  ),
                ),
            ],
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
        if ((state.errorMessage ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [SettingsWarningRow(message: state.errorMessage!)],
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
        if (state.phase == MemoFlowMigrationReceiverPhase.waitingProposal) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: controller.stopSession,
              variant: PlatformPrimaryActionVariant.outlined,
              label: Text(tr.msg_cancel),
            ),
          ),
        ],
      ],
    );
  }

  double? _resolveProgress(
    MemoFlowMigrationProposal? proposal,
    MemoFlowMigrationStatusSnapshot? status,
  ) {
    final total = proposal?.manifest.totalBytes ?? 0;
    final received = status?.receivedBytes ?? 0;
    if (total <= 0 || received <= 0) return null;
    final value = received / total;
    return value.clamp(0, 1);
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
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
