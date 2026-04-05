enum ImageCompressionFormat { auto, jpeg, webp }

class ImageCompressionSettings {
  static const int minMaxSide = 640;
  static const int maxMaxSide = 4096;
  static const int minQuality = 30;
  static const int maxQuality = 95;

  static const defaults = ImageCompressionSettings(
    schemaVersion: 1,
    enabled: true,
    maxSide: 1920,
    quality: 80,
    format: ImageCompressionFormat.jpeg,
  );

  const ImageCompressionSettings({
    required this.schemaVersion,
    required this.enabled,
    required this.maxSide,
    required this.quality,
    required this.format,
  });

  final int schemaVersion;
  final bool enabled;
  final int maxSide;
  final int quality;
  final ImageCompressionFormat format;

  ImageCompressionSettings copyWith({
    int? schemaVersion,
    bool? enabled,
    int? maxSide,
    int? quality,
    ImageCompressionFormat? format,
  }) {
    final normalizedMaxSide = _clampMaxSide(maxSide ?? this.maxSide);
    final normalizedQuality = _clampQuality(quality ?? this.quality);
    return ImageCompressionSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      enabled: enabled ?? this.enabled,
      maxSide: normalizedMaxSide,
      quality: normalizedQuality,
      format: format ?? this.format,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'enabled': enabled,
    'maxSide': maxSide,
    'quality': quality,
    'format': format.name,
  };

  factory ImageCompressionSettings.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    ImageCompressionFormat readFormat() {
      final raw = json['format'];
      if (raw is String) {
        return ImageCompressionFormat.values.firstWhere(
          (value) => value.name == raw,
          orElse: () => ImageCompressionSettings.defaults.format,
        );
      }
      return ImageCompressionSettings.defaults.format;
    }

    final schemaVersion = readInt('schemaVersion', 1);
    final maxSide = _clampMaxSide(
      readInt('maxSide', ImageCompressionSettings.defaults.maxSide),
    );
    final quality = _clampQuality(
      readInt('quality', ImageCompressionSettings.defaults.quality),
    );

    return ImageCompressionSettings(
      schemaVersion: schemaVersion,
      enabled: readBool('enabled', ImageCompressionSettings.defaults.enabled),
      maxSide: maxSide,
      quality: quality,
      format: readFormat(),
    );
  }

  static int _clampMaxSide(int value) => value.clamp(minMaxSide, maxMaxSide);

  static int _clampQuality(int value) => value.clamp(minQuality, maxQuality);
}
