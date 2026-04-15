// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_reminder.dart';
import 'package:memos_flutter_app/data/repositories/location_settings_repository.dart';
import 'package:memos_flutter_app/features/memos/memo_media_grid.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card_container.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_list_providers.dart';
import 'package:memos_flutter_app/state/settings/location_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/reminder_settings_provider.dart';
import 'package:memos_flutter_app/state/system/reminder_providers.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('failed outbox status overrides memo sync state', (tester) async {
    final memo = _buildMemo(syncState: SyncState.pending);

    await tester.pumpWidget(
      _buildHarness(
        memo: memo,
        outboxStatus: OutboxMemoStatus(
          pending: const <String>{},
          failed: <String>{memo.uid},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
    expect(card.syncStatus, MemoSyncStatus.failed);
  });

  testWidgets('pending outbox status overrides memo sync error', (
    tester,
  ) async {
    final memo = _buildMemo(syncState: SyncState.error);

    await tester.pumpWidget(
      _buildHarness(
        memo: memo,
        outboxStatus: OutboxMemoStatus(
          pending: <String>{memo.uid},
          failed: const <String>{},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
    expect(card.syncStatus, MemoSyncStatus.pending);
  });

  testWidgets('reminder provider populates reminder text', (tester) async {
    final memo = _buildMemo();
    final reminderTime = DateTime(2100, 1, 2, 3, 4);

    await tester.pumpWidget(
      _buildHarness(
        memo: memo,
        reminderMap: <String, MemoReminder>{
          memo.uid: MemoReminder(
            memoUid: memo.uid,
            mode: ReminderMode.single,
            times: <DateTime>[reminderTime],
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
    final expectedReminderText =
        '${DateFormat.Md('en').format(reminderTime)} ${DateFormat.Hm('en').format(reminderTime)}';
    expect(card.reminderText, expectedReminderText);
  });

  testWidgets(
    'inactive audio clears active listenables and forwards callbacks',
    (tester) async {
      final memo = _buildMemo();
      var tapCount = 0;
      var actionCount = 0;
      var toggleIndex = -1;

      await tester.pumpWidget(
        _buildHarness(
          memo: memo,
          playingMemoUid: 'other-memo',
          onTap: () => tapCount++,
          onAction: (_) => actionCount++,
          onToggleTask: (index) => toggleIndex = index,
        ),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
      expect(card.audioPositionListenable, isNull);
      expect(card.audioDurationListenable, isNull);
      expect(card.onAudioSeek, isNull);

      card.onTap();
      card.onAction(MemoCardAction.edit);
      card.onToggleTask(2);

      expect(tapCount, 1);
      expect(actionCount, 1);
      expect(toggleIndex, 2);
    },
  );

  testWidgets('Windows removing state suppresses media grid', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final memo = _buildMemo(
        content: 'memo with image',
        attachments: const <Attachment>[
          Attachment(
            name: 'attachments/demo',
            filename: 'demo.png',
            type: 'image/png',
            size: 1,
            externalLink: 'file:///C:/temp/demo.png',
          ),
        ],
      );

      await tester.pumpWidget(_buildHarness(memo: memo, removing: true));
      await tester.pump();

      final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
      expect(card.mediaEntries, isEmpty);
      expect(find.byType(MemoMediaGrid), findsNothing);
      expect(find.byType(Hero), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows non-removing state keeps media grid', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final memo = _buildMemo(
        content: 'memo with image',
        attachments: const <Attachment>[
          Attachment(
            name: 'attachments/demo',
            filename: 'demo.png',
            type: 'image/png',
            size: 1,
            externalLink: 'file:///C:/temp/demo.png',
          ),
        ],
      );

      await tester.pumpWidget(_buildHarness(memo: memo, removing: false));
      await tester.pump();

      final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
      expect(card.mediaEntries, hasLength(1));
      expect(find.byType(MemoMediaGrid), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('uses explicit hero tag when provided', (tester) async {
    final memo = _buildMemo();
    const heroTag = 'memo-list:visible:0:memo-1';

    await tester.pumpWidget(_buildHarness(memo: memo, heroTag: heroTag));
    await tester.pumpAndSettle();

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, heroTag);
  });
}

Widget _buildHarness({
  required LocalMemo memo,
  OutboxMemoStatus outboxStatus = const OutboxMemoStatus.empty(),
  Map<String, MemoReminder> reminderMap = const <String, MemoReminder>{},
  ReminderSettings? reminderSettings,
  String? playingMemoUid,
  bool removing = false,
  Object? heroTag,
  VoidCallback? onTap,
  ValueChanged<MemoCardAction>? onAction,
  ValueChanged<int>? onToggleTask,
}) {
  LocaleSettings.setLocale(AppLocale.en);
  final prefs = AppPreferences.defaultsForLanguage(AppLanguage.en);

  return ProviderScope(
    overrides: [
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref, prefs),
      ),
      locationSettingsProvider.overrideWith(
        (ref) =>
            _TestLocationSettingsController(ref, LocationSettings.defaults),
      ),
      reminderSettingsProvider.overrideWith(
        (ref) => _TestReminderSettingsController(
          ref,
          reminderSettings ?? ReminderSettings.defaultsFor(AppLanguage.en),
        ),
      ),
      memoReminderMapProvider.overrideWith((ref) => reminderMap),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: MemosListMemoCardContainer(
                memoCardKey: GlobalKey<MemoListCardState>(),
                memo: memo,
                heroTag: removing ? null : (heroTag ?? memo.uid),
                prefs: prefs,
                outboxStatus: outboxStatus,
                tagColors: TagColorLookup(const []),
                removing: removing,
                searching: false,
                windowsHeaderSearchExpanded: false,
                selectedQuickSearchKind: null,
                searchQuery: '',
                playingMemoUid: playingMemoUid,
                audioPlaying: true,
                audioLoading: false,
                audioPositionListenable: ValueNotifier<Duration>(
                  const Duration(seconds: 1),
                ),
                audioDurationListenable: ValueNotifier<Duration?>(
                  const Duration(seconds: 5),
                ),
                onAudioSeek: (_) {},
                onAudioTap: () {},
                onSyncStatusTap: (_) {},
                onToggleTask: onToggleTask ?? (_) {},
                onTap: onTap ?? () {},
                onDoubleTap: () {},
                onLongPress: () {},
                onFloatingStateChanged: () {},
                onAction: onAction ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

LocalMemo _buildMemo({
  String uid = 'memo-1',
  String content = 'memo body',
  SyncState syncState = SyncState.synced,
  List<Attachment> attachments = const <Attachment>[],
}) {
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
    syncState: syncState,
    lastError: null,
  );
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
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

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository(this._prefs)
    : super(const FlutterSecureStorage(), accountKey: null);

  final AppPreferences _prefs;

  @override
  Future<void> clear() async {}

  @override
  Future<AppPreferences> read() async => _prefs;

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<void> write(AppPreferences prefs) async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref, AppPreferences prefs)
    : super(
        ref,
        _TestAppPreferencesRepository(prefs),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      );
}

class _TestLocationSettingsRepository extends LocationSettingsRepository {
  _TestLocationSettingsRepository(this._settings)
    : super(const FlutterSecureStorage(), accountKey: 'test');

  final LocationSettings _settings;

  @override
  Future<LocationSettings> read() async => _settings;

  @override
  Future<void> write(LocationSettings settings) async {}

  @override
  Future<void> clear() async {}
}

class _TestLocationSettingsController extends LocationSettingsController {
  _TestLocationSettingsController(Ref ref, LocationSettings settings)
    : super(ref, _TestLocationSettingsRepository(settings));
}

class _TestReminderSettingsRepository extends ReminderSettingsRepository {
  _TestReminderSettingsRepository(this._settings)
    : super(const FlutterSecureStorage(), accountKey: null);

  final ReminderSettings _settings;

  @override
  Future<ReminderSettings?> read() async => _settings;

  @override
  Future<void> write(ReminderSettings settings) async {}
}

class _TestReminderSettingsController extends ReminderSettingsController {
  _TestReminderSettingsController(Ref ref, ReminderSettings settings)
    : super(
        ref,
        _TestReminderSettingsRepository(settings),
        onLoaded: () {
          ref.read(reminderSettingsLoadedProvider.notifier).state = true;
        },
      );
}
