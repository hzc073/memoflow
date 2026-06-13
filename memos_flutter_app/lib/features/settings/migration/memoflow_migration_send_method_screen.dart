import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_localization.dart';
import '../../../i18n/strings.g.dart';
import '../../../platform/platform_route.dart';
import '../../../platform/widgets/platform_dialog.dart';
import '../../../platform/widgets/platform_primary_action.dart';
import '../../../state/migration/memoflow_migration_providers.dart';
import '../../../state/migration/memoflow_migration_state.dart';
import '../memoflow_bridge_screen.dart';
import '../settings_ui.dart';
import 'memoflow_migration_result_screen.dart';

class MemoFlowMigrationSendMethodScreen extends ConsumerStatefulWidget {
  const MemoFlowMigrationSendMethodScreen({
    super.key,
    this.initialReceiverQrPayload,
  });

  final String? initialReceiverQrPayload;

  @override
  ConsumerState<MemoFlowMigrationSendMethodScreen> createState() =>
      _MemoFlowMigrationSendMethodScreenState();
}

class _MemoFlowMigrationSendMethodScreenState
    extends ConsumerState<MemoFlowMigrationSendMethodScreen> {
  bool _startedAutoConnect = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartAutoConnect();
    });
  }

  Future<void> _maybeStartAutoConnect() async {
    if (_startedAutoConnect) return;
    final raw = widget.initialReceiverQrPayload?.trim() ?? '';
    if (raw.isEmpty) return;
    final state = ref.read(memoFlowMigrationSenderControllerProvider);
    if (state.packageResult == null) return;
    _startedAutoConnect = true;
    await ref
        .read(memoFlowMigrationSenderControllerProvider.notifier)
        .connectFromQrPayload(raw);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoFlowMigrationSenderControllerProvider);
    final controller = ref.read(
      memoFlowMigrationSenderControllerProvider.notifier,
    );
    final tr = context.t.strings.legacy;
    final packageResult = state.packageResult;

    return SettingsPage(
      title: Text(tr.msg_memoflow_migration_send_method),
      children: [
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: tr.msg_memoflow_migration_send_method_desc,
            ),
          ],
        ),
        if (packageResult != null) ...[
          const SizedBox(height: 14),
          SettingsSection(
            header: Text(tr.msg_memoflow_migration_package_ready),
            children: [
              SettingsInfoRow(
                description: tr.msg_memoflow_migration_package_summary(
                  memoCount: packageResult.manifest.memoCount,
                  attachmentCount: packageResult.manifest.attachmentCount,
                  size: _formatBytes(packageResult.manifest.totalBytes),
                ),
              ),
              SettingsInfoRow(
                description: context.tr(
                  zh: '草稿 ${packageResult.manifest.draftCount} 条，草稿附件 ${packageResult.manifest.draftAttachmentCount} 个',
                  en: 'Drafts ${packageResult.manifest.draftCount}, draft attachments ${packageResult.manifest.draftAttachmentCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: () async {
                final raw = await Navigator.of(context).push<String>(
                  buildPlatformPageRoute<String>(
                    context: context,
                    builder: (_) => MemoFlowPairQrScanScreen(
                      titleText: tr.msg_memoflow_migration_scan_title,
                      hintText: tr.msg_memoflow_migration_scan_hint,
                    ),
                  ),
                );
                if (raw != null && context.mounted) {
                  await controller.connectFromQrPayload(raw);
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              variant: PlatformPrimaryActionVariant.outlined,
              label: Text(tr.msg_memoflow_migration_scan_receiver),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: () async {
                final request =
                    await showPlatformDialog<_ManualReceiverConnectRequest>(
                      context: context,
                      builder: (_) => const _ManualReceiverConnectDialog(),
                    );
                if (request != null && context.mounted) {
                  await controller.connectManually(
                    host: request.host,
                    port: request.port,
                    pairingCode: request.pairingCode,
                  );
                }
              },
              icon: const Icon(Icons.keyboard_alt_outlined),
              variant: PlatformPrimaryActionVariant.outlined,
              label: Text(tr.msg_manual),
            ),
          ),
        ],
        if (packageResult == null &&
            state.phase != MemoFlowMigrationSenderPhase.buildingPackage) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [
              SettingsInfoRow(
                description: tr.msg_memoflow_migration_prepare_send_first,
              ),
            ],
          ),
        ],
        if (state.phase == MemoFlowMigrationSenderPhase.uploading ||
            state.phase == MemoFlowMigrationSenderPhase.waitingForReceiver ||
            state.phase == MemoFlowMigrationSenderPhase.buildingPackage) ...[
          const SizedBox(height: 14),
          SettingsSection(
            children: [
              SettingsProgressRow(
                label: state.statusMessage?.trim().isNotEmpty == true
                    ? state.statusMessage!.trim()
                    : tr.msg_memoflow_migration_send_method,
                value: state.phase == MemoFlowMigrationSenderPhase.uploading
                    ? state.uploadProgress
                    : null,
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _ManualReceiverConnectRequest {
  const _ManualReceiverConnectRequest({
    required this.host,
    required this.port,
    required this.pairingCode,
  });

  final String host;
  final int port;
  final String pairingCode;
}

class _ManualReceiverConnectDialog extends StatefulWidget {
  const _ManualReceiverConnectDialog();

  @override
  State<_ManualReceiverConnectDialog> createState() =>
      _ManualReceiverConnectDialogState();
}

class _ManualReceiverConnectDialogState
    extends State<_ManualReceiverConnectDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _pairCodeController = TextEditingController();
  final _hostFocusNode = FocusNode();
  final _portFocusNode = FocusNode();
  final _pairCodeFocusNode = FocusNode();
  String? _hostError;
  String? _portError;
  String? _pairCodeError;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _pairCodeController.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    _pairCodeFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final strings = context.t.strings;
    final tr = strings.legacy;
    final parsed = _parseHostAndPort(_hostController.text);
    final portText = _portController.text.trim();
    final effectivePort = int.tryParse(
      portText.isNotEmpty ? portText : parsed.port?.toString() ?? '',
    );
    final hostError = parsed.host.trim().isEmpty
        ? tr.msg_bridge_input_host_required
        : null;
    final portError =
        effectivePort == null || effectivePort <= 0 || effectivePort > 65535
        ? tr.msg_bridge_input_port_invalid
        : null;
    final pairCodeError = _pairCodeController.text.trim().isEmpty
        ? tr.msg_bridge_input_pair_code_required
        : null;
    setState(() {
      _hostError = hostError;
      _portError = portError;
      _pairCodeError = pairCodeError;
    });
    if (hostError != null || portError != null || pairCodeError != null) {
      return;
    }
    final host = parsed.host.trim();
    Navigator.of(context).pop(
      _ManualReceiverConnectRequest(
        host: host,
        port: effectivePort!,
        pairingCode: _pairCodeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.strings;
    final tr = strings.legacy;

    return SettingsFormDialog(
      title: Text(tr.msg_manual),
      actions: [
        SettingsDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          label: Text(tr.msg_cancel),
        ),
        SettingsDialogAction(
          onPressed: _submit,
          label: Text(tr.msg_bridge_action_confirm_pair),
          variant: PlatformPrimaryActionVariant.filled,
        ),
      ],
      children: [
        SettingsDialogTextField(
          label: strings.aiProxy.host,
          controller: _hostController,
          focusNode: _hostFocusNode,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          hint: '192.168.1.10:4224',
          errorText: _hostError,
          onChanged: (_) => setState(() => _hostError = null),
          onSubmitted: (_) {
            final parsed = _parseHostAndPort(_hostController.text);
            if (parsed.port != null && _portController.text.trim().isEmpty) {
              _pairCodeFocusNode.requestFocus();
              return;
            }
            _portFocusNode.requestFocus();
          },
        ),
        const SizedBox(height: 12),
        SettingsDialogTextField(
          label: strings.aiProxy.port,
          controller: _portController,
          focusNode: _portFocusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          hint: '4224',
          errorText: _portError,
          onChanged: (_) => setState(() => _portError = null),
          onSubmitted: (_) => _pairCodeFocusNode.requestFocus(),
        ),
        const SizedBox(height: 12),
        SettingsDialogTextField(
          label: tr.msg_bridge_pair_code_label,
          controller: _pairCodeController,
          focusNode: _pairCodeFocusNode,
          textInputAction: TextInputAction.done,
          hint: '123456',
          errorText: _pairCodeError,
          onChanged: (_) => setState(() => _pairCodeError = null),
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  _ParsedHostPort _parseHostAndPort(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _ParsedHostPort(host: '', port: null);
    }

    final uri = Uri.tryParse(
      trimmed.contains('://') ? trimmed : 'http://$trimmed',
    );
    if (uri != null && uri.host.trim().isNotEmpty) {
      return _ParsedHostPort(
        host: uri.host.trim(),
        port: uri.hasPort ? uri.port : null,
      );
    }

    return _ParsedHostPort(host: trimmed, port: null);
  }
}

class _ParsedHostPort {
  const _ParsedHostPort({required this.host, required this.port});

  final String host;
  final int? port;
}
