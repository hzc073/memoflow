import 'package:flutter/widgets.dart';

import '../../data/location/location_provider_requirements_validator.dart';
import '../../i18n/strings.g.dart';

String localizeLocationProviderRequirement(
  BuildContext context,
  LocationProviderRequirementsResult result,
) {
  return switch (result.failure) {
    LocationProviderRequirementsFailure.disabled =>
      context.t.strings.legacy.msg_location_disabled_enable_settings_first,
    LocationProviderRequirementsFailure.missingAmapKeys =>
      context.t.strings.locationPicker.providerMissingAmapKeys,
    LocationProviderRequirementsFailure.missingBaiduKey =>
      context.t.strings.locationPicker.providerMissingBaiduKey,
    LocationProviderRequirementsFailure.missingGoogleKey =>
      context.t.strings.locationPicker.providerMissingGoogleKey,
    LocationProviderRequirementsFailure.unsupportedPlatform =>
      context.t.strings.locationPicker.providerUnsupportedPlatform,
    null => context.t.strings.locationPicker.providerNotReady,
  };
}

String localizeLocationPickerError(BuildContext context, String? message) {
  final normalized = (message ?? '').trim();
  return switch (normalized) {
    '' => '',
    'service_disabled' =>
      context.t.strings.legacy.msg_location_services_disabled,
    'permission_denied' =>
      context.t.strings.legacy.msg_location_permission_denied,
    'permission_denied_forever' =>
      context.t.strings.legacy.msg_location_permission_denied_permanently,
    'timeout' => context.t.strings.legacy.msg_location_timed_try,
    'map_initialize_failed' || 'Failed to initialize map.' =>
      context.t.strings.locationPicker.mapInitializeFailed,
    _ => normalized,
  };
}
