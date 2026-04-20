import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../../../data/models/image_compression_settings.dart';
import '../compression_models.dart';
import 'compression_engine.dart';

typedef _CompressNative =
    _CCSResult Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, _CCSParameters);
typedef _CompressDart =
    _CCSResult Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, _CCSParameters);

typedef _CompressToSizeNative =
    _CCSResult Function(
      ffi.Pointer<Utf8>,
      ffi.Pointer<Utf8>,
      _CCSParameters,
      ffi.IntPtr,
      ffi.Uint8,
    );
typedef _CompressToSizeDart =
    _CCSResult Function(
      ffi.Pointer<Utf8>,
      ffi.Pointer<Utf8>,
      _CCSParameters,
      int,
      int,
    );

typedef _ConvertNative =
    _CCSResult Function(
      ffi.Pointer<Utf8>,
      ffi.Pointer<Utf8>,
      ffi.Int32,
      _CCSParameters,
    );
typedef _ConvertDart =
    _CCSResult Function(
      ffi.Pointer<Utf8>,
      ffi.Pointer<Utf8>,
      int,
      _CCSParameters,
    );

final class _CCSResult extends ffi.Struct {
  @ffi.Uint8()
  external int success;

  @ffi.Uint32()
  external int code;

  external ffi.Pointer<Utf8> errorMessage;
}

final class _CCSParameters extends ffi.Struct {
  @ffi.Uint8()
  external int keepMetadata;

  @ffi.Uint32()
  external int jpegQuality;

  @ffi.Uint32()
  external int jpegChromaSubsampling;

  @ffi.Uint8()
  external int jpegProgressive;

  @ffi.Uint32()
  external int pngQuality;

  @ffi.Uint32()
  external int pngOptimizationLevel;

  @ffi.Uint8()
  external int pngForceZopfli;

  @ffi.Uint32()
  external int gifQuality;

  @ffi.Uint32()
  external int webpQuality;

  @ffi.Uint32()
  external int tiffCompression;

  @ffi.Uint32()
  external int tiffDeflateLevel;

  @ffi.Uint8()
  external int optimize;

  @ffi.Uint32()
  external int width;

  @ffi.Uint32()
  external int height;
}

class CaesiumFfiCompressionEngine implements CompressionEngine {
  CaesiumFfiCompressionEngine();

  static const String ffiLibraryVersion = '0.17.4';

  ffi.DynamicLibrary? _library;
  _CompressDart? _compress;
  _CompressToSizeDart? _compressToSize;
  _ConvertDart? _convert;
  bool _loadAttempted = false;

  @override
  String get engineId => 'libcaesium_ffi';

  @override
  String get libraryVersion => ffiLibraryVersion;

  @override
  bool get isAvailable {
    _ensureLoaded();
    return _library != null &&
        _compress != null &&
        _compressToSize != null &&
        _convert != null;
  }

  @override
  bool get requiresMatchingInputFormat => true;

  @override
  bool supportsOutputFormat(CompressionImageFormat format) =>
      isAvailable &&
      (format == CompressionImageFormat.jpeg ||
          format == CompressionImageFormat.png ||
          format == CompressionImageFormat.webp ||
          format == CompressionImageFormat.tiff);

  @override
  Future<CompressionEngineResult> compress(
    CompressionEngineRequest request,
  ) async {
    _ensureLoaded();
    final compress = _compress;
    final compressToSize = _compressToSize;
    if (compress == null || compressToSize == null) {
      throw UnsupportedError('libcaesium ffi not available');
    }

    final inputPtr = request.sourcePath.toNativeUtf8();
    final outputPtr = request.outputPath.toNativeUtf8();
    final paramsPtr = calloc<_CCSParameters>();
    try {
      _populateParameters(
        paramsPtr.ref,
        settings: request.settings,
        resizeTarget: request.resizeTarget,
      );
      final result = request.settings.mode == ImageCompressionMode.size
          ? compressToSize(
              inputPtr,
              outputPtr,
              paramsPtr.ref,
              request.maxOutputBytes ?? 0,
              1,
            )
          : compress(inputPtr, outputPtr, paramsPtr.ref);
      if (result.success != 1) {
        final message = result.errorMessage == ffi.nullptr
            ? 'libcaesium compression failed'
            : result.errorMessage.toDartString();
        throw StateError(message);
      }
      return CompressionEngineResult(outputPath: request.outputPath);
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
      calloc.free(paramsPtr);
    }
  }

  @override
  Future<void> convert(CompressionConversionRequest request) async {
    _ensureLoaded();
    final convert = _convert;
    if (convert == null) {
      throw UnsupportedError('libcaesium ffi convert not available');
    }
    final inputPtr = request.sourcePath.toNativeUtf8();
    final outputPtr = request.outputPath.toNativeUtf8();
    final paramsPtr = calloc<_CCSParameters>();
    try {
      _populateParameters(
        paramsPtr.ref,
        settings: ImageCompressionSettings.defaults.copyWith(
          keepMetadata: request.keepMetadata,
        ),
        resizeTarget: request.resizeTarget,
      );
      final result = convert(
        inputPtr,
        outputPtr,
        _supportedFileType(request.outputFormat),
        paramsPtr.ref,
      );
      if (result.success != 1) {
        final message = result.errorMessage == ffi.nullptr
            ? 'libcaesium conversion failed'
            : result.errorMessage.toDartString();
        throw StateError(message);
      }
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
      calloc.free(paramsPtr);
    }
  }

  void _ensureLoaded() {
    if (_loadAttempted) return;
    _loadAttempted = true;
    try {
      _library = _openLibrary();
      if (_library == null) return;
      _compress = _library!.lookupFunction<_CompressNative, _CompressDart>(
        'c_compress',
      );
      _compressToSize = _library!
          .lookupFunction<_CompressToSizeNative, _CompressToSizeDart>(
            'c_compress_to_size',
          );
      _convert = _library!.lookupFunction<_ConvertNative, _ConvertDart>(
        'c_convert',
      );
    } catch (_) {
      _library = null;
      _compress = null;
      _compressToSize = null;
      _convert = null;
    }
  }

  ffi.DynamicLibrary? _openLibrary() {
    if (Platform.isWindows) {
      for (final candidate in const ['caesium.dll', 'libcaesium.dll']) {
        try {
          return ffi.DynamicLibrary.open(candidate);
        } catch (_) {}
      }
      return null;
    }
    if (Platform.isAndroid) {
      try {
        return ffi.DynamicLibrary.open('libcaesium.so');
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _populateParameters(
    _CCSParameters params, {
    required ImageCompressionSettings settings,
    required CompressionResizeTarget? resizeTarget,
  }) {
    params.keepMetadata = settings.keepMetadata ? 1 : 0;
    params.jpegQuality = settings.jpeg.quality;
    params.jpegChromaSubsampling = _jpegChromaSubsampling(
      settings.jpeg.chromaSubsampling,
    );
    params.jpegProgressive = settings.jpeg.progressive ? 1 : 0;
    params.pngQuality = settings.png.quality;
    params.pngOptimizationLevel = settings.png.optimizationLevel;
    params.pngForceZopfli = 0;
    params.gifQuality = 20;
    params.webpQuality = settings.webp.quality;
    params.tiffCompression = _tiffCompression(settings.tiff.method);
    params.tiffDeflateLevel = _tiffDeflateLevel(settings.tiff.deflatePreset);
    params.optimize = settings.lossless ? 1 : 0;
    params.width = resizeTarget?.width ?? 0;
    params.height = resizeTarget?.height ?? 0;
  }

  int _jpegChromaSubsampling(JpegChromaSubsampling value) {
    return switch (value) {
      JpegChromaSubsampling.auto => 0,
      JpegChromaSubsampling.chroma444 => 444,
      JpegChromaSubsampling.chroma422 => 422,
      JpegChromaSubsampling.chroma420 => 420,
      JpegChromaSubsampling.chroma411 => 411,
    };
  }

  int _tiffCompression(TiffCompressionMethod value) {
    return switch (value) {
      TiffCompressionMethod.uncompressed => 0,
      TiffCompressionMethod.lzw => 1,
      TiffCompressionMethod.deflate => 2,
      TiffCompressionMethod.packbits => 3,
    };
  }

  int _tiffDeflateLevel(TiffDeflatePreset value) {
    return switch (value) {
      TiffDeflatePreset.fast => 3,
      TiffDeflatePreset.balanced => 6,
      TiffDeflatePreset.best => 9,
    };
  }

  int _supportedFileType(CompressionImageFormat value) {
    return switch (value) {
      CompressionImageFormat.jpeg => 0,
      CompressionImageFormat.png => 1,
      CompressionImageFormat.gif => 2,
      CompressionImageFormat.webp => 3,
      CompressionImageFormat.tiff => 4,
      _ => 5,
    };
  }
}
