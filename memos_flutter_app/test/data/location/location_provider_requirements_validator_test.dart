import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/location/location_provider_requirements_validator.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';

void main() {
  const enabledGoogleSettings = LocationSettings(
    enabled: true,
    provider: LocationServiceProvider.google,
    amapWebKey: '',
    amapSecurityKey: '',
    baiduWebKey: '',
    googleApiKey: 'google-key',
    precision: LocationPrecision.city,
  );

  test('returns disabled result when location feature is off', () {
    final validator = LocationProviderRequirementsValidator(
      isSupportedPlatform: () => true,
    );

    final result = validator.validate(LocationSettings.defaults);

    expect(result.isReady, isFalse);
    expect(result.failure, LocationProviderRequirementsFailure.disabled);
  });

  test('requires provider-specific API keys', () {
    final validator = LocationProviderRequirementsValidator(
      isSupportedPlatform: () => true,
    );

    final result = validator.validate(
      enabledGoogleSettings.copyWith(googleApiKey: '  '),
    );

    expect(result.isReady, isFalse);
    expect(
      result.failure,
      LocationProviderRequirementsFailure.missingGoogleKey,
    );
  });

  test('fails on unsupported platforms', () {
    final validator = LocationProviderRequirementsValidator(
      isSupportedPlatform: () => false,
    );

    final result = validator.validate(enabledGoogleSettings);

    expect(result.isReady, isFalse);
    expect(
      result.failure,
      LocationProviderRequirementsFailure.unsupportedPlatform,
    );
  });

  test('passes when settings and platform are ready', () {
    final validator = LocationProviderRequirementsValidator(
      isSupportedPlatform: () => true,
    );

    final result = validator.validate(enabledGoogleSettings);

    expect(result.isReady, isTrue);
    expect(result.failure, isNull);
  });
}
