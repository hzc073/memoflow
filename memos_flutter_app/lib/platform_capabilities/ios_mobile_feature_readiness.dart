import 'package:flutter/foundation.dart';

enum IosMobileFeatureId {
  homeWidgets,
  locationPicker,
  memoReminders,
  reminderRingtone,
  thirdPartyShareIntake,
  thirdPartyShareVideoCompression,
  qrScanner,
  imageCompression,
}

enum PlatformFeatureReadinessStatus {
  available,
  disabledWithReason,
  hidden,
  manualFallback,
  requiresNativeImplementation,
}

enum IosMobileFeatureReadinessReason {
  available,
  notIosMobile,
  widgetKitUnavailable,
  shareExtensionUnavailable,
  localNotificationsUnavailable,
  scannerUnavailable,
  locationProviderUnavailable,
  imageCompressionUnavailable,
  shareVideoCompressionUnavailable,
  systemNotificationSoundOnly,
}

@immutable
class PlatformFeatureReadiness {
  const PlatformFeatureReadiness({
    required this.featureId,
    required this.status,
    required this.reasonCode,
    this.nativeRequirement,
    this.manualFallbackDescription,
  });

  final IosMobileFeatureId featureId;
  final PlatformFeatureReadinessStatus status;
  final IosMobileFeatureReadinessReason reasonCode;
  final String? nativeRequirement;
  final String? manualFallbackDescription;

  bool get canRun =>
      status == PlatformFeatureReadinessStatus.available ||
      status == PlatformFeatureReadinessStatus.manualFallback;

  bool get needsVisibleReason =>
      status == PlatformFeatureReadinessStatus.disabledWithReason ||
      status == PlatformFeatureReadinessStatus.manualFallback ||
      status == PlatformFeatureReadinessStatus.requiresNativeImplementation;
}

@immutable
class IosMobileFeatureReadinessInputs {
  const IosMobileFeatureReadinessInputs({
    required this.isIosMobile,
    this.widgetKitAvailable = true,
    this.shareExtensionAvailable = true,
    this.localNotificationsAvailable = true,
    this.scannerAvailable = true,
    this.locationProviderAvailable = true,
    this.imageCompressionAvailable = true,
    this.shareVideoCompressionAvailable = true,
  });

  factory IosMobileFeatureReadinessInputs.forPlatform({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
    bool widgetKitAvailable = true,
    bool shareExtensionAvailable = true,
    bool localNotificationsAvailable = true,
    bool scannerAvailable = true,
    bool locationProviderAvailable = true,
    bool imageCompressionAvailable = true,
    bool shareVideoCompressionAvailable = true,
  }) {
    final resolved = platform ?? defaultTargetPlatform;
    return IosMobileFeatureReadinessInputs(
      isIosMobile: !isWeb && resolved == TargetPlatform.iOS,
      widgetKitAvailable: widgetKitAvailable,
      shareExtensionAvailable: shareExtensionAvailable,
      localNotificationsAvailable: localNotificationsAvailable,
      scannerAvailable: scannerAvailable,
      locationProviderAvailable: locationProviderAvailable,
      imageCompressionAvailable: imageCompressionAvailable,
      shareVideoCompressionAvailable: shareVideoCompressionAvailable,
    );
  }

  final bool isIosMobile;
  final bool widgetKitAvailable;
  final bool shareExtensionAvailable;
  final bool localNotificationsAvailable;
  final bool scannerAvailable;
  final bool locationProviderAvailable;
  final bool imageCompressionAvailable;
  final bool shareVideoCompressionAvailable;
}

const List<IosMobileFeatureId> iosMobileFeatureReadinessInventory =
    <IosMobileFeatureId>[
      IosMobileFeatureId.homeWidgets,
      IosMobileFeatureId.locationPicker,
      IosMobileFeatureId.memoReminders,
      IosMobileFeatureId.reminderRingtone,
      IosMobileFeatureId.thirdPartyShareIntake,
      IosMobileFeatureId.thirdPartyShareVideoCompression,
      IosMobileFeatureId.qrScanner,
      IosMobileFeatureId.imageCompression,
    ];

PlatformFeatureReadiness resolveIosMobileFeatureReadiness({
  required IosMobileFeatureId featureId,
  IosMobileFeatureReadinessInputs? inputs,
}) {
  final resolvedInputs =
      inputs ?? IosMobileFeatureReadinessInputs.forPlatform();
  if (!resolvedInputs.isIosMobile) {
    return PlatformFeatureReadiness(
      featureId: featureId,
      status: PlatformFeatureReadinessStatus.available,
      reasonCode: IosMobileFeatureReadinessReason.notIosMobile,
    );
  }

  return switch (featureId) {
    IosMobileFeatureId.homeWidgets =>
      resolvedInputs.widgetKitAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.homeWidgets,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
              nativeRequirement: 'WidgetKit target with shared widget data',
              manualFallbackDescription:
                  'Add MemoFlow widgets from the iOS widget gallery.',
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.homeWidgets,
              status:
                  PlatformFeatureReadinessStatus.requiresNativeImplementation,
              reasonCode: IosMobileFeatureReadinessReason.widgetKitUnavailable,
              nativeRequirement:
                  'WidgetKit target with timeline reload support',
            ),
    IosMobileFeatureId.locationPicker =>
      resolvedInputs.locationProviderAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.locationPicker,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.locationPicker,
              status: PlatformFeatureReadinessStatus.disabledWithReason,
              reasonCode:
                  IosMobileFeatureReadinessReason.locationProviderUnavailable,
            ),
    IosMobileFeatureId.memoReminders =>
      resolvedInputs.localNotificationsAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.memoReminders,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
              nativeRequirement: 'iOS local notification scheduling',
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.memoReminders,
              status:
                  PlatformFeatureReadinessStatus.requiresNativeImplementation,
              reasonCode:
                  IosMobileFeatureReadinessReason.localNotificationsUnavailable,
              nativeRequirement: 'iOS local notification scheduling',
            ),
    IosMobileFeatureId.reminderRingtone => const PlatformFeatureReadiness(
      featureId: IosMobileFeatureId.reminderRingtone,
      status: PlatformFeatureReadinessStatus.manualFallback,
      reasonCode: IosMobileFeatureReadinessReason.systemNotificationSoundOnly,
      manualFallbackDescription:
          'Use the iOS system notification sound; Android ringtone picker is hidden.',
    ),
    IosMobileFeatureId.thirdPartyShareIntake =>
      resolvedInputs.shareExtensionAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.thirdPartyShareIntake,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
              nativeRequirement: 'iOS Share Extension or equivalent handoff',
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.thirdPartyShareIntake,
              status:
                  PlatformFeatureReadinessStatus.requiresNativeImplementation,
              reasonCode:
                  IosMobileFeatureReadinessReason.shareExtensionUnavailable,
              nativeRequirement: 'iOS Share Extension or equivalent handoff',
            ),
    IosMobileFeatureId.thirdPartyShareVideoCompression =>
      resolvedInputs.shareVideoCompressionAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.thirdPartyShareVideoCompression,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.thirdPartyShareVideoCompression,
              status: PlatformFeatureReadinessStatus.disabledWithReason,
              reasonCode: IosMobileFeatureReadinessReason
                  .shareVideoCompressionUnavailable,
            ),
    IosMobileFeatureId.qrScanner =>
      resolvedInputs.scannerAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.qrScanner,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.qrScanner,
              status: PlatformFeatureReadinessStatus.disabledWithReason,
              reasonCode: IosMobileFeatureReadinessReason.scannerUnavailable,
              manualFallbackDescription:
                  'Use manual pairing or text input when scanner is unavailable.',
            ),
    IosMobileFeatureId.imageCompression =>
      resolvedInputs.imageCompressionAvailable
          ? const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.imageCompression,
              status: PlatformFeatureReadinessStatus.available,
              reasonCode: IosMobileFeatureReadinessReason.available,
            )
          : const PlatformFeatureReadiness(
              featureId: IosMobileFeatureId.imageCompression,
              status: PlatformFeatureReadinessStatus.disabledWithReason,
              reasonCode:
                  IosMobileFeatureReadinessReason.imageCompressionUnavailable,
            ),
  };
}

Map<IosMobileFeatureId, PlatformFeatureReadiness>
resolveIosMobileFeatureReadinessInventory({
  IosMobileFeatureReadinessInputs? inputs,
}) {
  return <IosMobileFeatureId, PlatformFeatureReadiness>{
    for (final featureId in iosMobileFeatureReadinessInventory)
      featureId: resolveIosMobileFeatureReadiness(
        featureId: featureId,
        inputs: inputs,
      ),
  };
}
