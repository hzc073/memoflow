import '../models/location_settings.dart';
import 'coordinate_transform.dart';
import 'models/canonical_coordinate.dart';
import 'models/location_candidate.dart';

String readString(dynamic value) {
  if (value is String) return value.trim();
  return value?.toString().trim() ?? '';
}

double? readDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

List<LocationCandidate> sortAndLimitCandidates(
  List<LocationCandidate> candidates,
  CanonicalCoordinate center, {
  int limit = 10,
}) {
  final copy = List<LocationCandidate>.from(candidates);
  copy.sort((a, b) {
    final distanceA = a.distanceMeters ?? distanceBetween(a.coordinate, center);
    final distanceB = b.distanceMeters ?? distanceBetween(b.coordinate, center);
    return distanceA.compareTo(distanceB);
  });
  if (copy.length <= limit) return copy;
  return copy.take(limit).toList(growable: false);
}

String joinDistinctParts(Iterable<String> parts, {String separator = '\u2022'}) {
  final normalized = <String>[];
  for (final part in parts) {
    final value = part.trim();
    if (value.isEmpty || normalized.contains(value)) continue;
    normalized.add(value);
  }
  return normalized.join(separator);
}

String formatLocationPrecisionSummary({
  required LocationPrecision precision,
  required String province,
  required String city,
  required String district,
  required String street,
  String fallback = '',
}) {
  final provinceValue = province.trim();
  final cityValue = city.trim();
  final districtValue = district.trim();
  final streetValue = street.trim();
  final fallbackValue = fallback.trim();

  final provinceCity = joinDistinctParts([provinceValue, cityValue]);
  final cityContext = cityValue.isNotEmpty ? cityValue : provinceValue;
  final districtContext = districtValue.isNotEmpty ? districtValue : cityContext;
  final cityDistrict = joinDistinctParts([cityContext, districtValue]);
  final districtStreet = joinDistinctParts([districtContext, streetValue]);

  return switch (precision) {
    LocationPrecision.province => _firstNonEmpty([
      provinceValue,
      cityValue,
      districtValue,
      streetValue,
      fallbackValue,
    ]),
    LocationPrecision.city => _firstNonEmpty([
      provinceCity,
      provinceValue,
      cityValue,
      districtValue,
      streetValue,
      fallbackValue,
    ]),
    LocationPrecision.district => _firstNonEmpty([
      cityDistrict,
      provinceCity,
      districtValue,
      cityContext,
      streetValue,
      fallbackValue,
    ]),
    LocationPrecision.street => _firstNonEmpty([
      districtStreet,
      cityDistrict,
      provinceCity,
      streetValue,
      districtValue,
      cityContext,
      fallbackValue,
    ]),
  };
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) return normalized;
  }
  return '';
}

