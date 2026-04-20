enum ImageCompressionMode { quality, size }

enum ImageCompressionOutputFormat { sameAsInput, jpeg, png, webp, tiff }

enum ImageCompressionResizeMode {
  noResize,
  dimensions,
  percentage,
  shortEdge,
  longEdge,
  fixedWidth,
  fixedHeight,
}

enum ImageCompressionMaxOutputUnit { bytes, kb, mb, percentage }

enum JpegChromaSubsampling { auto, chroma444, chroma422, chroma420, chroma411 }

enum TiffCompressionMethod { uncompressed, lzw, deflate, packbits }

enum TiffDeflatePreset { fast, balanced, best }

class JpegCompressionSettings {
  static const int minQuality = 1;
  static const int maxQuality = 100;

  static const defaults = JpegCompressionSettings(
    quality: 80,
    chromaSubsampling: JpegChromaSubsampling.auto,
    progressive: true,
  );

  const JpegCompressionSettings({
    required this.quality,
    required this.chromaSubsampling,
    required this.progressive,
  });

  final int quality;
  final JpegChromaSubsampling chromaSubsampling;
  final bool progressive;

  JpegCompressionSettings copyWith({
    int? quality,
    JpegChromaSubsampling? chromaSubsampling,
    bool? progressive,
  }) {
    return JpegCompressionSettings(
      quality: _clampQuality(quality ?? this.quality),
      chromaSubsampling: chromaSubsampling ?? this.chromaSubsampling,
      progressive: progressive ?? this.progressive,
    );
  }

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'chromaSubsampling': chromaSubsampling.name,
    'progressive': progressive,
  };

  factory JpegCompressionSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return JpegCompressionSettings(
      quality: _clampQuality(_readInt(json['quality'], defaults.quality)),
      chromaSubsampling: _readEnum(
        raw: json['chromaSubsampling'],
        values: JpegChromaSubsampling.values,
        fallback: defaults.chromaSubsampling,
      ),
      progressive: _readBool(json['progressive'], defaults.progressive),
    );
  }

  static int _clampQuality(int value) => value.clamp(minQuality, maxQuality);
}

class PngCompressionSettings {
  static const int minQuality = 0;
  static const int maxQuality = 100;
  static const int minOptimizationLevel = 1;
  static const int maxOptimizationLevel = 6;

  static const defaults = PngCompressionSettings(
    quality: 80,
    optimizationLevel: 3,
  );

  const PngCompressionSettings({
    required this.quality,
    required this.optimizationLevel,
  });

  final int quality;
  final int optimizationLevel;

  PngCompressionSettings copyWith({int? quality, int? optimizationLevel}) {
    return PngCompressionSettings(
      quality: _clampQuality(quality ?? this.quality),
      optimizationLevel: _clampOptimizationLevel(
        optimizationLevel ?? this.optimizationLevel,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'optimizationLevel': optimizationLevel,
  };

  factory PngCompressionSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return PngCompressionSettings(
      quality: _clampQuality(_readInt(json['quality'], defaults.quality)),
      optimizationLevel: _clampOptimizationLevel(
        _readInt(json['optimizationLevel'], defaults.optimizationLevel),
      ),
    );
  }

  static int _clampQuality(int value) => value.clamp(minQuality, maxQuality);

  static int _clampOptimizationLevel(int value) =>
      value.clamp(minOptimizationLevel, maxOptimizationLevel);
}

class WebpCompressionSettings {
  static const int minQuality = 1;
  static const int maxQuality = 100;

  static const defaults = WebpCompressionSettings(quality: 60);

  const WebpCompressionSettings({required this.quality});

  final int quality;

  WebpCompressionSettings copyWith({int? quality}) {
    return WebpCompressionSettings(
      quality: _clampQuality(quality ?? this.quality),
    );
  }

  Map<String, dynamic> toJson() => {'quality': quality};

  factory WebpCompressionSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return WebpCompressionSettings(
      quality: _clampQuality(_readInt(json['quality'], defaults.quality)),
    );
  }

  static int _clampQuality(int value) => value.clamp(minQuality, maxQuality);
}

class TiffCompressionSettings {
  static const defaults = TiffCompressionSettings(
    method: TiffCompressionMethod.lzw,
    deflatePreset: TiffDeflatePreset.balanced,
  );

  const TiffCompressionSettings({
    required this.method,
    required this.deflatePreset,
  });

  final TiffCompressionMethod method;
  final TiffDeflatePreset deflatePreset;

  TiffCompressionSettings copyWith({
    TiffCompressionMethod? method,
    TiffDeflatePreset? deflatePreset,
  }) {
    return TiffCompressionSettings(
      method: method ?? this.method,
      deflatePreset: deflatePreset ?? this.deflatePreset,
    );
  }

  Map<String, dynamic> toJson() => {
    'method': method.name,
    'deflatePreset': deflatePreset.name,
  };

  factory TiffCompressionSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return TiffCompressionSettings(
      method: _readEnum(
        raw: json['method'],
        values: TiffCompressionMethod.values,
        fallback: defaults.method,
      ),
      deflatePreset: _readEnum(
        raw: json['deflatePreset'],
        values: TiffDeflatePreset.values,
        fallback: defaults.deflatePreset,
      ),
    );
  }
}

class ImageCompressionResizeSettings {
  static const int minDimension = 1;
  static const int maxDimension = 99999;
  static const int minPercentage = 1;
  static const int maxPercentage = 999;
  static const int minEdge = 1;
  static const int maxEdge = 99999;

  static const defaults = ImageCompressionResizeSettings(
    enabled: false,
    mode: ImageCompressionResizeMode.longEdge,
    width: 1920,
    height: 1920,
    edge: 1920,
    doNotEnlarge: true,
  );

  const ImageCompressionResizeSettings({
    required this.enabled,
    required this.mode,
    required this.width,
    required this.height,
    required this.edge,
    required this.doNotEnlarge,
  });

  final bool enabled;
  final ImageCompressionResizeMode mode;
  final int width;
  final int height;
  final int edge;
  final bool doNotEnlarge;

  ImageCompressionResizeSettings copyWith({
    bool? enabled,
    ImageCompressionResizeMode? mode,
    int? width,
    int? height,
    int? edge,
    bool? doNotEnlarge,
  }) {
    return ImageCompressionResizeSettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      width: _clampDimension(width ?? this.width),
      height: _clampDimension(height ?? this.height),
      edge: _clampEdge(edge ?? this.edge),
      doNotEnlarge: doNotEnlarge ?? this.doNotEnlarge,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mode': mode.name,
    'width': width,
    'height': height,
    'edge': edge,
    'doNotEnlarge': doNotEnlarge,
  };

  factory ImageCompressionResizeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return ImageCompressionResizeSettings(
      enabled: _readBool(json['enabled'], defaults.enabled),
      mode: _readEnum(
        raw: json['mode'],
        values: ImageCompressionResizeMode.values,
        fallback: defaults.mode,
      ),
      width: _clampDimension(_readInt(json['width'], defaults.width)),
      height: _clampDimension(_readInt(json['height'], defaults.height)),
      edge: _clampEdge(_readInt(json['edge'], defaults.edge)),
      doNotEnlarge: _readBool(json['doNotEnlarge'], defaults.doNotEnlarge),
    );
  }

  static int _clampDimension(int value) =>
      value.clamp(minDimension, maxDimension);

  static int _clampEdge(int value) => value.clamp(minEdge, maxEdge);
}

class ImageCompressionSizeTarget {
  static const int minValue = 1;
  static const int maxValue = 1024 * 1024;

  static const defaults = ImageCompressionSizeTarget(
    value: 80,
    unit: ImageCompressionMaxOutputUnit.percentage,
  );

  const ImageCompressionSizeTarget({required this.value, required this.unit});

  final int value;
  final ImageCompressionMaxOutputUnit unit;

  ImageCompressionSizeTarget copyWith({
    int? value,
    ImageCompressionMaxOutputUnit? unit,
  }) {
    final resolvedUnit = unit ?? this.unit;
    return ImageCompressionSizeTarget(
      value: _clampValue(value ?? this.value, resolvedUnit),
      unit: resolvedUnit,
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit.name};

  factory ImageCompressionSizeTarget.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final unit = _readEnum(
      raw: json['unit'],
      values: ImageCompressionMaxOutputUnit.values,
      fallback: defaults.unit,
    );
    return ImageCompressionSizeTarget(
      value: _clampValue(_readInt(json['value'], defaults.value), unit),
      unit: unit,
    );
  }

  static int _clampValue(int value, ImageCompressionMaxOutputUnit unit) {
    if (unit == ImageCompressionMaxOutputUnit.percentage) {
      return value.clamp(1, 100);
    }
    return value.clamp(minValue, maxValue);
  }
}

class ImageCompressionSettings {
  static const int currentSchemaVersion = 2;

  static const defaults = ImageCompressionSettings(
    schemaVersion: currentSchemaVersion,
    enabled: true,
    mode: ImageCompressionMode.quality,
    outputFormat: ImageCompressionOutputFormat.sameAsInput,
    lossless: false,
    keepMetadata: false,
    skipIfBigger: true,
    resize: ImageCompressionResizeSettings.defaults,
    jpeg: JpegCompressionSettings.defaults,
    png: PngCompressionSettings.defaults,
    webp: WebpCompressionSettings.defaults,
    tiff: TiffCompressionSettings.defaults,
    sizeTarget: ImageCompressionSizeTarget.defaults,
  );

  const ImageCompressionSettings({
    required this.schemaVersion,
    required this.enabled,
    required this.mode,
    required this.outputFormat,
    required this.lossless,
    required this.keepMetadata,
    required this.skipIfBigger,
    required this.resize,
    required this.jpeg,
    required this.png,
    required this.webp,
    required this.tiff,
    required this.sizeTarget,
  });

  final int schemaVersion;
  final bool enabled;
  final ImageCompressionMode mode;
  final ImageCompressionOutputFormat outputFormat;
  final bool lossless;
  final bool keepMetadata;
  final bool skipIfBigger;
  final ImageCompressionResizeSettings resize;
  final JpegCompressionSettings jpeg;
  final PngCompressionSettings png;
  final WebpCompressionSettings webp;
  final TiffCompressionSettings tiff;
  final ImageCompressionSizeTarget sizeTarget;

  ImageCompressionSettings copyWith({
    int? schemaVersion,
    bool? enabled,
    ImageCompressionMode? mode,
    ImageCompressionOutputFormat? outputFormat,
    bool? lossless,
    bool? keepMetadata,
    bool? skipIfBigger,
    ImageCompressionResizeSettings? resize,
    JpegCompressionSettings? jpeg,
    PngCompressionSettings? png,
    WebpCompressionSettings? webp,
    TiffCompressionSettings? tiff,
    ImageCompressionSizeTarget? sizeTarget,
  }) {
    return ImageCompressionSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      outputFormat: outputFormat ?? this.outputFormat,
      lossless: lossless ?? this.lossless,
      keepMetadata: keepMetadata ?? this.keepMetadata,
      skipIfBigger: skipIfBigger ?? this.skipIfBigger,
      resize: resize ?? this.resize,
      jpeg: jpeg ?? this.jpeg,
      png: png ?? this.png,
      webp: webp ?? this.webp,
      tiff: tiff ?? this.tiff,
      sizeTarget: sizeTarget ?? this.sizeTarget,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'enabled': enabled,
    'mode': mode.name,
    'outputFormat': outputFormat.name,
    'lossless': lossless,
    'keepMetadata': keepMetadata,
    'skipIfBigger': skipIfBigger,
    'resize': resize.toJson(),
    'jpeg': jpeg.toJson(),
    'png': png.toJson(),
    'webp': webp.toJson(),
    'tiff': tiff.toJson(),
    'sizeTarget': sizeTarget.toJson(),
  };

  factory ImageCompressionSettings.fromJson(Map<String, dynamic> json) {
    final resolvedSchemaVersion = _readInt(
      json['schemaVersion'],
      defaults.schemaVersion,
    );
    if (resolvedSchemaVersion <= 1) {
      return _fromLegacyJson(json);
    }

    return ImageCompressionSettings(
      schemaVersion: currentSchemaVersion,
      enabled: _readBool(json['enabled'], defaults.enabled),
      mode: _readEnum(
        raw: json['mode'],
        values: ImageCompressionMode.values,
        fallback: defaults.mode,
      ),
      outputFormat: _readEnum(
        raw: json['outputFormat'],
        values: ImageCompressionOutputFormat.values,
        fallback: defaults.outputFormat,
      ),
      lossless: _readBool(json['lossless'], defaults.lossless),
      keepMetadata: _readBool(json['keepMetadata'], defaults.keepMetadata),
      skipIfBigger: _readBool(json['skipIfBigger'], defaults.skipIfBigger),
      resize: ImageCompressionResizeSettings.fromJson(_readMap(json['resize'])),
      jpeg: JpegCompressionSettings.fromJson(_readMap(json['jpeg'])),
      png: PngCompressionSettings.fromJson(_readMap(json['png'])),
      webp: WebpCompressionSettings.fromJson(_readMap(json['webp'])),
      tiff: TiffCompressionSettings.fromJson(_readMap(json['tiff'])),
      sizeTarget: ImageCompressionSizeTarget.fromJson(
        _readMap(json['sizeTarget']),
      ),
    );
  }

  static ImageCompressionSettings _fromLegacyJson(Map<String, dynamic> json) {
    final legacyQuality = _readInt(json['quality'], defaults.jpeg.quality)
        .clamp(
          WebpCompressionSettings.minQuality,
          WebpCompressionSettings.maxQuality,
        );
    final legacyMaxSide = _readInt(
      json['maxSide'],
      ImageCompressionResizeSettings.defaults.edge,
    );
    final legacyFormatRaw = (json['format'] as String?)?.trim();
    final outputFormat = switch (legacyFormatRaw) {
      'jpeg' => ImageCompressionOutputFormat.jpeg,
      'webp' => ImageCompressionOutputFormat.webp,
      'png' => ImageCompressionOutputFormat.png,
      'tiff' => ImageCompressionOutputFormat.tiff,
      _ => ImageCompressionOutputFormat.sameAsInput,
    };
    return defaults.copyWith(
      enabled: _readBool(json['enabled'], defaults.enabled),
      outputFormat: outputFormat,
      resize: defaults.resize.copyWith(edge: legacyMaxSide),
      jpeg: defaults.jpeg.copyWith(quality: legacyQuality),
      png: defaults.png.copyWith(quality: legacyQuality),
      webp: defaults.webp.copyWith(quality: legacyQuality),
    );
  }
}

int _readInt(Object? raw, int fallback) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

bool _readBool(Object? raw, bool fallback) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

T _readEnum<T extends Enum>({
  required Object? raw,
  required List<T> values,
  required T fallback,
}) {
  if (raw is String) {
    final normalized = raw.trim();
    for (final value in values) {
      if (value.name == normalized) {
        return value;
      }
    }
  }
  return fallback;
}

Map<String, dynamic>? _readMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.cast<String, dynamic>();
  }
  return null;
}
