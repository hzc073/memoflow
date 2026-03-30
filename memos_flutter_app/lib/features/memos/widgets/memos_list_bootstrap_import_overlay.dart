import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../../i18n/strings.g.dart';

class MemosListBootstrapImportOverlay extends StatelessWidget {
  const MemosListBootstrapImportOverlay({
    super.key,
    required this.active,
    required this.importedCount,
    required this.totalCount,
    required this.startedAt,
    required this.formatDuration,
  });

  final bool active;
  final int importedCount;
  final int totalCount;
  final DateTime? startedAt;
  final String Function(Duration? value) formatDuration;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.62 : 0.58);
    final backdropColor =
        (isDark
                ? MemoFlowPalette.backgroundDark
                : MemoFlowPalette.backgroundLight)
            .withValues(alpha: isDark ? 0.94 : 0.96);
    final safeTotal = totalCount <= 0 ? importedCount : totalCount;
    final safeImported = importedCount.clamp(0, safeTotal).toInt();
    final progress = safeTotal > 0
        ? (safeImported / safeTotal).clamp(0.0, 1.0).toDouble()
        : null;
    final elapsed = startedAt == null
        ? null
        : DateTime.now().difference(startedAt!);
    final elapsedText = elapsed == null ? null : formatDuration(elapsed);

    return AbsorbPointer(
      child: Container(
        color: backdropColor,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor.withValues(alpha: 0.92)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: MemoFlowPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t.strings.legacy.msg_importing_memos,
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${context.t.strings.legacy.msg_imported_memos}: $safeImported / $safeTotal',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: MemoFlowPalette.primary,
                      backgroundColor: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.2 : 0.16,
                      ),
                    ),
                  ),
                ],
                if (elapsedText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${context.t.strings.legacy.msg_loading} $elapsedText',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
