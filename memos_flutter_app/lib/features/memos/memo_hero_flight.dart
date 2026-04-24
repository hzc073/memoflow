import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/local_memo.dart';

const double memoHeroFlightBorderRadius = 22;

Object memoHeroTagForMemo(LocalMemo memo) {
  final uid = memo.uid.trim();
  final fallback = memo.contentFingerprint.trim();
  final identity = uid.isNotEmpty ? uid : fallback;
  return 'memo:$identity';
}

HeroFlightShuttleBuilder memoHeroFlightShuttleBuilder({
  required bool isPinned,
}) {
  return (
    flightContext,
    animation,
    flightDirection,
    fromHeroContext,
    toHeroContext,
  ) {
    return Material(
      color: Colors.transparent,
      child: IgnorePointer(
        child: RepaintBoundary(child: MemoHeroFlightShell(isPinned: isPinned)),
      ),
    );
  };
}

class MemoHeroFlightShell extends StatelessWidget {
  const MemoHeroFlightShell({super.key, required this.isPinned});

  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final pinColor = MemoFlowPalette.primary;
    final pinBorderColor = pinColor.withValues(alpha: isDark ? 0.5 : 0.4);
    final pinTint = pinColor.withValues(alpha: isDark ? 0.18 : 0.08);
    final cardSurface = isPinned
        ? Color.alphaBlend(pinTint, cardColor)
        : cardColor;
    final cardBorderColor = isPinned ? pinBorderColor : borderColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(memoHeroFlightBorderRadius),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            blurRadius: isDark ? 20 : 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.03),
          ),
        ],
      ),
      child: const SizedBox.expand(),
    );
  }
}
