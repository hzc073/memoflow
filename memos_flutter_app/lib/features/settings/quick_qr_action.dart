import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/migration/memoflow_migration_protocol.dart';
import '../../core/top_toast.dart';
import '../../i18n/strings.g.dart';
import 'memoflow_bridge_screen.dart';
import 'migration/memoflow_migration_sender_screen.dart';

enum QuickQrActionKind { bridgePairing, migrationSender }

class QuickQrActionTarget {
  const QuickQrActionTarget({required this.kind, required this.rawPayload});

  final QuickQrActionKind kind;
  final String rawPayload;
}

QuickQrActionTarget? classifyQuickQrPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (parseMemoFlowMigrationConnectUri(trimmed) != null) {
    return QuickQrActionTarget(
      kind: QuickQrActionKind.migrationSender,
      rawPayload: trimmed,
    );
  }
  if (MemoFlowBridgePairingPayload.tryParse(trimmed) != null) {
    return QuickQrActionTarget(
      kind: QuickQrActionKind.bridgePairing,
      rawPayload: trimmed,
    );
  }
  return null;
}

Future<void> startUniversalQuickQrAction({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (!supportsMemoFlowQrScannerOnCurrentPlatform()) {
    showMemoFlowQrUnsupportedNotice(context);
    return;
  }

  final tr = context.t.strings.legacy;
  final raw = await Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute<String>(
      builder: (_) => MemoFlowPairQrScanScreen(
        titleText: tr.msg_bridge_scan_title,
        hintText:
            '${tr.msg_memoflow_migration_scan_hint}\n${tr.msg_bridge_scan_hint}',
      ),
    ),
  );
  if (raw == null || raw.trim().isEmpty) return;
  if (!context.mounted) return;

  final target = classifyQuickQrPayload(raw);
  if (target == null) {
    showTopToast(context, tr.msg_bridge_qr_invalid);
    return;
  }

  switch (target.kind) {
    case QuickQrActionKind.bridgePairing:
      await pairMemoFlowBridgeFromQrRaw(
        context: context,
        ref: ref,
        raw: target.rawPayload,
      );
      return;
    case QuickQrActionKind.migrationSender:
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => MemoFlowMigrationSenderScreen(
            initialReceiverQrPayload: target.rawPayload,
          ),
        ),
      );
      return;
  }
}
