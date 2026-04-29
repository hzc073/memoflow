import 'package:flutter/material.dart';

import '../../../state/memos/memo_composer_state.dart';

class AttachmentProcessingOverlay extends StatelessWidget {
  const AttachmentProcessingOverlay({super.key, required this.status});

  final AttachmentProcessingStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == AttachmentProcessingStatus.ready) {
      return const SizedBox.shrink();
    }

    final isFailed = status == AttachmentProcessingStatus.failed;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: isFailed ? 0.52 : 0.38),
        ),
        child: Center(
          child: isFailed
              ? const Icon(Icons.error_outline, color: Colors.white, size: 22)
              : const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
