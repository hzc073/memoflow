import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

class PlatformDialogAction<T> {
  const PlatformDialogAction({
    required this.value,
    required this.label,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final bool isDefault;
  final bool isDestructive;
}

Future<T?> showPlatformDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
}) {
  final target = resolvePlatformTarget(context);
  if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    builder: builder,
  );
}

Future<T?> showPlatformAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  String? details,
  required List<PlatformDialogAction<T>> actions,
  bool barrierDismissible = true,
  String? barrierLabel,
}) {
  final target = resolvePlatformTarget(context);
  final isAppleMobile =
      target == PlatformTarget.iPhone || target == PlatformTarget.iPad;
  if (isAppleMobile) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: _PlatformAlertDialogContent(
          message: message,
          details: details,
          apple: true,
        ),
        actions: [
          for (final action in actions)
            CupertinoDialogAction(
              isDefaultAction: action.isDefault,
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.of(dialogContext).pop(action.value),
              child: Text(action.label),
            ),
        ],
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: _PlatformAlertDialogContent(
        message: message,
        details: details,
        apple: false,
      ),
      actions: [
        for (final action in actions)
          action.isDefault
              ? FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(action.value),
                  style: action.isDestructive
                      ? FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.error,
                          foregroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.onError,
                        )
                      : null,
                  child: Text(action.label),
                )
              : TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(action.value),
                  style: action.isDestructive
                      ? TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.error,
                        )
                      : null,
                  child: Text(action.label),
                ),
      ],
    ),
  );
}

class _PlatformAlertDialogContent extends StatelessWidget {
  const _PlatformAlertDialogContent({
    required this.message,
    required this.details,
    required this.apple,
  });

  final String? message;
  final String? details;
  final bool apple;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message?.trim();
    final resolvedDetails = details?.trim();
    final hasMessage = resolvedMessage != null && resolvedMessage.isNotEmpty;
    final hasDetails = resolvedDetails != null && resolvedDetails.isNotEmpty;
    if (!hasMessage && !hasDetails) {
      return const SizedBox.shrink();
    }
    if (hasMessage && !hasDetails) {
      return Text(resolvedMessage);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMessage)
          Align(
            alignment: apple
                ? AlignmentDirectional.center
                : AlignmentDirectional.centerStart,
            child: Text(
              resolvedMessage,
              textAlign: apple ? TextAlign.center : TextAlign.start,
            ),
          ),
        if (hasMessage && hasDetails) const SizedBox(height: 12),
        if (hasDetails)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              resolvedDetails,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
      ],
    );
  }
}
