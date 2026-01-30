class MemoLocation {
  const MemoLocation({
    required this.placeholder,
    required this.latitude,
    required this.longitude,
  });

  final String placeholder;
  final double latitude;
  final double longitude;

  bool get hasPlaceholder => placeholder.trim().isNotEmpty;

  String displayText({int fractionDigits = 6}) {
    if (hasPlaceholder) return placeholder.trim();
    final lat = _formatDouble(latitude, fractionDigits);
    final lng = _formatDouble(longitude, fractionDigits);
    return '$lat, $lng';
  }

  MemoLocation copyWith({
    String? placeholder,
    double? latitude,
    double? longitude,
  }) {
    return MemoLocation(
      placeholder: placeholder ?? this.placeholder,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeholder': placeholder,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static MemoLocation? fromJson(Map<String, dynamic> json) {
    final lat = _readDouble(json['latitude']);
    final lng = _readDouble(json['longitude']);
    if (lat == null || lng == null) return null;
    return MemoLocation(
      placeholder: (json['placeholder'] as String?) ?? '',
      latitude: lat,
      longitude: lng,
    );
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String _formatDouble(double value, int fractionDigits) {
    if (!value.isFinite) return value.toString();
    return value.toStringAsFixed(fractionDigits);
  }
}
