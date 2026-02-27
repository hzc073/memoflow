import 'package:flutter/material.dart';

import '../state/preferences_provider.dart';
import 'app_localization.dart';
import 'top_toast.dart';

enum SyncFeedbackChannel { snackbar, toast, skipped }

String buildSyncFeedbackMessage({
  required AppLanguage language,
  required bool succeeded,
}) {
  final effective = language == AppLanguage.system
      ? appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale)
      : language;
  if (succeeded) {
    return switch (effective) {
      AppLanguage.zhHans => '\u540c\u6b65\u5b8c\u6210',
      AppLanguage.zhHantTw => '\u540c\u6b65\u5b8c\u6210',
      AppLanguage.ja => '\u540c\u671f\u5b8c\u4e86',
      AppLanguage.de => 'Synchronisierung abgeschlossen',
      AppLanguage.en => 'Sync completed',
      AppLanguage.system => 'Sync completed',
    };
  }
  return switch (effective) {
    AppLanguage.zhHans => '\u540c\u6b65\u5931\u8d25',
    AppLanguage.zhHantTw => '\u540c\u6b65\u5931\u6557',
    AppLanguage.ja => '\u540c\u671f\u5931\u6557',
    AppLanguage.de => 'Synchronisierung fehlgeschlagen',
    AppLanguage.en => 'Sync failed',
    AppLanguage.system => 'Sync failed',
  };
}

String buildAutoSyncProgressMessage({required AppLanguage language}) {
  final effective = language == AppLanguage.system
      ? appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale)
      : language;
  return switch (effective) {
    AppLanguage.zhHans => '\u81ea\u52a8\u540c\u6b65\u4e2d...',
    AppLanguage.zhHantTw => '\u81ea\u52d5\u540c\u6b65\u4e2d...',
    AppLanguage.ja => '\u81ea\u52d5\u540c\u671f\u4e2d...',
    AppLanguage.de => 'Automatische Synchronisierung l\u00e4uft...',
    AppLanguage.en => 'Auto sync in progress...',
    AppLanguage.system => 'Auto sync in progress...',
  };
}

String buildAutoSyncFeedbackMessage({
  required AppLanguage language,
  required bool succeeded,
}) {
  final effective = language == AppLanguage.system
      ? appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale)
      : language;
  if (succeeded) {
    return switch (effective) {
      AppLanguage.zhHans => '\u81ea\u52a8\u540c\u6b65\u5b8c\u6210',
      AppLanguage.zhHantTw => '\u81ea\u52d5\u540c\u6b65\u5b8c\u6210',
      AppLanguage.ja => '\u81ea\u52d5\u540c\u671f\u5b8c\u4e86',
      AppLanguage.de => 'Automatische Synchronisierung abgeschlossen',
      AppLanguage.en => 'Auto sync completed',
      AppLanguage.system => 'Auto sync completed',
    };
  }
  return switch (effective) {
    AppLanguage.zhHans => '\u81ea\u52a8\u540c\u6b65\u5931\u8d25',
    AppLanguage.zhHantTw => '\u81ea\u52d5\u540c\u6b65\u5931\u6557',
    AppLanguage.ja => '\u81ea\u52d5\u540c\u671f\u5931\u6557',
    AppLanguage.de => 'Automatische Synchronisierung fehlgeschlagen',
    AppLanguage.en => 'Auto sync failed',
    AppLanguage.system => 'Auto sync failed',
  };
}

SyncFeedbackChannel showSyncFeedback({
  required BuildContext overlayContext,
  required AppLanguage language,
  required bool succeeded,
  String? message,
  BuildContext? messengerContext,
  Duration duration = const Duration(seconds: 3),
}) {
  final resolvedMessage =
      message ??
      buildSyncFeedbackMessage(language: language, succeeded: succeeded);
  // Keep sync feedback consistent with the app's capsule top toast style.
  // Some call sites may provide a context without an attached root Overlay,
  // so we fallback to the secondary context when possible.
  final hasOverlayOnPrimary =
      Overlay.maybeOf(overlayContext, rootOverlay: true) != null;
  final hasOverlayOnSecondary =
      messengerContext != null &&
      Overlay.maybeOf(messengerContext, rootOverlay: true) != null;
  final toastContext = hasOverlayOnPrimary
      ? overlayContext
      : (hasOverlayOnSecondary ? messengerContext : overlayContext);
  final shown = showTopToast(
    toastContext,
    resolvedMessage,
    duration: duration,
    topOffset: 96,
  );
  if (!shown &&
      messengerContext != null &&
      !identical(messengerContext, toastContext)) {
    final shownByFallback = showTopToast(
      messengerContext,
      resolvedMessage,
      duration: duration,
      topOffset: 96,
    );
    return shownByFallback
        ? SyncFeedbackChannel.toast
        : SyncFeedbackChannel.skipped;
  }
  return shown ? SyncFeedbackChannel.toast : SyncFeedbackChannel.skipped;
}
