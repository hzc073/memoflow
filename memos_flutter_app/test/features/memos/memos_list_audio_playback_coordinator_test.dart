import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/features/memos/memos_list_audio_playback_coordinator.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('source missing keeps coordinator idle', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter();
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => null,
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final result = await coordinator.togglePlayback(_buildMemo());

    expect(result.kind, MemosListAudioToggleResultKind.sourceMissing);
    expect(coordinator.audioLoading, isFalse);
    expect(coordinator.playingMemoUid, isNull);
    expect(coordinator.positionListenable.value, Duration.zero);
    expect(coordinator.durationListenable.value, isNull);
    expect(player.setFilePathCallCount, 0);
    expect(player.setUrlCallCount, 0);
  });

  test('first local playback uses file path and stores duration', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter(
      nextSetFilePathResult: const Duration(seconds: 42),
    );
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => const MemosListResolvedAudioSource(
        url: 'file:///tmp/audio.m4a',
        localPath: 'C:/tmp/audio.m4a',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final result = await coordinator.togglePlayback(_buildMemo());

    expect(result.kind, MemosListAudioToggleResultKind.handled);
    expect(player.stopCallCount, 1);
    expect(player.setFilePathCallCount, 1);
    expect(player.lastSetFilePath, 'C:/tmp/audio.m4a');
    expect(player.playCallCount, 1);
    expect(coordinator.playingMemoUid, 'memo-1');
    expect(coordinator.audioLoading, isFalse);
    expect(coordinator.durationListenable.value, const Duration(seconds: 42));
  });

  test('remote playback resolves url and forwards auth header', () async {
    final account = Account(
      key: 'account-1',
      baseUrl: Uri.parse('https://demo.test'),
      personalAccessToken: 'token-123',
      user: const User.empty(),
      instanceProfile: const InstanceProfile.empty(),
      serverVersionOverride: '0.24.1',
    );
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(
          (ref) => _TestSessionController(account: account),
        ),
      ],
    );
    final player = _FakeAudioPlayerAdapter(
      nextSetUrlResult: const Duration(seconds: 30),
    );
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final result = await coordinator.togglePlayback(
      _buildMemo(
        attachments: const <Attachment>[
          Attachment(
            name: 'resources/audio-1',
            filename: 'clip.mp3',
            type: 'audio/mp3',
            size: 100,
            externalLink: 'file/resources/audio-1/clip.mp3',
          ),
        ],
      ),
    );

    expect(result.kind, MemosListAudioToggleResultKind.handled);
    expect(player.setUrlCallCount, 1);
    expect(
      player.lastSetUrl,
      'https://demo.test/file/resources/audio-1/clip.mp3',
    );
    expect(
      player.lastSetUrlHeaders,
      const <String, String>{'Authorization': 'Bearer token-123'},
    );
  });

  test('same memo toggle pauses and resumes without clearing active uid', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter(
      nextSetFilePathResult: const Duration(seconds: 15),
    );
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => const MemosListResolvedAudioSource(
        url: 'file:///tmp/a.mp3',
        localPath: 'C:/tmp/a.mp3',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final memo = _buildMemo();
    await coordinator.togglePlayback(memo);
    final pauseResult = await coordinator.togglePlayback(memo);
    final resumeResult = await coordinator.togglePlayback(memo);

    expect(pauseResult.kind, MemosListAudioToggleResultKind.handled);
    expect(resumeResult.kind, MemosListAudioToggleResultKind.handled);
    expect(player.pauseCallCount, 1);
    expect(player.playCallCount, 2);
    expect(coordinator.playingMemoUid, memo.uid);
  });

  test('switching memo resets progress and loads new source', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter(
      nextSetFilePathResult: const Duration(seconds: 20),
    );
    final memoA = _buildMemo(uid: 'memo-a');
    final memoB = _buildMemo(uid: 'memo-b');
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (attachment) => MemosListResolvedAudioSource(
        url: 'file:///tmp/${attachment.filename}',
        localPath: 'C:/tmp/${attachment.filename}',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    await coordinator.togglePlayback(
      memoA.copyWithAttachmentFilename('a.mp3'),
    );
    await coordinator.seek(memoA.copyWithAttachmentFilename('a.mp3'), const Duration(seconds: 7));
    await coordinator.togglePlayback(
      memoB.copyWithAttachmentFilename('b.mp3'),
    );

    expect(player.stopCallCount, 2);
    expect(player.lastSetFilePath, 'C:/tmp/b.mp3');
    expect(coordinator.playingMemoUid, 'memo-b');
    expect(coordinator.positionListenable.value, Duration.zero);
  });

  test('seek clamps to valid range and ignores inactive memo', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter(
      nextSetFilePathResult: const Duration(seconds: 10),
    );
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => const MemosListResolvedAudioSource(
        url: 'file:///tmp/audio.mp3',
        localPath: 'C:/tmp/audio.mp3',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final activeMemo = _buildMemo(uid: 'active');
    final inactiveMemo = _buildMemo(uid: 'inactive');
    await coordinator.togglePlayback(activeMemo);

    await coordinator.seek(inactiveMemo, const Duration(seconds: 3));
    expect(player.seekCallCount, 0);

    await coordinator.seek(activeMemo, const Duration(seconds: -2));
    expect(player.seekCallCount, 1);
    expect(player.lastSeekPosition, Duration.zero);

    await coordinator.seek(activeMemo, const Duration(seconds: 99));
    expect(player.seekCallCount, 2);
    expect(player.lastSeekPosition, const Duration(seconds: 10));
  });

  test('completed playback clears active state and notifiers', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter(
      nextSetFilePathResult: const Duration(seconds: 10),
    );
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => const MemosListResolvedAudioSource(
        url: 'file:///tmp/audio.mp3',
        localPath: 'C:/tmp/audio.mp3',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    await coordinator.togglePlayback(_buildMemo());
    player.positionValue = const Duration(seconds: 4);

    player.emitPlayerState(PlayerState(false, ProcessingState.completed));
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.playingMemoUid, isNull);
    expect(coordinator.audioLoading, isFalse);
    expect(coordinator.positionListenable.value, Duration.zero);
    expect(coordinator.durationListenable.value, isNull);
  });

  test('playback failure resets active state and returns failure result', () async {
    final container = ProviderContainer();
    final error = StateError('play failed');
    final player = _FakeAudioPlayerAdapter(
      nextSetFilePathResult: const Duration(seconds: 12),
      playError: error,
    );
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => const MemosListResolvedAudioSource(
        url: 'file:///tmp/audio.mp3',
        localPath: 'C:/tmp/audio.mp3',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final result = await coordinator.togglePlayback(_buildMemo());

    expect(result.kind, MemosListAudioToggleResultKind.playbackFailed);
    expect(result.error, same(error));
    expect(coordinator.playingMemoUid, isNull);
    expect(coordinator.audioLoading, isFalse);
    expect(coordinator.positionListenable.value, Duration.zero);
    expect(coordinator.durationListenable.value, isNull);
  });

  test('missing duration keeps playback state usable', () async {
    final container = ProviderContainer();
    final player = _FakeAudioPlayerAdapter(nextSetFilePathResult: null);
    final coordinator = MemosListAudioPlaybackCoordinator(
      read: container.read,
      playerOverride: player,
      resolveSourceOverride: (_) => const MemosListResolvedAudioSource(
        url: 'file:///tmp/audio.mp3',
        localPath: 'C:/tmp/audio.mp3',
      ),
    );
    addTearDown(() async {
      coordinator.dispose();
      container.dispose();
    });

    final memo = _buildMemo();
    final firstResult = await coordinator.togglePlayback(memo);
    final secondResult = await coordinator.togglePlayback(memo);

    expect(firstResult.kind, MemosListAudioToggleResultKind.handled);
    expect(secondResult.kind, MemosListAudioToggleResultKind.handled);
    expect(coordinator.playingMemoUid, memo.uid);
    expect(coordinator.durationListenable.value, isNull);
    expect(player.pauseCallCount, 1);
  });
}

extension on LocalMemo {
  LocalMemo copyWithAttachmentFilename(String filename) {
    return LocalMemo(
      uid: uid,
      content: content,
      contentFingerprint: contentFingerprint,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTime: createTime,
      updateTime: updateTime,
      tags: tags,
      attachments: <Attachment>[
        Attachment(
          name: 'resources/$filename',
          filename: filename,
          type: 'audio/mp3',
          size: 100,
          externalLink: filename,
        ),
      ],
      relationCount: relationCount,
      location: location,
      syncState: syncState,
      lastError: lastError,
    );
  }
}

LocalMemo _buildMemo({
  String uid = 'memo-1',
  List<Attachment> attachments = const <Attachment>[
    Attachment(
      name: 'resources/audio-1',
      filename: 'clip.mp3',
      type: 'audio/mp3',
      size: 100,
      externalLink: 'clip.mp3',
    ),
  ],
}) {
  const content = 'memo body';
  final now = DateTime(2024, 1, 2, 3, 4, 5);
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: now,
    updateTime: now,
    tags: const <String>[],
    attachments: attachments,
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
  );
}

class _TestSessionController extends AppSessionController {
  _TestSessionController({Account? account})
    : super(
        AsyncValue.data(
          AppSessionState(
            accounts: account == null ? const <Account>[] : <Account>[account],
            currentKey: account?.key,
          ),
        ),
      );

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}
}

class _FakeAudioPlayerAdapter implements MemosListAudioPlayerAdapter {
  _FakeAudioPlayerAdapter({
    this.nextSetFilePathResult,
    this.nextSetUrlResult,
    this.playError,
  });

  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast(sync: true);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast(sync: true);

  bool _playing = false;
  Duration positionValue = Duration.zero;
  Duration? durationValue;
  ProcessingState processingStateValue = ProcessingState.idle;

  int setFilePathCallCount = 0;
  int setUrlCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;
  int seekCallCount = 0;

  String? lastSetFilePath;
  String? lastSetUrl;
  Map<String, String>? lastSetUrlHeaders;
  Duration? lastSeekPosition;

  Duration? nextSetFilePathResult;
  Duration? nextSetUrlResult;
  Object? setFilePathError;
  Object? setUrlError;
  Object? playError;

  @override
  bool get playing => _playing;

  @override
  Duration get position => positionValue;

  @override
  Duration? get duration => durationValue;

  @override
  ProcessingState get processingState => processingStateValue;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Future<Duration?> setFilePath(String path) async {
    setFilePathCallCount++;
    lastSetFilePath = path;
    final error = setFilePathError;
    if (error != null) throw error;
    durationValue = nextSetFilePathResult;
    processingStateValue = ProcessingState.ready;
    return nextSetFilePathResult;
  }

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers}) async {
    setUrlCallCount++;
    lastSetUrl = url;
    lastSetUrlHeaders = headers;
    final error = setUrlError;
    if (error != null) throw error;
    durationValue = nextSetUrlResult;
    processingStateValue = ProcessingState.ready;
    return nextSetUrlResult;
  }

  @override
  Future<void> play() async {
    playCallCount++;
    final error = playError;
    if (error != null) throw error;
    _playing = true;
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
    _playing = false;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _playing = false;
    positionValue = Duration.zero;
    processingStateValue = ProcessingState.idle;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCallCount++;
    lastSeekPosition = position;
    positionValue = position;
  }

  void emitPlayerState(PlayerState state) {
    _playing = state.playing;
    processingStateValue = state.processingState;
    _playerStateController.add(state);
  }

  void emitPosition(Duration position) {
    positionValue = position;
    _positionController.add(position);
  }

  void emitDuration(Duration? duration) {
    durationValue = duration;
    _durationController.add(duration);
  }

  @override
  Future<void> dispose() async {
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
