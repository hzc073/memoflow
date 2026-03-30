import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/system/logging_provider.dart';
import '../../state/system/session_provider.dart';

typedef MemosListAudioRead = T Function<T>(ProviderListenable<T> provider);

abstract interface class MemosListAudioPlayerAdapter {
  bool get playing;
  Duration get position;
  Duration? get duration;
  ProcessingState get processingState;
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Future<Duration?> setFilePath(String path);
  Future<Duration?> setUrl(String url, {Map<String, String>? headers});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioMemosListAudioPlayerAdapter
    implements MemosListAudioPlayerAdapter {
  JustAudioMemosListAudioPlayerAdapter({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  bool get playing => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  ProcessingState get processingState => _player.processingState;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers}) =>
      _player.setUrl(url, headers: headers);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}

@immutable
class MemosListResolvedAudioSource {
  const MemosListResolvedAudioSource({
    required this.url,
    this.localPath,
    this.headers,
  });

  final String url;
  final String? localPath;
  final Map<String, String>? headers;
}

enum MemosListAudioToggleResultKind { handled, sourceMissing, playbackFailed }

@immutable
class MemosListAudioToggleResult {
  const MemosListAudioToggleResult({required this.kind, this.error});

  const MemosListAudioToggleResult.handled()
    : kind = MemosListAudioToggleResultKind.handled,
      error = null;

  const MemosListAudioToggleResult.sourceMissing()
    : kind = MemosListAudioToggleResultKind.sourceMissing,
      error = null;

  const MemosListAudioToggleResult.playbackFailed(Object this.error)
    : kind = MemosListAudioToggleResultKind.playbackFailed;

  final MemosListAudioToggleResultKind kind;
  final Object? error;
}

class MemosListAudioPlaybackCoordinator extends ChangeNotifier {
  MemosListAudioPlaybackCoordinator({
    required MemosListAudioRead read,
    MemosListAudioPlayerAdapter? playerOverride,
    MemosListResolvedAudioSource? Function(Attachment attachment)?
    resolveSourceOverride,
  }) : _read = read,
       _player = playerOverride ?? JustAudioMemosListAudioPlayerAdapter(),
       _resolveSourceOverride = resolveSourceOverride {
    _audioStateSub = _player.playerStateStream.listen(_handlePlayerState);
    _audioPositionSub = _player.positionStream.listen(_handlePositionChanged);
    _audioDurationSub = _player.durationStream.listen(_handleDurationChanged);
  }

  final MemosListAudioRead _read;
  final MemosListAudioPlayerAdapter _player;
  final MemosListResolvedAudioSource? Function(Attachment attachment)?
  _resolveSourceOverride;

  final ValueNotifier<Duration> _audioPositionNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration?> _audioDurationNotifier = ValueNotifier(null);

  StreamSubscription<PlayerState>? _audioStateSub;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<Duration?>? _audioDurationSub;
  Timer? _audioProgressTimer;
  DateTime? _audioProgressStart;
  Duration _audioProgressBase = Duration.zero;
  Duration _audioProgressLast = Duration.zero;
  DateTime? _lastAudioProgressLogAt;
  Duration _lastAudioProgressLogPosition = Duration.zero;
  Duration? _lastAudioLoggedDuration;
  bool _audioDurationMissingLogged = false;
  String? _playingMemoUid;
  String? _playingAudioUrl;
  bool _audioLoading = false;
  bool _disposed = false;

  String? get playingMemoUid => _playingMemoUid;
  bool get audioLoading => _audioLoading;
  bool get audioPlaying => _player.playing;
  ValueListenable<Duration> get positionListenable => _audioPositionNotifier;
  ValueListenable<Duration?> get durationListenable => _audioDurationNotifier;

  Future<MemosListAudioToggleResult> togglePlayback(LocalMemo memo) async {
    if (_disposed || _audioLoading) {
      return const MemosListAudioToggleResult.handled();
    }

    final audioAttachments = memo.attachments
        .where((attachment) => attachment.type.startsWith('audio'))
        .toList(growable: false);
    if (audioAttachments.isEmpty) {
      return const MemosListAudioToggleResult.handled();
    }

    final attachment = audioAttachments.first;
    final source = _resolveAudioSource(attachment);
    if (source == null) {
      _logAudioBreadcrumb('source missing memo=${_shortMemoUid(memo.uid)}');
      return const MemosListAudioToggleResult.sourceMissing();
    }

    final url = source.url;
    final sourceLabel = source.localPath != null ? 'local' : 'remote';
    final sameTarget = _playingMemoUid == memo.uid && _playingAudioUrl == url;

    try {
      if (sameTarget) {
        if (_player.playing) {
          await _player.pause();
          _stopAudioProgressTimer();
          _logAudioAction(
            'pause memo=${_shortMemoUid(memo.uid)} pos=${_formatDuration(_player.position)}',
            context: {
              'memo': memo.uid,
              'positionMs': _player.position.inMilliseconds,
              'source': sourceLabel,
            },
          );
        } else {
          _startAudioProgressTimer();
          _lastAudioProgressLogAt = null;
          _logAudioAction(
            'resume memo=${_shortMemoUid(memo.uid)} pos=${_formatDuration(_player.position)}',
            context: {
              'memo': memo.uid,
              'positionMs': _player.position.inMilliseconds,
              'source': sourceLabel,
            },
          );
          await _player.play();
        }
        _audioPositionNotifier.value = _player.position;
        _notifyChanged();
        return const MemosListAudioToggleResult.handled();
      }

      _resetAudioLogState();
      _logAudioAction(
        'load start memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
        context: {'memo': memo.uid, 'source': sourceLabel},
      );
      _audioLoading = true;
      _playingMemoUid = memo.uid;
      _playingAudioUrl = url;
      _audioPositionNotifier.value = Duration.zero;
      _audioDurationNotifier.value = null;
      _notifyChanged();

      await _player.stop();
      Duration? loadedDuration;
      if (source.localPath != null) {
        loadedDuration = await _player.setFilePath(source.localPath!);
      } else {
        loadedDuration = await _player.setUrl(url, headers: source.headers);
      }
      final resolvedDuration = loadedDuration ?? _player.duration;
      _audioDurationNotifier.value = resolvedDuration;
      if (resolvedDuration == null || resolvedDuration <= Duration.zero) {
        _audioDurationMissingLogged = true;
        _logAudioBreadcrumb(
          'duration missing memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
          context: {
            'memo': memo.uid,
            'durationMs': resolvedDuration?.inMilliseconds,
            'source': sourceLabel,
          },
        );
      } else {
        _lastAudioLoggedDuration = resolvedDuration;
        _logAudioBreadcrumb(
          'duration memo=${_shortMemoUid(memo.uid)} dur=${_formatDuration(resolvedDuration)} source=$sourceLabel',
          context: {
            'memo': memo.uid,
            'durationMs': resolvedDuration.inMilliseconds,
            'source': sourceLabel,
          },
        );
      }
      _logAudioAction(
        'play memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
        context: {'memo': memo.uid, 'source': sourceLabel},
      );
      _startAudioProgressTimer();
      _audioLoading = false;
      _notifyChanged();
      await _player.play();
      _notifyChanged();
      return const MemosListAudioToggleResult.handled();
    } catch (error, stackTrace) {
      _logAudioError(
        'playback failed memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
        error,
        stackTrace,
      );
      _resetActivePlaybackState();
      _notifyChanged();
      return MemosListAudioToggleResult.playbackFailed(error);
    }
  }

  Future<void> seek(LocalMemo memo, Duration target) async {
    if (_disposed || _playingMemoUid != memo.uid) return;
    final duration = _audioDurationNotifier.value;
    if (duration == null || duration <= Duration.zero) return;
    var clamped = target;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    } else if (clamped > duration) {
      clamped = duration;
    }
    try {
      await _player.seek(clamped);
      _audioProgressBase = clamped;
      _audioProgressLast = clamped;
      _audioProgressStart = DateTime.now();
      _audioPositionNotifier.value = clamped;
    } catch (error, stackTrace) {
      _logAudioError(
        'seek failed memo=${_shortMemoUid(memo.uid)}',
        error,
        stackTrace,
      );
    }
  }

  void _handlePlayerState(PlayerState state) {
    if (_disposed) return;
    if (state.playing) {
      _startAudioProgressTimer();
      if (_audioLoading) {
        _audioLoading = false;
      }
    } else {
      _stopAudioProgressTimer();
    }

    if (state.processingState == ProcessingState.completed) {
      final memoUid = _playingMemoUid;
      if (memoUid != null) {
        _logAudioAction(
          'completed memo=${_shortMemoUid(memoUid)} pos=${_formatDuration(_player.position)}',
          context: {
            'memo': memoUid,
            'positionMs': _player.position.inMilliseconds,
          },
        );
      }
      _resetAudioLogState();
      _stopAudioProgressTimer();
      unawaited(_player.seek(Duration.zero));
      unawaited(_player.pause());
      _resetActivePlaybackState();
      _notifyChanged();
      return;
    }

    _notifyChanged();
  }

  void _handlePositionChanged(Duration position) {
    if (_disposed || _playingMemoUid == null) return;
    if (_player.playing && position <= _audioProgressLast) {
      return;
    }
    _audioProgressBase = position;
    _audioProgressLast = position;
    _audioProgressStart = DateTime.now();
    _audioPositionNotifier.value = position;
  }

  void _handleDurationChanged(Duration? duration) {
    final memoUid = _playingMemoUid;
    if (_disposed || memoUid == null) return;
    _audioDurationNotifier.value = duration;
    if (duration == null || duration <= Duration.zero) {
      if (!_audioDurationMissingLogged) {
        _audioDurationMissingLogged = true;
        _logAudioBreadcrumb(
          'duration missing memo=${_shortMemoUid(memoUid)}',
          context: {'memo': memoUid, 'durationMs': duration?.inMilliseconds},
        );
      }
      return;
    }
    if (_lastAudioLoggedDuration == duration) return;
    _lastAudioLoggedDuration = duration;
    _logAudioBreadcrumb(
      'duration memo=${_shortMemoUid(memoUid)} dur=${_formatDuration(duration)}',
      context: {'memo': memoUid, 'durationMs': duration.inMilliseconds},
    );
  }

  void _resetAudioLogState() {
    _lastAudioProgressLogAt = null;
    _lastAudioProgressLogPosition = Duration.zero;
    _lastAudioLoggedDuration = null;
    _audioDurationMissingLogged = false;
  }

  void _logAudioAction(String message, {Map<String, Object?>? context}) {
    _read(loggerServiceProvider).recordAction('Audio $message');
    _read(logManagerProvider).info('Audio $message', context: context);
  }

  void _logAudioBreadcrumb(String message, {Map<String, Object?>? context}) {
    _read(loggerServiceProvider).recordBreadcrumb('Audio: $message');
    _read(logManagerProvider).info('Audio $message', context: context);
  }

  void _logAudioError(String message, Object error, StackTrace stackTrace) {
    _read(loggerServiceProvider).recordError('Audio $message');
    _read(
      logManagerProvider,
    ).error('Audio $message', error: error, stackTrace: stackTrace);
  }

  void _maybeLogAudioProgress(Duration position) {
    final memoUid = _playingMemoUid;
    if (_disposed || memoUid == null) return;
    final now = DateTime.now();
    final lastAt = _lastAudioProgressLogAt;
    if (lastAt != null && now.difference(lastAt) < const Duration(seconds: 4)) {
      return;
    }
    final lastPos = _lastAudioProgressLogPosition;
    final duration = _audioDurationNotifier.value;
    final message = position <= lastPos && lastAt != null
        ? 'progress stalled memo=${_shortMemoUid(memoUid)} pos=${_formatDuration(position)} dur=${_formatDuration(duration)}'
        : 'progress memo=${_shortMemoUid(memoUid)} pos=${_formatDuration(position)} dur=${_formatDuration(duration)}';
    _logAudioBreadcrumb(
      message,
      context: {
        'memo': memoUid,
        'positionMs': position.inMilliseconds,
        'durationMs': duration?.inMilliseconds,
        'playing': _player.playing,
        'state': _player.processingState.toString(),
      },
    );
    _lastAudioProgressLogAt = now;
    _lastAudioProgressLogPosition = position;
  }

  String _shortMemoUid(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return '--';
    return trimmed.length <= 6 ? trimmed : trimmed.substring(0, 6);
  }

  String _formatDuration(Duration? value) {
    if (value == null) return '--:--';
    final totalSeconds = value.inSeconds;
    final hh = totalSeconds ~/ 3600;
    final mm = (totalSeconds % 3600) ~/ 60;
    final ss = totalSeconds % 60;
    if (hh <= 0) {
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  void _startAudioProgressTimer() {
    if (_audioProgressTimer != null || _disposed) return;
    _audioProgressBase = _player.position;
    _audioProgressLast = _audioProgressBase;
    _audioProgressStart = DateTime.now();
    _audioProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      if (_disposed || _playingMemoUid == null) return;
      final now = DateTime.now();
      var position = _player.position;
      if (_audioProgressStart != null && position <= _audioProgressLast) {
        position = _audioProgressBase + now.difference(_audioProgressStart!);
      } else {
        _audioProgressBase = position;
        _audioProgressStart = now;
      }
      _audioProgressLast = position;
      _audioPositionNotifier.value = position;
      _maybeLogAudioProgress(position);
    });
  }

  void _stopAudioProgressTimer() {
    _audioProgressTimer?.cancel();
    _audioProgressTimer = null;
    _audioProgressStart = null;
  }

  String? _localAttachmentPath(Attachment attachment) {
    final raw = attachment.externalLink.trim();
    if (!raw.startsWith('file://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final path = uri.toFilePath();
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return path;
  }

  MemosListResolvedAudioSource? _resolveAudioSource(Attachment attachment) {
    final override = _resolveSourceOverride;
    if (override != null) {
      return override(attachment);
    }

    final rawLink = attachment.externalLink.trim();
    final account = _read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = _read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';

    if (rawLink.isNotEmpty) {
      final localPath = _localAttachmentPath(attachment);
      if (localPath != null) {
        return MemosListResolvedAudioSource(
          url: Uri.file(localPath).toString(),
          localPath: localPath,
        );
      }

      var resolved = resolveMaybeRelativeUrl(baseUrl, rawLink);
      if (rebaseAbsoluteFileUrlForV024) {
        final rebased = rebaseAbsoluteFileUrlToBase(baseUrl, resolved);
        if (rebased != null && rebased.isNotEmpty) {
          resolved = rebased;
        }
      }
      final isAbsolute = isAbsoluteUrl(resolved);
      final canAttachAuth = rebaseAbsoluteFileUrlForV024
          ? (!isAbsolute || isSameOriginWithBase(baseUrl, resolved))
          : (!isAbsolute ||
                (attachAuthForSameOriginAbsolute &&
                    isSameOriginWithBase(baseUrl, resolved)));
      final headers = (canAttachAuth && authHeader != null)
          ? <String, String>{'Authorization': authHeader}
          : null;
      return MemosListResolvedAudioSource(
        url: resolved,
        headers: headers,
      );
    }

    if (baseUrl == null) return null;
    final name = attachment.name.trim();
    final filename = attachment.filename.trim();
    if (name.isEmpty || filename.isEmpty) return null;
    final url = joinBaseUrl(baseUrl, 'file/$name/$filename');
    final headers = authHeader == null
        ? null
        : <String, String>{'Authorization': authHeader};
    return MemosListResolvedAudioSource(url: url, headers: headers);
  }

  void _resetActivePlaybackState() {
    _stopAudioProgressTimer();
    _audioPositionNotifier.value = Duration.zero;
    _audioDurationNotifier.value = null;
    _audioLoading = false;
    _playingMemoUid = null;
    _playingAudioUrl = null;
  }

  void _notifyChanged() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _audioStateSub?.cancel();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _stopAudioProgressTimer();
    _audioPositionNotifier.dispose();
    _audioDurationNotifier.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }
}
