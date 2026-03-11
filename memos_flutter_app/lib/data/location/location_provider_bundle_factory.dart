import '../models/location_settings.dart';
import 'location_provider_bundle.dart';
import 'providers/amap_location_provider_adapter.dart';
import 'providers/baidu_location_provider_adapter.dart';
import 'providers/google_location_provider_adapter.dart';

class LocationProviderBundleFactory {
  const LocationProviderBundleFactory();

  LocationProviderBundle create(LocationSettings settings) {
    return switch (settings.provider) {
      LocationServiceProvider.amap => LocationProviderBundle(
        provider: settings.provider,
        adapter: AmapLocationProviderAdapter(),
        displayName: 'Amap',
        apiKey: settings.amapWebKey.trim(),
        securityKey: settings.amapSecurityKey.trim(),
      ),
      LocationServiceProvider.baidu => LocationProviderBundle(
        provider: settings.provider,
        adapter: BaiduLocationProviderAdapter(),
        displayName: 'Baidu Map',
        apiKey: settings.baiduWebKey.trim(),
      ),
      LocationServiceProvider.google => LocationProviderBundle(
        provider: settings.provider,
        adapter: GoogleLocationProviderAdapter(),
        displayName: 'Google Maps',
        apiKey: settings.googleApiKey.trim(),
      ),
    };
  }
}
