import 'package:flutter/foundation.dart';

class ReaderPlatformCapabilities {
  const ReaderPlatformCapabilities({
    required this.canOverrideScreenBrightness,
    required this.canControlSystemBars,
    required this.canLockOrientation,
    required this.canHandleHardwareVolumePaging,
    required this.canUseMouseWheelPaging,
  });

  final bool canOverrideScreenBrightness;
  final bool canControlSystemBars;
  final bool canLockOrientation;
  final bool canHandleHardwareVolumePaging;
  final bool canUseMouseWheelPaging;

  factory ReaderPlatformCapabilities.current({
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    if (isWeb) {
      return const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: false,
        canControlSystemBars: false,
        canLockOrientation: false,
        canHandleHardwareVolumePaging: false,
        canUseMouseWheelPaging: true,
      );
    }
    return switch (effectivePlatform) {
      TargetPlatform.android => const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: true,
        canControlSystemBars: true,
        canLockOrientation: true,
        canHandleHardwareVolumePaging: true,
        canUseMouseWheelPaging: true,
      ),
      TargetPlatform.iOS => const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: true,
        canControlSystemBars: true,
        canLockOrientation: true,
        canHandleHardwareVolumePaging: false,
        canUseMouseWheelPaging: false,
      ),
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: false,
        canControlSystemBars: false,
        canLockOrientation: false,
        canHandleHardwareVolumePaging: false,
        canUseMouseWheelPaging: true,
      ),
      TargetPlatform.fuchsia => const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: false,
        canControlSystemBars: false,
        canLockOrientation: false,
        canHandleHardwareVolumePaging: false,
        canUseMouseWheelPaging: true,
      ),
    };
  }
}
