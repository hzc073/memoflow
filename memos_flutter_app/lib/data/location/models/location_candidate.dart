import 'canonical_coordinate.dart';
import 'provider_place_ref.dart';

enum LocationCandidateSource {
  nearby,
  keyword,
  reverseGeocodeFallback,
  manualCenter,
}

class LocationCandidate {
  const LocationCandidate({
    required this.title,
    required this.coordinate,
    required this.source,
    this.subtitle = '',
    this.distanceMeters,
    this.placeRef,
  });

  final String title;
  final String subtitle;
  final CanonicalCoordinate coordinate;
  final double? distanceMeters;
  final ProviderPlaceRef? placeRef;
  final LocationCandidateSource source;

  String get displaySubtitle => subtitle.trim();
}
