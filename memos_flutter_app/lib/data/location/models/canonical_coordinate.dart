enum ProviderCoordinateSystem { wgs84, gcj02, bd09 }

class CanonicalCoordinate {
  const CanonicalCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  CanonicalCoordinate copyWith({double? latitude, double? longitude}) {
    return CanonicalCoordinate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  bool operator ==(Object other) {
    return other is CanonicalCoordinate &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'CanonicalCoordinate(latitude: $latitude, longitude: $longitude)';
}

class ProviderCoordinate {
  const ProviderCoordinate({
    required this.latitude,
    required this.longitude,
    required this.system,
  });

  final double latitude;
  final double longitude;
  final ProviderCoordinateSystem system;

  @override
  bool operator ==(Object other) {
    return other is ProviderCoordinate &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.system == system;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, system);
}
