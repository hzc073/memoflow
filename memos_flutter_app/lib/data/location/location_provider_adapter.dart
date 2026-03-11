import '../models/location_settings.dart';
import 'models/canonical_coordinate.dart';
import 'models/location_candidate.dart';

abstract class LocationProviderAdapter {
  Future<String?> reverseGeocode({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
  });

  Future<List<LocationCandidate>> searchNearby({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  });

  Future<List<LocationCandidate>> searchByKeyword({
    required String query,
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  });

  CanonicalCoordinate fromProviderCoordinate(ProviderCoordinate coordinate);

  ProviderCoordinate toProviderCoordinate(CanonicalCoordinate coordinate);
}
