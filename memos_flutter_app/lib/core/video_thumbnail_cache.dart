import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../data/logs/log_manager.dart';

const int _blankSpreadThreshold = 24;
const double _blankStdDevThreshold = 6.0;
const double _scoreSpreadWeight = 0.05;
const double _brightnessWeight = 0.1;
const double _darkMeanThreshold = 35.0;
const double _darkPenalty = 0.6;
const double _preferBrightThreshold = 50.0;
const Duration _pendingPollInterval = Duration(milliseconds: 250);
const Duration _pendingMaxWait = Duration(seconds: 35);
const Duration _mediaKitOpenTimeout = Duration(seconds: 12);
const Duration _mediaKitCaptureTimeout = Duration(seconds: 4);
const Duration _mediaKitFrameSettleDelay = Duration(milliseconds: 180);

class _FrameStats {
  const _FrameStats({
    required this.spread,
    required this.stdDev,
    required this.mean,
    required this.samples,
  });

  final int spread;
  final double stdDev;
  final double mean;
  final int samples;

  bool get isBlank =>
      spread <= _blankSpreadThreshold || stdDev <= _blankStdDevThreshold;

  double get score => stdDev + (spread * _scoreSpreadWeight);
}

class VideoThumbnailCache {
  static const _folderName = 'video_thumbnails';
  static const _maxWidth = 512;
  static const _quality = 75;
  static const _cacheVersion = 10;
  static const List<int> _captureTimesMs = [
    0,
    500,
    1000,
    2000,
    3000,
    5000,
    8000,
    12000,
    15000,
  ];
  static const _downloadTimeout = Duration(seconds: 90);
  static bool get _useMediaKitDesktopPipeline =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static final Map<String, Future<File?>> _pending = {};
  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, File> _fileCache = {};

  static File? peekThumbnailFile({
    required String id,
    required int size,
    required File? localFile,
    required String? videoUrl,
  }) {
    final key = _cacheKey(
      id: id,
      size: size,
      localFile: localFile,
      videoUrl: videoUrl,
    );
    final file = _fileCache[key];
    if (file == null) return null;
    if (!file.existsSync() || file.lengthSync() <= 0) {
      _fileCache.remove(key);
      return null;
    }
    return file;
  }

  static Uint8List? peekThumbnailBytes({
    required String id,
    required int size,
    required File? localFile,
    required String? videoUrl,
  }) {
    final key = _cacheKey(
      id: id,
      size: size,
      localFile: localFile,
      videoUrl: videoUrl,
    );
    final bytes = _memoryCache[key];
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  }

  static Future<File?> getThumbnailFile({
    required String id,
    required int size,
    required File? localFile,
    required String? videoUrl,
    Map<String, String>? headers,
  }) async {
    final key = _cacheKey(
      id: id,
      size: size,
      localFile: localFile,
      videoUrl: videoUrl,
    );
    final existingFile = await _tryExistingFile(key);
    if (existingFile != null) {
      _pending.remove(key);
      _rememberFile(key, existingFile);
      LogManager.instance.debug(
        'Video thumbnail cache hit (direct)',
        context: {
          'key': key,
          'path': existingFile.path,
          'bytes': existingFile.lengthSync(),
        },
      );
      return existingFile;
    }
    final existing = _pending[key];
    if (existing != null) {
      return _resolveExistingOrPending(existing, key);
    }

    final future = _loadOrCreate(
      key: key,
      localFile: localFile,
      videoUrl: videoUrl,
      headers: headers,
    ).whenComplete(() => _pending.remove(key));

    _pending[key] = future;
    return future;
  }

  static Future<File?> _tryExistingFile(String key) async {
    try {
      final cacheDir = await _cacheDir();
      final filePath = p.join(cacheDir.path, '$key.jpg');
      final file = File(filePath);
      if (file.existsSync() && file.lengthSync() > 0) {
        _rememberFile(key, file);
        return file;
      }
    } catch (_) {}
    return null;
  }

  static Future<File?> _resolveExistingOrPending(
    Future<File?> pending,
    String key,
  ) async {
    Directory cacheDir;
    try {
      cacheDir = await _cacheDir();
    } catch (_) {
      return pending;
    }
    final filePath = p.join(cacheDir.path, '$key.jpg');
    final file = File(filePath);

    bool hasFile() => file.existsSync() && file.lengthSync() > 0;

    if (hasFile()) {
      _pending.remove(key);
      LogManager.instance.debug(
        'Video thumbnail cache hit (pending bypass)',
        context: {'key': key, 'path': filePath, 'bytes': file.lengthSync()},
      );
      return file;
    }

    final completer = Completer<File?>();
    Timer? pollTimer;
    Timer? timeoutTimer;

    void completeWithFile(String reason) {
      if (completer.isCompleted) return;
      _pending.remove(key);
      _rememberFile(key, file);
      LogManager.instance.debug(
        reason,
        context: {'key': key, 'path': filePath, 'bytes': file.lengthSync()},
      );
      completer.complete(file);
    }

    pollTimer = Timer.periodic(_pendingPollInterval, (_) {
      if (hasFile()) {
        completeWithFile('Video thumbnail cache hit (pending poll)');
      }
    });

    timeoutTimer = Timer(_pendingMaxWait, () {
      if (completer.isCompleted) return;
      if (hasFile()) {
        completeWithFile('Video thumbnail cache hit (pending timeout)');
        return;
      }
      _pending.remove(key);
      LogManager.instance.warn(
        'Video thumbnail pending timeout',
        context: {'key': key, 'path': filePath},
      );
      completer.complete(null);
    });

    pending
        .then((value) {
          if (completer.isCompleted) return;
          _rememberFile(key, value);
          completer.complete(value);
        })
        .catchError((error, stackTrace) {
          if (completer.isCompleted) return;
          completer.completeError(error, stackTrace);
        });

    try {
      return await completer.future;
    } finally {
      pollTimer.cancel();
      timeoutTimer.cancel();
    }
  }

  static Future<Uint8List?> getThumbnailBytes({
    required String id,
    required int size,
    required File? localFile,
    required String? videoUrl,
    Map<String, String>? headers,
  }) async {
    final key = _cacheKey(
      id: id,
      size: size,
      localFile: localFile,
      videoUrl: videoUrl,
    );
    final cached = _memoryCache[key];
    if (cached != null && cached.isNotEmpty) return cached;

    final file = await getThumbnailFile(
      id: id,
      size: size,
      localFile: localFile,
      videoUrl: videoUrl,
      headers: headers,
    );
    if (file == null || !file.existsSync()) {
      LogManager.instance.warn(
        'Video thumbnail bytes missing (file not found)',
        context: {'key': key, 'path': file?.path ?? ''},
      );
      return null;
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        LogManager.instance.warn(
          'Video thumbnail bytes empty',
          context: {'key': key, 'path': file.path},
        );
        return null;
      }
      _memoryCache[key] = bytes;
      LogManager.instance.debug(
        'Video thumbnail bytes ready',
        context: {'key': key, 'path': file.path, 'bytes': bytes.length},
      );
      return bytes;
    } catch (e, stackTrace) {
      LogManager.instance.warn(
        'Video thumbnail read failed',
        error: e,
        stackTrace: stackTrace,
        context: {'key': key, 'path': file.path},
      );
      return null;
    }
  }

  static String _cacheKey({
    required String id,
    required int size,
    required File? localFile,
    required String? videoUrl,
  }) {
    final source = (localFile?.path ?? videoUrl ?? id).trim();
    final raw = '$source|$size|$_cacheVersion';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  static Future<File?> _loadOrCreate({
    required String key,
    required File? localFile,
    required String? videoUrl,
    Map<String, String>? headers,
  }) async {
    final cacheDir = await _cacheDir();
    final filePath = p.join(cacheDir.path, '$key.jpg');
    final file = File(filePath);
    if (file.existsSync() && file.lengthSync() > 0) {
      _rememberFile(key, file);
      LogManager.instance.debug(
        'Video thumbnail cache hit',
        context: {'key': key, 'path': filePath, 'bytes': file.lengthSync()},
      );
      return file;
    }
    LogManager.instance.debug(
      'Video thumbnail cache miss',
      context: {
        'key': key,
        'hasLocal': localFile != null,
        'videoUrl': videoUrl ?? '',
      },
    );

    final bytes = await _generateThumbnail(
      localFile: localFile,
      videoUrl: videoUrl,
      headers: headers,
    );
    if (bytes == null || bytes.isEmpty) {
      LogManager.instance.warn(
        'Video thumbnail generate failed',
        context: {
          'key': key,
          'hasLocal': localFile != null,
          'videoUrl': videoUrl ?? '',
        },
      );
      return null;
    }

    try {
      await file.writeAsBytes(bytes, flush: true);
      _rememberFile(key, file);
      LogManager.instance.debug(
        'Video thumbnail saved',
        context: {'key': key, 'path': filePath, 'bytes': bytes.length},
      );
      return file;
    } catch (e, stackTrace) {
      LogManager.instance.warn(
        'Video thumbnail save failed',
        error: e,
        stackTrace: stackTrace,
        context: {'key': key, 'path': filePath},
      );
      return null;
    }
  }

  static void _rememberFile(String key, File? file) {
    if (file == null || !file.existsSync() || file.lengthSync() <= 0) {
      _fileCache.remove(key);
      return;
    }
    _fileCache[key] = file;
  }

  static Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _folderName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<Uint8List?> _generateThumbnail({
    required File? localFile,
    required String? videoUrl,
    Map<String, String>? headers,
  }) async {
    if (localFile != null && localFile.existsSync()) {
      LogManager.instance.debug(
        'Video thumbnail source local',
        context: {
          'file': p.basename(localFile.path),
          'bytes': localFile.lengthSync(),
        },
      );
      if (_useMediaKitDesktopPipeline) {
        final mediaKitData = await _tryMediaKitThumbnailData(
          source: localFile.path,
          headers: null,
        );
        if (mediaKitData != null && mediaKitData.isNotEmpty) {
          return mediaKitData;
        }
      }
      return _tryThumbnailData(source: localFile.path, headers: null);
    }

    final url = (videoUrl ?? '').trim();
    if (url.isEmpty) {
      LogManager.instance.warn('Video thumbnail source missing');
      return null;
    }

    if (_useMediaKitDesktopPipeline) {
      final mediaKitData = await _tryMediaKitThumbnailData(
        source: url,
        headers: headers,
      );
      if (mediaKitData != null && mediaKitData.isNotEmpty) {
        return mediaKitData;
      }
    }

    final tempFile = await _downloadToTemp(url, headers: headers ?? const {});
    if (tempFile == null) {
      LogManager.instance.warn(
        'Video thumbnail download failed, fallback to direct',
        context: {
          'videoUrl': url,
          'hasHeaders': headers != null && headers.isNotEmpty,
        },
      );
      return _tryThumbnailData(source: url, headers: headers);
    }
    try {
      final data = await _tryThumbnailData(
        source: tempFile.path,
        headers: null,
      );
      if (data != null && data.isNotEmpty) return data;
    } finally {
      if (tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    LogManager.instance.warn(
      'Video thumbnail fallback to direct after file attempt',
      context: {'videoUrl': url},
    );
    return _tryThumbnailData(source: url, headers: headers);
  }

  static Future<Uint8List?> _tryMediaKitThumbnailData({
    required String source,
    required Map<String, String>? headers,
  }) async {
    Player? player;
    VideoController? videoController;
    Uint8List? bestData;
    Uint8List? bestBlankData;
    Uint8List? brightestData;
    int? bestTimeMs;
    int? bestBlankTimeMs;
    int? brightestTimeMs;
    _FrameStats? bestStats;
    _FrameStats? bestBlankStats;
    _FrameStats? brightestStats;
    double bestScore = -1;
    double bestBlankScore = -1;
    double brightestMean = -1;

    try {
      final safeHeaders =
          headers == null || headers.isEmpty ? null : Map<String, String>.from(headers);
      player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          title: 'MemoFlow Thumbnail',
        ),
      );
      videoController = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          width: 320,
          height: 180,
          enableHardwareAcceleration: true,
        ),
      );

      await player
          .open(
            Media(source, httpHeaders: safeHeaders),
            play: true,
          )
          .timeout(_mediaKitOpenTimeout);
      try {
        await videoController
            .waitUntilFirstFrameRendered
            .timeout(_mediaKitOpenTimeout);
      } catch (_) {}
      await Future<void>.delayed(_mediaKitFrameSettleDelay);
      await player.pause();

      final durationMs = player.state.duration.inMilliseconds;
      final maxCaptureMs = durationMs > 0
          ? math.max(0, durationMs - 120)
          : _captureTimesMs.last;

      for (final requestedTimeMs in _captureTimesMs) {
        final captureMs = math.min(math.max(requestedTimeMs, 0), maxCaptureMs);
        try {
          await player.seek(Duration(milliseconds: captureMs));
          await player.play();
          await Future<void>.delayed(_mediaKitFrameSettleDelay);
          await player.pause();
          final data = await player
              .screenshot(format: 'image/jpeg')
              .timeout(_mediaKitCaptureTimeout);
          if (data == null || data.isEmpty) continue;

          final stats = await _analyzeFrame(data);
          if (stats == null) continue;

          var adjustedScore = stats.score + (stats.mean * _brightnessWeight);
          if (stats.mean < _darkMeanThreshold) {
            adjustedScore *= _darkPenalty;
          }
          if (stats.mean > brightestMean) {
            brightestMean = stats.mean;
            brightestData = data;
            brightestTimeMs = captureMs;
            brightestStats = stats;
          }
          if (stats.isBlank) {
            if (adjustedScore > bestBlankScore) {
              bestBlankScore = adjustedScore;
              bestBlankData = data;
              bestBlankTimeMs = captureMs;
              bestBlankStats = stats;
            }
            continue;
          }
          if (adjustedScore > bestScore) {
            bestScore = adjustedScore;
            bestData = data;
            bestTimeMs = captureMs;
            bestStats = stats;
          }
        } catch (_) {
          // Ignore per-frame capture failure and keep trying other timestamps.
        }
      }

      if (bestData != null) {
        if (bestStats != null &&
            brightestData != null &&
            brightestStats != null &&
            bestStats.mean < _preferBrightThreshold) {
          LogManager.instance.debug(
            'Video thumbnail media_kit fallback to brightest frame',
            context: {
              'bestTimeMs': bestTimeMs ?? -1,
              'bestMean': bestStats.mean.toStringAsFixed(2),
              'brightTimeMs': brightestTimeMs ?? -1,
              'brightMean': brightestStats.mean.toStringAsFixed(2),
            },
          );
          return brightestData;
        }
        LogManager.instance.debug(
          'Video thumbnail media_kit selected best frame',
          context: {
            'timeMs': bestTimeMs ?? -1,
            'bytes': bestData.length,
            'spread': bestStats?.spread ?? -1,
            'stdDev': bestStats?.stdDev.toStringAsFixed(2) ?? 'n/a',
            'mean': bestStats?.mean.toStringAsFixed(2) ?? 'n/a',
            'score': bestStats?.score.toStringAsFixed(2) ?? 'n/a',
          },
        );
        return bestData;
      }

      if (bestBlankData != null) {
        LogManager.instance.debug(
          'Video thumbnail media_kit fallback to blank frame',
          context: {
            'timeMs': bestBlankTimeMs ?? -1,
            'bytes': bestBlankData.length,
            'spread': bestBlankStats?.spread ?? -1,
            'stdDev': bestBlankStats?.stdDev.toStringAsFixed(2) ?? 'n/a',
            'mean': bestBlankStats?.mean.toStringAsFixed(2) ?? 'n/a',
          },
        );
        return bestBlankData;
      }

      final fallback = await player
          .screenshot(format: 'image/jpeg')
          .timeout(_mediaKitCaptureTimeout);
      if (fallback != null && fallback.isNotEmpty) {
        LogManager.instance.debug(
          'Video thumbnail media_kit screenshot fallback',
          context: {'bytes': fallback.length},
        );
      }
      return fallback;
    } catch (e, stackTrace) {
      LogManager.instance.warn(
        'Video thumbnail media_kit failed',
        error: e,
        stackTrace: stackTrace,
        context: {'source': source},
      );
      return null;
    } finally {
      try {
        await player?.dispose();
      } catch (_) {}
    }
  }

  static Future<Uint8List?> _tryThumbnailData({
    required String source,
    required Map<String, String>? headers,
  }) async {
    Uint8List? bestData;
    Uint8List? bestBlankData;
    Uint8List? brightestData;
    int? bestTimeMs;
    int? bestBlankTimeMs;
    int? brightestTimeMs;
    _FrameStats? bestStats;
    _FrameStats? bestBlankStats;
    _FrameStats? brightestStats;
    double bestScore = -1;
    double bestBlankScore = -1;
    double brightestMean = -1;
    for (final timeMs in _captureTimesMs) {
      try {
        final data = await VideoThumbnail.thumbnailData(
          video: source,
          imageFormat: ImageFormat.JPEG,
          maxWidth: _maxWidth,
          quality: _quality,
          timeMs: timeMs,
          headers: headers,
        );
        if (data != null && data.isNotEmpty) {
          final stats = await _analyzeFrame(data);
          if (stats == null) {
            LogManager.instance.debug(
              'Video thumbnail capture skipped (analyze failed)',
              context: {
                'timeMs': timeMs,
                'bytes': data.length,
                'source': source,
              },
            );
            continue;
          }
          var adjustedScore = stats.score + (stats.mean * _brightnessWeight);
          if (stats.mean < _darkMeanThreshold) {
            adjustedScore *= _darkPenalty;
          }
          LogManager.instance.debug(
            'Video thumbnail frame stats',
            context: {
              'timeMs': timeMs,
              'bytes': data.length,
              'spread': stats.spread,
              'stdDev': stats.stdDev.toStringAsFixed(2),
              'mean': stats.mean.toStringAsFixed(2),
              'score': stats.score.toStringAsFixed(2),
              'scoreAdj': adjustedScore.toStringAsFixed(2),
              'blank': stats.isBlank,
              'source': source,
            },
          );
          if (stats.mean > brightestMean) {
            brightestMean = stats.mean;
            brightestData = data;
            brightestTimeMs = timeMs;
            brightestStats = stats;
          }
          if (stats.isBlank) {
            if (adjustedScore > bestBlankScore) {
              bestBlankScore = adjustedScore;
              bestBlankData = data;
              bestBlankTimeMs = timeMs;
              bestBlankStats = stats;
            }
            continue;
          }
          if (adjustedScore > bestScore) {
            bestScore = adjustedScore;
            bestData = data;
            bestTimeMs = timeMs;
            bestStats = stats;
          }
        }
        if (data == null || data.isEmpty) {
          LogManager.instance.debug(
            'Video thumbnail capture empty',
            context: {'timeMs': timeMs, 'source': source},
          );
        }
      } catch (e, stackTrace) {
        LogManager.instance.warn(
          'Video thumbnail capture failed',
          error: e,
          stackTrace: stackTrace,
          context: {'timeMs': timeMs, 'source': source},
        );
      }
    }
    if (bestData != null) {
      if (bestStats != null &&
          brightestData != null &&
          brightestStats != null &&
          bestStats.mean < _preferBrightThreshold) {
        LogManager.instance.debug(
          'Video thumbnail fallback to brightest frame',
          context: {
            'bestTimeMs': bestTimeMs ?? -1,
            'bestMean': bestStats.mean.toStringAsFixed(2),
            'brightTimeMs': brightestTimeMs ?? -1,
            'brightMean': brightestStats.mean.toStringAsFixed(2),
            'brightScore': brightestStats.score.toStringAsFixed(2),
            'source': source,
          },
        );
        return brightestData;
      }
      LogManager.instance.debug(
        'Video thumbnail selected best frame',
        context: {
          'timeMs': bestTimeMs ?? -1,
          'bytes': bestData.length,
          'spread': bestStats?.spread ?? -1,
          'stdDev': bestStats?.stdDev.toStringAsFixed(2) ?? 'n/a',
          'mean': bestStats?.mean.toStringAsFixed(2) ?? 'n/a',
          'score': bestStats?.score.toStringAsFixed(2) ?? 'n/a',
          'blank': bestStats?.isBlank ?? false,
          'source': source,
        },
      );
      return bestData;
    }
    if (bestBlankData != null) {
      LogManager.instance.debug(
        'Video thumbnail fallback to blank frame',
        context: {
          'timeMs': bestBlankTimeMs ?? -1,
          'bytes': bestBlankData.length,
          'spread': bestBlankStats?.spread ?? -1,
          'stdDev': bestBlankStats?.stdDev.toStringAsFixed(2) ?? 'n/a',
          'mean': bestBlankStats?.mean.toStringAsFixed(2) ?? 'n/a',
          'score': bestBlankStats?.score.toStringAsFixed(2) ?? 'n/a',
          'blank': bestBlankStats?.isBlank ?? false,
          'source': source,
        },
      );
      return bestBlankData;
    }
    return null;
  }

  static Future<_FrameStats?> _analyzeFrame(Uint8List bytes) async {
    ui.Image? image;
    try {
      image = await _decodeImage(bytes);
      if (image == null) return null;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final raw = data.buffer.asUint8List();
      final totalPixels = image.width * image.height;
      if (totalPixels <= 0) return null;
      const sampleCount = 64;
      final step = (totalPixels / sampleCount)
          .floor()
          .clamp(1, totalPixels)
          .toInt();
      var minL = 255;
      var maxL = 0;
      var sumL = 0.0;
      var sumSq = 0.0;
      var sampled = 0;
      var pixelIndex = 0;
      while (pixelIndex < totalPixels && sampled < sampleCount) {
        final offset = pixelIndex * 4;
        if (offset + 2 >= raw.length) break;
        final r = raw[offset];
        final g = raw[offset + 1];
        final b = raw[offset + 2];
        final l = ((r * 2126 + g * 7152 + b * 722) / 10000).round();
        if (l < minL) minL = l;
        if (l > maxL) maxL = l;
        sumL += l;
        sumSq += l * l;
        pixelIndex += step;
        sampled++;
      }
      if (sampled <= 0) return null;
      final mean = sumL / sampled;
      final variance = math.max(0.0, (sumSq / sampled) - (mean * mean));
      final stdDev = math.sqrt(variance);
      final spread = maxL - minL;
      return _FrameStats(
        spread: spread,
        stdDev: stdDev,
        mean: mean,
        samples: sampled,
      );
    } catch (e, stackTrace) {
      LogManager.instance.warn(
        'Video thumbnail analyze failed',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      try {
        image?.dispose();
      } catch (_) {}
    }
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> _downloadToTemp(
    String url, {
    required Map<String, String> headers,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final name = 'thumb_${sha1.convert(utf8.encode(url)).toString()}.mp4';
      final path = p.join(tempDir.path, name);
      final file = File(path);
      final dio = Dio();
      await dio.download(
        url,
        file.path,
        options: Options(
          headers: headers,
          receiveTimeout: _downloadTimeout,
          sendTimeout: _downloadTimeout,
        ),
      );
      if (!file.existsSync() || file.lengthSync() == 0) return null;
      LogManager.instance.debug(
        'Video thumbnail download ok',
        context: {'videoUrl': url, 'bytes': file.lengthSync()},
      );
      return file;
    } catch (e, stackTrace) {
      LogManager.instance.warn(
        'Video thumbnail download failed',
        error: e,
        stackTrace: stackTrace,
        context: {'videoUrl': url, 'hasHeaders': headers.isNotEmpty},
      );
      return null;
    }
  }
}
