import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';

class AudioRow extends StatelessWidget {
  const AudioRow({
    super.key,
    required this.durationText,
    required this.isDark,
    required this.playing,
    required this.loading,
    required this.position,
    required this.duration,
    required this.durationFallback,
    this.onSeek,
    this.onTap,
  });

  final String durationText;
  final bool isDark;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration? duration;
  final Duration? durationFallback;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight.withValues(alpha: 0.5);
    final bg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final text = (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
        .withValues(alpha: isDark ? 0.4 : 0.6);

    final icon = !playing && loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(MemoFlowPalette.primary),
            ),
          )
        : Icon(playing ? Icons.pause : Icons.play_arrow, size: 20);
    final effectiveDuration = duration ?? durationFallback;
    final durationMs = effectiveDuration?.inMilliseconds ?? 0;
    final positionMs = position.inMilliseconds;
    final progress = durationMs > 0 ? positionMs / durationMs : 0.0;
    final progressClamped = progress.clamp(0.0, 1.0).toDouble();

    Widget progressBar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progressClamped,
        minHeight: 4,
        backgroundColor: (isDark ? Colors.white : Colors.black)
            .withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation(MemoFlowPalette.primary),
      ),
    );

    if (onSeek != null && durationMs > 0) {
      final baseProgressBar = progressBar;
      progressBar = LayoutBuilder(
        builder: (context, constraints) {
          void seekTo(double dx) {
            final width = constraints.maxWidth;
            if (width <= 0) return;
            final ratio = (dx / width).clamp(0.0, 1.0);
            final targetMs = (durationMs * ratio).round();
            onSeek!(Duration(milliseconds: targetMs));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seekTo(details.localPosition.dx),
            onPanUpdate: (details) => seekTo(details.localPosition.dx),
            child: baseProgressBar,
          );
        },
      );
    }

    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? Colors.transparent : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ],
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 12),
          Expanded(child: progressBar),
          const SizedBox(width: 10),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
