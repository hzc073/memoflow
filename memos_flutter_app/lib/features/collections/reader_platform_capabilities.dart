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
    if (isWeb) {
      return const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: false,
        canControlSystemBars: false,
        canLockOrientation: false,
        canHandleHardwareVolumePaging: false,
        canUseMouseWheelPaging: true,
      );
    }
    if ((platform ?? defaultTargetPlatform) == TargetPlatform.android) {
      return const ReaderPlatformCapabilities(
        canOverrideScreenBrightness: true,
        canControlSystemBars: true,
        canLockOrientation: true,
        canHandleHardwareVolumePaging: true,
        canUseMouseWheelPaging: true,
      );
    }
    return const ReaderPlatformCapabilities(
      canOverrideScreenBrightness: false,
      canControlSystemBars: false,
      canLockOrientation: false,
      canHandleHardwareVolumePaging: false,
      canUseMouseWheelPaging: true,
    );
  }
}
