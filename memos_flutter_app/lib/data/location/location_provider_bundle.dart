import '../models/location_settings.dart';
import 'location_provider_adapter.dart';

class LocationProviderBundle {
  const LocationProviderBundle({
    required this.provider,
    required this.adapter,
    required this.displayName,
    required this.apiKey,
    this.securityKey = '',
  });

  final LocationServiceProvider provider;
  final LocationProviderAdapter adapter;
  final String displayName;
  final String apiKey;
  final String securityKey;
}
