import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/strings.g.dart';
import '../memoflow_bridge_screen.dart';
import '../../../state/migration/memoflow_migration_providers.dart';
import '../../../state/migration/memoflow_migration_state.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(tr.msg_memoflow_migration_send_method)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr.msg_memoflow_migration_send_method_desc,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (packageResult != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.msg_memoflow_migration_package_ready,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr.msg_memoflow_migration_package_summary(
                        memoCount: packageResult.manifest.memoCount,
                        attachmentCount: packageResult.manifest.attachmentCount,
                        size: _formatBytes(packageResult.manifest.totalBytes),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final raw = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute<String>(
                                    builder: (_) => MemoFlowPairQrScanScreen(
                                      titleText:
                                          tr.msg_memoflow_migration_scan_title,
                                      hintText:
                                          tr.msg_memoflow_migration_scan_hint,
                                    ),
                                  ),
                                );
                            if (raw != null && context.mounted) {
                              await controller.connectFromQrPayload(raw);
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(tr.msg_memoflow_migration_scan_receiver),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final request =
                                await showDialog<_ManualReceiverConnectRequest>(
                                  context: context,
                                  builder: (_) =>
                                      const _ManualReceiverConnectDialog(),
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
                          label: Text(tr.msg_manual),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (packageResult == null &&
              state.phase != MemoFlowMigrationSenderPhase.buildingPackage) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(tr.msg_memoflow_migration_prepare_send_first),
              ),
            ),
          ],
          if (state.phase == MemoFlowMigrationSenderPhase.uploading ||
              state.phase == MemoFlowMigrationSenderPhase.waitingForReceiver ||
              state.phase == MemoFlowMigrationSenderPhase.buildingPackage) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.statusMessage ?? '',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          state.phase == MemoFlowMigrationSenderPhase.uploading
                          ? state.uploadProgress
                          : null,
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
          const SizedBox(height: 16),
          Text(
            tr.msg_memoflow_migration_foreground_notice,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
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
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _pairCodeController = TextEditingController();
  final _hostFocusNode = FocusNode();
  final _portFocusNode = FocusNode();
  final _pairCodeFocusNode = FocusNode();

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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final parsed = _parseHostAndPort(_hostController.text);
    final host = parsed.host.trim();
    final portText = _portController.text.trim();
    final port = int.parse(
      portText.isNotEmpty ? portText : parsed.port!.toString(),
    );
    Navigator.of(context).pop(
      _ManualReceiverConnectRequest(
        host: host,
        port: port,
        pairingCode: _pairCodeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.strings;
    final tr = strings.legacy;

    return AlertDialog(
      title: Text(tr.msg_manual),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _hostController,
                focusNode: _hostFocusNode,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: strings.aiProxy.host,
                  hintText: '192.168.1.10:4224',
                ),
                onFieldSubmitted: (_) {
                  final parsed = _parseHostAndPort(_hostController.text);
                  if (parsed.port != null &&
                      _portController.text.trim().isEmpty) {
                    _pairCodeFocusNode.requestFocus();
                    return;
                  }
                  _portFocusNode.requestFocus();
                },
                validator: (value) {
                  final parsed = _parseHostAndPort(value ?? '');
                  if (parsed.host.isEmpty) {
                    return tr.msg_bridge_input_host_required;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portController,
                focusNode: _portFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: strings.aiProxy.port,
                  hintText: '4224',
                ),
                onFieldSubmitted: (_) => _pairCodeFocusNode.requestFocus(),
                validator: (value) {
                  final parsed = _parseHostAndPort(_hostController.text);
                  final portText = (value ?? '').trim();
                  final effectivePort = int.tryParse(
                    portText.isNotEmpty
                        ? portText
                        : parsed.port?.toString() ?? '',
                  );
                  if (effectivePort == null ||
                      effectivePort <= 0 ||
                      effectivePort > 65535) {
                    return tr.msg_bridge_input_port_invalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pairCodeController,
                focusNode: _pairCodeFocusNode,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: tr.msg_bridge_pair_code_label,
                  hintText: '123456',
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return tr.msg_bridge_input_pair_code_required;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr.msg_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(tr.msg_bridge_action_confirm_pair),
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
