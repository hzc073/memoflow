import 'dart:io';

import '../models/location_settings.dart';

enum LocationProviderRequirementsFailure {
  disabled,
  missingAmapKeys,
  missingBaiduKey,
  missingGoogleKey,
  unsupportedPlatform,
}

class LocationProviderRequirementsResult {
  const LocationProviderRequirementsResult({
    required this.isReady,
    this.failure,
  });

  final bool isReady;
  final LocationProviderRequirementsFailure? failure;
}

class LocationProviderRequirementsValidator {
  const LocationProviderRequirementsValidator({
    bool Function()? isSupportedPlatform,
  }) : _isSupportedPlatform = isSupportedPlatform;

  final bool Function()? _isSupportedPlatform;

  LocationProviderRequirementsResult validate(LocationSettings settings) {
    if (!settings.enabled) {
      return const LocationProviderRequirementsResult(
        isReady: false,
        failure: LocationProviderRequirementsFailure.disabled,
      );
    }

    final hasKey = switch (settings.provider) {
      LocationServiceProvider.amap =>
        settings.amapWebKey.trim().isNotEmpty &&
            settings.amapSecurityKey.trim().isNotEmpty,
      LocationServiceProvider.baidu => settings.baiduWebKey.trim().isNotEmpty,
      LocationServiceProvider.google => settings.googleApiKey.trim().isNotEmpty,
    };

    if (!hasKey) {
      return LocationProviderRequirementsResult(
        isReady: false,
        failure: switch (settings.provider) {
          LocationServiceProvider.amap =>
            LocationProviderRequirementsFailure.missingAmapKeys,
          LocationServiceProvider.baidu =>
            LocationProviderRequirementsFailure.missingBaiduKey,
          LocationServiceProvider.google =>
            LocationProviderRequirementsFailure.missingGoogleKey,
        },
      );
    }

    final isSupportedPlatform =
        _isSupportedPlatform?.call() ??
        (Platform.isAndroid || Platform.isWindows);
    if (!isSupportedPlatform) {
      return const LocationProviderRequirementsResult(
        isReady: false,
        failure: LocationProviderRequirementsFailure.unsupportedPlatform,
      );
    }

    return const LocationProviderRequirementsResult(isReady: true);
  }
}
