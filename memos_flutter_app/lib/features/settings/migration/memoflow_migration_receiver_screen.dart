import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../application/sync/migration/memoflow_migration_models.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/migration/memoflow_migration_providers.dart';
import '../../../state/migration/memoflow_migration_state.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(tr.msg_memoflow_migration_receiver)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.phase == MemoFlowMigrationReceiverPhase.idle ||
              state.phase ==
                  MemoFlowMigrationReceiverPhase.startingSession) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.msg_memoflow_migration_receiver_desc,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          state.phase ==
                              MemoFlowMigrationReceiverPhase.startingSession
                          ? null
                          : controller.startSession,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text(tr.msg_memoflow_migration_start_receive),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (state.sessionDescriptor != null &&
              (state.phase == MemoFlowMigrationReceiverPhase.waitingProposal ||
                  state.phase ==
                      MemoFlowMigrationReceiverPhase.reviewingProposal ||
                  state.phase == MemoFlowMigrationReceiverPhase.receiving)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      state.sessionDescriptor!.receiverDeviceName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if ((state.qrPayload ?? '').isNotEmpty)
                      LayoutBuilder(
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
                    const SizedBox(height: 12),
                    Text(
                      state.statusMessage ??
                          tr.msg_memoflow_migration_waiting_receiver,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SelectionArea(
                      child: Column(
                        children: [
                          SelectableText(
                            state.sessionDescriptor!.address,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            '${tr.msg_bridge_pair_code_label}: '
                            '${state.sessionDescriptor!.pairingCode}',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (proposal != null &&
              state.phase ==
                  MemoFlowMigrationReceiverPhase.reviewingProposal) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.msg_memoflow_migration_review_proposal,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
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
                      label: tr.msg_memoflow_migration_size,
                      value: _formatBytes(proposal.manifest.totalBytes),
                    ),
                    if (proposal.manifest.includeMemos) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr.msg_memoflow_migration_receive_mode,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<MemoFlowMigrationReceiveMode>(
                        segments: <ButtonSegment<MemoFlowMigrationReceiveMode>>[
                          ButtonSegment<MemoFlowMigrationReceiveMode>(
                            value: MemoFlowMigrationReceiveMode.newWorkspace,
                            label: Text(
                              tr.msg_memoflow_migration_receive_as_new_workspace,
                            ),
                          ),
                          if (state.canOverwriteCurrentWorkspace)
                            ButtonSegment<MemoFlowMigrationReceiveMode>(
                              value:
                                  MemoFlowMigrationReceiveMode.overwriteCurrent,
                              label: Text(
                                tr.msg_memoflow_migration_overwrite_current_workspace,
                              ),
                            ),
                        ],
                        selected: <MemoFlowMigrationReceiveMode>{
                          state.selectedReceiveMode,
                        },
                        onSelectionChanged: (selection) {
                          final value = selection.isEmpty
                              ? null
                              : selection.first;
                          if (value != null) controller.setReceiveMode(value);
                        },
                      ),
                    ],
                    if (sensitiveTypes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr.msg_memoflow_migration_sensitive_config_confirm,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ...sensitiveTypes.map(
                        (type) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_configTypeLabel(context, type)),
                          value: state.acceptedSensitiveConfigTypes.contains(
                            type,
                          ),
                          onChanged: (value) => controller
                              .toggleSensitiveConfigType(type, value ?? false),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: controller.acceptProposal,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(tr.msg_memoflow_migration_accept),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.rejectProposal,
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(tr.msg_memoflow_migration_reject),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (state.phase == MemoFlowMigrationReceiverPhase.receiving &&
              state.latestStatus != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.latestStatus!.message ?? '',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _resolveProgress(proposal, state.latestStatus),
                    ),
                    if ((state.latestStatus?.receivedBytes ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr.msg_memoflow_migration_received_bytes(
                          size: _formatBytes(
                            state.latestStatus!.receivedBytes!,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (state.result != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.msg_memoflow_migration_completed,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(state.statusMessage ?? ''),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MemoFlowMigrationResultScreen(
                              result: state.result!,
                              title: tr.msg_memoflow_migration_result,
                            ),
                          ),
                        );
                      },
                      child: Text(tr.msg_memoflow_migration_view_result),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if ((state.errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(state.errorMessage!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            tr.msg_memoflow_migration_foreground_notice,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
      bottomNavigationBar:
          state.phase == MemoFlowMigrationReceiverPhase.waitingProposal
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton(
                onPressed: controller.stopSession,
                child: Text(tr.msg_cancel),
              ),
            )
          : null,
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
