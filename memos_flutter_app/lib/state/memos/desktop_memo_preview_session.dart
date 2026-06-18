import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log_sanitizer.dart';
import '../../core/memo_content_diagnostics.dart';
import '../../core/tags.dart';
import '../../core/url.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/local_memo.dart';
import '../../features/memos/memo_detail_screen.dart';
import '../settings/device_preferences_provider.dart';
import '../settings/workspace_preferences_provider.dart';
import '../system/session_provider.dart';
import 'memo_clip_card_providers.dart';

enum DesktopMemoPreviewPhase { idle, preparing, ready, error }

@immutable
class DesktopMemoPreviewCacheKey {
  const DesktopMemoPreviewCacheKey({
    required this.memoUid,
    required this.contentFingerprint,
    required this.updateTimeMicros,
    required this.attachmentCount,
    required this.baseUrl,
    required this.authHeader,
    required this.rebaseAbsoluteFileUrlForV024,
    required this.attachAuthForSameOriginAbsolute,
    required this.tagRecognitionPolicyToken,
  });

  final String memoUid;
  final String contentFingerprint;
  final int updateTimeMicros;
  final int attachmentCount;
  final String baseUrl;
  final String authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;
  final String tagRecognitionPolicyToken;

  @override
  bool operator ==(Object other) {
    return other is DesktopMemoPreviewCacheKey &&
        other.memoUid == memoUid &&
        other.contentFingerprint == contentFingerprint &&
        other.updateTimeMicros == updateTimeMicros &&
        other.attachmentCount == attachmentCount &&
        other.baseUrl == baseUrl &&
        other.authHeader == authHeader &&
        other.rebaseAbsoluteFileUrlForV024 == rebaseAbsoluteFileUrlForV024 &&
        other.attachAuthForSameOriginAbsolute ==
            attachAuthForSameOriginAbsolute &&
        other.tagRecognitionPolicyToken == tagRecognitionPolicyToken;
  }

  @override
  int get hashCode => Object.hash(
    memoUid,
    contentFingerprint,
    updateTimeMicros,
    attachmentCount,
    baseUrl,
    authHeader,
    rebaseAbsoluteFileUrlForV024,
    attachAuthForSameOriginAbsolute,
    tagRecognitionPolicyToken,
  );
}

@immutable
class DesktopMemoPreviewEntry {
  const DesktopMemoPreviewEntry({required this.key, required this.data});

  final DesktopMemoPreviewCacheKey key;
  final MemoDocumentResolvedData data;
}

@immutable
class DesktopMemoPreviewSessionState {
  const DesktopMemoPreviewSessionState({
    required this.phase,
    required this.requestId,
    required this.requestEpochMs,
    this.requestedMemo,
    this.activeKey,
    this.data,
    this.errorMessage,
  });

  static const DesktopMemoPreviewSessionState initial =
      DesktopMemoPreviewSessionState(
        phase: DesktopMemoPreviewPhase.idle,
        requestId: 0,
        requestEpochMs: 0,
      );

  final DesktopMemoPreviewPhase phase;
  final int requestId;
  final int requestEpochMs;
  final LocalMemo? requestedMemo;
  final DesktopMemoPreviewCacheKey? activeKey;
  final MemoDocumentResolvedData? data;
  final String? errorMessage;

  DesktopMemoPreviewSessionState copyWith({
    DesktopMemoPreviewPhase? phase,
    int? requestId,
    int? requestEpochMs,
    LocalMemo? requestedMemo,
    bool clearRequestedMemo = false,
    DesktopMemoPreviewCacheKey? activeKey,
    bool clearActiveKey = false,
    MemoDocumentResolvedData? data,
    bool clearData = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DesktopMemoPreviewSessionState(
      phase: phase ?? this.phase,
      requestId: requestId ?? this.requestId,
      requestEpochMs: requestEpochMs ?? this.requestEpochMs,
      requestedMemo: clearRequestedMemo
          ? null
          : (requestedMemo ?? this.requestedMemo),
      activeKey: clearActiveKey ? null : (activeKey ?? this.activeKey),
      data: clearData ? null : (data ?? this.data),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class DesktopMemoPreviewSessionController
    extends AutoDisposeNotifier<DesktopMemoPreviewSessionState> {
  static const _cacheCapacity = 8;

  final Map<DesktopMemoPreviewCacheKey, DesktopMemoPreviewEntry> _cache =
      <DesktopMemoPreviewCacheKey, DesktopMemoPreviewEntry>{};
  final Set<DesktopMemoPreviewCacheKey> _warmingKeys =
      <DesktopMemoPreviewCacheKey>{};
  bool _disposed = false;
  int _requestSeed = 0;

  @override
  DesktopMemoPreviewSessionState build() {
    ref.onDispose(() => _disposed = true);
    return DesktopMemoPreviewSessionState.initial;
  }

  Future<void> requestMemo(LocalMemo memo) async {
    final requestId = ++_requestSeed;
    final requestEpochMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final key = _buildCacheKey(memo);
    _logPreviewEvent(
      'session_request',
      memo: memo,
      context: <String, Object?>{
        'requestId': requestId,
        'cacheSize': _cache.length,
      },
    );

    final cached = _touchCache(key);
    if (cached != null) {
      state = state.copyWith(
        phase: DesktopMemoPreviewPhase.ready,
        requestId: requestId,
        requestEpochMs: requestEpochMs,
        requestedMemo: memo,
        activeKey: key,
        data: cached.data,
        clearErrorMessage: true,
      );
      _logPreviewEvent(
        'cache_hit',
        memo: memo,
        context: <String, Object?>{'requestId': requestId},
      );
      return;
    }

    state = state.copyWith(
      phase: DesktopMemoPreviewPhase.preparing,
      requestId: requestId,
      requestEpochMs: requestEpochMs,
      requestedMemo: memo,
      clearErrorMessage: true,
    );
    _logPreviewEvent(
      'cache_miss',
      memo: memo,
      context: <String, Object?>{'requestId': requestId},
    );

    unawaited(
      Future<void>(() async {
        _logPreviewEvent(
          'bundle_prepare_start',
          memo: memo,
          context: <String, Object?>{'requestId': requestId},
        );
        try {
          final data = _prepareResolvedData(memo);
          _storeCache(key, data);
          final elapsedMs =
              DateTime.now().toUtc().millisecondsSinceEpoch - requestEpochMs;
          _logPreviewEvent(
            'bundle_prepare_complete',
            memo: memo,
            context: <String, Object?>{
              'requestId': requestId,
              'elapsedMs': elapsedMs,
            },
          );
          if (_disposed) return;
          if (state.requestId != requestId) {
            _logPreviewEvent(
              'stale_request_ignored',
              memo: memo,
              context: <String, Object?>{
                'requestId': requestId,
                'activeRequestId': state.requestId,
              },
            );
            return;
          }
          state = state.copyWith(
            phase: DesktopMemoPreviewPhase.ready,
            activeKey: key,
            data: data,
            clearErrorMessage: true,
          );
        } catch (error) {
          if (_disposed) return;
          if (state.requestId != requestId) {
            _logPreviewEvent(
              'stale_request_ignored',
              memo: memo,
              context: <String, Object?>{
                'requestId': requestId,
                'activeRequestId': state.requestId,
                'during': 'error',
              },
            );
            return;
          }
          state = state.copyWith(
            phase: DesktopMemoPreviewPhase.error,
            errorMessage: error.toString(),
          );
        }
      }),
    );
  }

  void prewarmMemo(LocalMemo memo) {
    final key = _buildCacheKey(memo);
    if (_cache.containsKey(key) || !_warmingKeys.add(key)) {
      return;
    }
    unawaited(
      Future<void>(() async {
        try {
          final data = _prepareResolvedData(memo);
          if (_disposed) return;
          _storeCache(key, data);
        } finally {
          _warmingKeys.remove(key);
        }
      }),
    );
  }

  void retry() {
    final memo = state.requestedMemo;
    if (memo == null) return;
    unawaited(requestMemo(memo));
  }

  DesktopMemoPreviewCacheKey _buildCacheKey(LocalMemo memo) {
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? '' : 'Bearer $token';
    final TagRecognitionPolicy tagRecognitionPolicy = ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    return DesktopMemoPreviewCacheKey(
      memoUid: memo.uid.trim(),
      contentFingerprint: memo.contentFingerprint.trim(),
      updateTimeMicros: memo.updateTime.microsecondsSinceEpoch,
      attachmentCount: memo.attachments.length,
      baseUrl: baseUrl?.toString() ?? '',
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: isServerVersion024(serverVersion),
      attachAuthForSameOriginAbsolute: isServerVersion021(serverVersion),
      tagRecognitionPolicyToken: tagRecognitionPolicy.cacheToken,
    );
  }

  MemoDocumentResolvedData _prepareResolvedData(LocalMemo memo) {
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final appLanguage = ref.read(devicePreferencesProvider).language;
    final TagRecognitionPolicy tagRecognitionPolicy = ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    return buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: appLanguage,
      clipCard: ref.read(memoClipCardByUidProvider(memo.uid)),
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: isServerVersion024(serverVersion),
      attachAuthForSameOriginAbsolute: isServerVersion021(serverVersion),
      richContentEnabled: true,
      tagRecognitionPolicy: tagRecognitionPolicy,
    );
  }

  DesktopMemoPreviewEntry? _touchCache(DesktopMemoPreviewCacheKey key) {
    final existing = _cache.remove(key);
    if (existing == null) return null;
    _cache[key] = existing;
    return existing;
  }

  void _storeCache(
    DesktopMemoPreviewCacheKey key,
    MemoDocumentResolvedData data,
  ) {
    _cache.remove(key);
    _cache[key] = DesktopMemoPreviewEntry(key: key, data: data);
    while (_cache.length > _cacheCapacity) {
      final evictedKey = _cache.keys.first;
      final evicted = _cache.remove(evictedKey);
      if (evicted != null) {
        _logPreviewEvent(
          'cache_evicted',
          memo: evicted.data.memo,
          context: <String, Object?>{
            'memoKeyFingerprint': LogSanitizer.redactWithFingerprint(
              evictedKey.memoUid,
              kind: 'memo_uid',
            ),
          },
        );
      }
    }
  }

  void _logPreviewEvent(
    String event, {
    required LocalMemo memo,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    if (!kDebugMode) return;
    LogManager.instance.info(
      'Desktop preview: $event',
      context: <String, Object?>{
        ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
        ...context,
      },
    );
  }
}

final desktopMemoPreviewSessionProvider =
    AutoDisposeNotifierProvider<
      DesktopMemoPreviewSessionController,
      DesktopMemoPreviewSessionState
    >(DesktopMemoPreviewSessionController.new);
