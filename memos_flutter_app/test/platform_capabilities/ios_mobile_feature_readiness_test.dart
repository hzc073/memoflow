import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/platform_capabilities/ios_mobile_feature_readiness.dart';

void main() {
  test('inventory covers every required iOS mobile feature id', () {
    expect(
      iosMobileFeatureReadinessInventory.toSet(),
      equals(IosMobileFeatureId.values.toSet()),
    );
  });

  test('readiness status set remains fixed', () {
    expect(
      PlatformFeatureReadinessStatus.values.map((status) => status.name),
      <String>[
        'available',
        'disabledWithReason',
        'hidden',
        'manualFallback',
        'requiresNativeImplementation',
      ],
    );
  });

  test('readiness status helpers cover every status', () {
    final expectations = <PlatformFeatureReadinessStatus, bool>{
      PlatformFeatureReadinessStatus.available: true,
      PlatformFeatureReadinessStatus.disabledWithReason: false,
      PlatformFeatureReadinessStatus.hidden: false,
      PlatformFeatureReadinessStatus.manualFallback: true,
      PlatformFeatureReadinessStatus.requiresNativeImplementation: false,
    };

    for (final entry in expectations.entries) {
      final readiness = PlatformFeatureReadiness(
        featureId: IosMobileFeatureId.homeWidgets,
        status: entry.key,
        reasonCode: IosMobileFeatureReadinessReason.available,
      );

      expect(readiness.canRun, entry.value, reason: entry.key.name);
    }
  });

  test('iOS mobile readiness defaults to executable core feature states', () {
    final inventory = resolveIosMobileFeatureReadinessInventory(
      inputs: IosMobileFeatureReadinessInputs.forPlatform(
        platform: TargetPlatform.iOS,
        isWeb: false,
      ),
    );

    expect(
      inventory[IosMobileFeatureId.homeWidgets]?.status,
      PlatformFeatureReadinessStatus.available,
    );
    expect(
      inventory[IosMobileFeatureId.thirdPartyShareIntake]?.status,
      PlatformFeatureReadinessStatus.available,
    );
    expect(
      inventory[IosMobileFeatureId.memoReminders]?.status,
      PlatformFeatureReadinessStatus.available,
    );
    expect(
      inventory[IosMobileFeatureId.reminderRingtone]?.status,
      PlatformFeatureReadinessStatus.manualFallback,
    );
    expect(
      inventory[IosMobileFeatureId.thirdPartyShareVideoCompression]?.status,
      PlatformFeatureReadinessStatus.available,
    );
  });

  test('iOS mobile unavailable native requirements are explicit', () {
    final inventory = resolveIosMobileFeatureReadinessInventory(
      inputs: const IosMobileFeatureReadinessInputs(
        isIosMobile: true,
        widgetKitAvailable: false,
        shareExtensionAvailable: false,
        localNotificationsAvailable: false,
        scannerAvailable: false,
        locationProviderAvailable: false,
        imageCompressionAvailable: false,
        shareVideoCompressionAvailable: false,
      ),
    );

    expect(
      inventory[IosMobileFeatureId.homeWidgets]?.status,
      PlatformFeatureReadinessStatus.requiresNativeImplementation,
    );
    expect(
      inventory[IosMobileFeatureId.thirdPartyShareIntake]?.status,
      PlatformFeatureReadinessStatus.requiresNativeImplementation,
    );
    expect(
      inventory[IosMobileFeatureId.memoReminders]?.status,
      PlatformFeatureReadinessStatus.requiresNativeImplementation,
    );
    expect(
      inventory[IosMobileFeatureId.qrScanner]?.status,
      PlatformFeatureReadinessStatus.disabledWithReason,
    );
    expect(
      inventory[IosMobileFeatureId.thirdPartyShareVideoCompression]?.status,
      PlatformFeatureReadinessStatus.disabledWithReason,
    );
    expect(
      inventory.values.where((readiness) => readiness.needsVisibleReason),
      isNotEmpty,
    );
  });

  test(
    'non iOS mobile platforms do not receive iOS-specific disabled states',
    () {
      final readiness = resolveIosMobileFeatureReadiness(
        featureId: IosMobileFeatureId.homeWidgets,
        inputs: IosMobileFeatureReadinessInputs.forPlatform(
          platform: TargetPlatform.android,
          isWeb: false,
          widgetKitAvailable: false,
        ),
      );

      expect(readiness.status, PlatformFeatureReadinessStatus.available);
      expect(
        readiness.reasonCode,
        IosMobileFeatureReadinessReason.notIosMobile,
      );
    },
  );
}
