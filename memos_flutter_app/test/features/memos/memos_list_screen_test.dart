// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_dependencies.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/logs/sync_queue_progress_tracker.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_reminder.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/repositories/location_settings_repository.dart';
import 'package:memos_flutter_app/data/repositories/memo_template_settings_repository.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/application/desktop/desktop_resizable_panel_shell.dart';
import 'package:memos_flutter_app/features/memos/memos_list_screen.dart';
import 'package:memos_flutter_app/features/memos/memos_list_route_delegate.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_floating_actions.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_list_providers.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_provider.dart';
import 'package:memos_flutter_app/state/settings/location_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/memo_template_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/reminder_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/user_settings_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/logging_provider.dart';
import 'package:memos_flutter_app/state/system/notifications_provider.dart';
import 'package:memos_flutter_app/state/system/reminder_providers.dart';
import 'package:memos_flutter_app/state/system/scene_micro_guide_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async {
          switch (call.method) {
            case 'isMaximized':
              return false;
            case 'isVisible':
              return true;
            case 'isMinimized':
              return false;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'screen stays stable across memo stream append, mutate, and rebuild updates',
    (tester) async {
      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(memosStream: memosController.stream),
      );

      final firstMemo = _buildMemo(uid: 'memo-1', content: 'First memo');
      memosController.add(<LocalMemo>[firstMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      final secondMemo = _buildMemo(uid: 'memo-2', content: 'Second memo');
      memosController.add(<LocalMemo>[firstMemo, secondMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final updatedFirstMemo = _buildMemo(
        uid: 'memo-1',
        content: 'First memo updated',
      );
      memosController.add(<LocalMemo>[updatedFirstMemo, secondMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      memosController.add(<LocalMemo>[secondMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'mobile FAB tap opens note input and long press opens quick voice',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);
      final voiceOverlayCompleter = Completer<VoiceRecordResult?>();
      var noteInputOpenCount = 0;
      var voiceOverlayOpenCount = 0;
      VoiceRecordMode? capturedMode;
      VoiceRecordOverlayDragSession? capturedDragSession;

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(390, 844),
          enableCompose: true,
          showNoteInputSheet:
              (
                context, {
                String? initialText,
                List<String> initialAttachmentPaths = const <String>[],
                bool ignoreDraft = false,
              }) async {
                noteInputOpenCount++;
              },
          showVoiceRecordOverlay:
              (
                context, {
                bool autoStart = true,
                VoiceRecordOverlayDragSession? dragSession,
                VoiceRecordMode mode = VoiceRecordMode.standard,
              }) {
                voiceOverlayOpenCount++;
                capturedMode = mode;
                capturedDragSession = dragSession;
                return voiceOverlayCompleter.future;
              },
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Memo'),
      ]);
      await _pumpScreenFrames(tester);

      final fabFinder = find.byType(MemoFlowFab);
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder);
      await tester.pump();
      expect(noteInputOpenCount, 1);
      expect(voiceOverlayOpenCount, 0);

      final gesture = await tester.startGesture(
        tester.getCenter(fabFinder),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      expect(voiceOverlayOpenCount, 1);
      expect(capturedMode, VoiceRecordMode.quickFabCompose);
      expect(capturedDragSession, isNotNull);
      expect(noteInputOpenCount, 1);

      await gesture.moveBy(const Offset(84, -36));
      await tester.pump();
      expect(capturedDragSession!.offset, const Offset(84, -36));

      await gesture.up();
      await tester.pump();
      expect(capturedDragSession!.gestureEndSequence, 1);

      voiceOverlayCompleter.complete(null);
      await _pumpScreenFrames(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('desktop layout does not show mobile compose FAB', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(memosStream: memosController.stream, enableCompose: true),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Memo'),
    ]);
    await _pumpScreenFrames(tester);

    expect(find.byType(MemoFlowFab), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('windows home compose flag shows desktop resize handles', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Memo'),
    ]);
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-resizable-panel-right')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows without home compose flag keeps resize handles disabled',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(memosStream: memosController.stream, enableCompose: true),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Memo'),
      ]);
      await _pumpScreenFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('desktop-resizable-panel-right')),
        findsNothing,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('non-windows platform keeps desktop resize handles disabled', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Memo'),
    ]);
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-resizable-panel-right')),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('home compose drag persists layout and restores on rebuild', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);
    final devicePrefsRepo = _TestDevicePreferencesRepository(
      DevicePreferences.defaultsForLanguage(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
        devicePreferencesRepository: devicePrefsRepo,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Memo'),
    ]);
    await _pumpScreenFrames(tester);

    final topLeftFinder = find.byKey(
      const ValueKey<String>('desktop-resizable-panel-topLeft'),
    );
    final rightFinder = find.byKey(
      const ValueKey<String>('desktop-resizable-panel-right'),
    );
    final initialTopLeftRect = tester.getRect(topLeftFinder);
    final shell = tester.widget<DesktopResizablePanelShell>(
      find.byType(DesktopResizablePanelShell),
    );
    final updatedRect = DesktopResizablePanelRect(
      left: shell.rect.left + 56,
      top: shell.rect.top + 36,
      width: shell.rect.width - 56,
      height: shell.rect.height - 36,
    );

    shell.onChanged(updatedRect);
    shell.onChangeEnd(updatedRect);
    await _pumpScreenFrames(tester);

    final savedLayout = devicePrefsRepo.stored.homeInlineComposePanelLayout;
    expect(savedLayout, isNotNull);
    expect(savedLayout!.width, lessThan(620));
    expect(savedLayout.editorHeight, greaterThan(0));
    expect(savedLayout.xRatio, greaterThan(0));
    expect(savedLayout.yRatio, greaterThan(0));

    final draggedTopLeftRect = tester.getRect(topLeftFinder);
    final draggedRightRect = tester.getRect(rightFinder);
    expect(draggedTopLeftRect.left, greaterThan(initialTopLeftRect.left));
    expect(draggedTopLeftRect.top, greaterThan(initialTopLeftRect.top));

    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(<LocalMemo>[
          _buildMemo(uid: 'memo-1', content: 'Memo'),
        ]),
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
        devicePreferencesRepository: devicePrefsRepo,
      ),
    );
    await _pumpScreenFrames(tester);

    final restoredTopLeftRect = tester.getRect(topLeftFinder);
    final restoredRightRect = tester.getRect(rightFinder);
    expect(restoredTopLeftRect.left, closeTo(draggedTopLeftRect.left, 2));
    expect(restoredTopLeftRect.top, closeTo(draggedTopLeftRect.top, 2));
    expect(restoredRightRect.right, closeTo(draggedRightRect.right, 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('home compose restores saved ratio inside smaller viewport', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final devicePrefsRepo = _TestDevicePreferencesRepository(
      DevicePreferences.defaultsForLanguage(AppLanguage.en).copyWith(
        homeInlineComposePanelLayout:
            const HomeInlineComposePanelLayoutPreference(
              width: 560,
              editorHeight: 180,
              xRatio: 0.5,
              yRatio: 0.5,
            ),
      ),
    );

    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(<LocalMemo>[
          _buildMemo(uid: 'memo-1', content: 'Memo'),
        ]),
        screenSize: const Size(900, 1200),
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
        devicePreferencesRepository: devicePrefsRepo,
      ),
    );
    await _pumpScreenFrames(tester);
    await _pumpScreenFrames(tester);

    final topLeftFinder = find.byKey(
      const ValueKey<String>('desktop-resizable-panel-topLeft'),
    );
    final rightFinder = find.byKey(
      const ValueKey<String>('desktop-resizable-panel-right'),
    );

    var restoredTopLeftRect = tester.getRect(topLeftFinder);
    var restoredRightRect = tester.getRect(rightFinder);
    for (
      var attempt = 0;
      attempt < 6 &&
          (restoredTopLeftRect.left <= 8 || restoredTopLeftRect.top <= 2);
      attempt++
    ) {
      await _pumpScreenFrames(tester);
      restoredTopLeftRect = tester.getRect(topLeftFinder);
      restoredRightRect = tester.getRect(rightFinder);
    }

    expect(restoredTopLeftRect.left, greaterThan(8));
    expect(restoredTopLeftRect.top, greaterThan(2));
    expect(restoredRightRect.right, lessThanOrEqualTo(900));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop resizable compose bypasses desktop content max width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(<LocalMemo>[
          _buildMemo(uid: 'memo-1', content: 'Memo'),
        ]),
        screenSize: const Size(1400, 1200),
        showDrawer: true,
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
      ),
    );
    await _pumpScreenFrames(tester);

    final shell = tester.widget<DesktopResizablePanelShell>(
      find.byType(DesktopResizablePanelShell),
    );

    expect(shell.viewportSize.width, greaterThan(980));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('embedded bottom nav mode hides primary compose fab', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(<LocalMemo>[
          _buildMemo(uid: 'memo-1', content: 'First memo'),
        ]),
        screenSize: const Size(430, 900),
        enableCompose: true,
        showDrawer: true,
        presentation: HomeScreenPresentation.embeddedBottomNav,
        embeddedNavigationHost: _TestEmbeddedNavigationHost(),
        hidePrimaryComposeFab: true,
      ),
    );
    await _pumpScreenFrames(tester);

    expect(find.byType(MemoFlowFab), findsNothing);
  });
}

Future<void> _pumpScreenFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 32));
}

Widget _buildHarness({
  required Stream<List<LocalMemo>> memosStream,
  Size screenSize = const Size(1280, 1800),
  bool enableCompose = false,
  bool enableDesktopResizableHomeInlineCompose = false,
  _TestDevicePreferencesRepository? devicePreferencesRepository,
  bool showDrawer = false,
  HomeScreenPresentation presentation = HomeScreenPresentation.standalone,
  HomeEmbeddedNavigationHost? embeddedNavigationHost,
  bool hidePrimaryComposeFab = false,
  MemosListRouteNoteInputPresenter? showNoteInputSheet,
  MemosListRouteVoiceRecordOverlayPresenter? showVoiceRecordOverlay,
}) {
  final resolvedDevicePreferencesRepository =
      devicePreferencesRepository ??
      _TestDevicePreferencesRepository(
        DevicePreferences.defaultsForLanguage(AppLanguage.en),
      );
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(_MemorySecureStorage()),
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref),
      ),
      devicePreferencesProvider.overrideWith(
        (ref) => _TestDevicePreferencesController(
          ref,
          resolvedDevicePreferencesRepository,
        ),
      ),
      locationSettingsProvider.overrideWith(
        (ref) => _TestLocationSettingsController(ref),
      ),
      reminderSettingsProvider.overrideWith(
        (ref) => _TestReminderSettingsController(ref),
      ),
      memoTemplateSettingsProvider.overrideWith(
        (ref) => _TestMemoTemplateSettingsController(ref),
      ),
      sceneMicroGuideProvider.overrideWith(
        (ref) => _TestSceneMicroGuideController(),
      ),
      syncCoordinatorProvider.overrideWith((ref) => _TestSyncCoordinator()),
      memosStreamProvider.overrideWith((ref, query) => memosStream),
      shortcutsProvider.overrideWith((ref) async => const []),
      tagStatsProvider.overrideWith((ref) => Stream.value(const <TagStat>[])),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
      memoReminderMapProvider.overrideWith(
        (ref) => const <String, MemoReminder>{},
      ),
      currentLocalLibraryProvider.overrideWith((ref) => null),
      memosListOutboxStatusProvider.overrideWith(
        (ref) => Stream.value(const OutboxMemoStatus.empty()),
      ),
      memosListNormalMemoCountProvider.overrideWith((ref) => Stream.value(1)),
      userGeneralSettingProvider.overrideWith(
        (ref) async => const UserGeneralSetting(),
      ),
      syncQueueProgressTrackerProvider.overrideWith(
        (ref) => SyncQueueProgressTracker(),
      ),
      unreadNotificationCountProvider.overrideWith((ref) => 0),
      syncQueuePendingCountProvider.overrideWith((ref) => Stream.value(0)),
      syncQueueAttentionCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: MemosListScreen(
            title: 'Memos',
            state: 'NORMAL',
            showDrawer: showDrawer,
            enableCompose: enableCompose,
            enableDesktopResizableHomeInlineCompose:
                enableDesktopResizableHomeInlineCompose,
            enableSearch: false,
            enableTitleMenu: false,
            showPillActions: false,
            presentation: presentation,
            embeddedNavigationHost: embeddedNavigationHost,
            hidePrimaryComposeFab: hidePrimaryComposeFab,
            showNoteInputSheet: showNoteInputSheet,
            showVoiceRecordOverlay: showVoiceRecordOverlay,
          ),
        ),
      ),
    ),
  );
}

LocalMemo _buildMemo({required String uid, required String content}) {
  final now = DateTime(2025, 1, 2, 3, 4, 5);
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
    attachments: const <Attachment>[],
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
  );
}

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

class _TestEmbeddedNavigationHost implements HomeEmbeddedNavigationHost {
  @override
  void handleBackToPrimaryDestination(BuildContext context) {}

  @override
  void handleDrawerDestination(BuildContext context, destination) {}

  @override
  void handleDrawerTag(BuildContext context, String tag) {}

  @override
  void handleOpenNotifications(BuildContext context) {}

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {}

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {}
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(
          AppSessionState(accounts: [], currentKey: 'test-account'),
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

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository()
    : super(_MemorySecureStorage(), accountKey: null);

  @override
  Future<void> clear() async {}

  @override
  Future<AppPreferences> read() async {
    return AppPreferences.defaultsForLanguage(AppLanguage.en);
  }

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
  }

  @override
  Future<void> write(AppPreferences prefs) async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref)
    : super(
        ref,
        _TestAppPreferencesRepository(),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      );
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository(this._stored)
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _stored;

  DevicePreferences get stored => _stored;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<DevicePreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(DevicePreferences prefs) async {
    _stored = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  // ignore: use_super_parameters
  _TestDevicePreferencesController(
    Ref ref,
    _TestDevicePreferencesRepository repository,
  ) : super(
        ref,
        repository,
        onLoaded: () {
          ref.read(devicePreferencesLoadedProvider.notifier).state = true;
        },
      );
}

class _TestLocationSettingsController extends LocationSettingsController {
  _TestLocationSettingsController(Ref ref)
    : super(ref, _TestLocationSettingsRepository());
}

class _TestLocationSettingsRepository extends LocationSettingsRepository {
  _TestLocationSettingsRepository()
    : super(_MemorySecureStorage(), accountKey: 'test-account');

  @override
  Future<void> clear() async {}

  @override
  Future<LocationSettings> read() async => LocationSettings.defaults;

  @override
  Future<void> write(LocationSettings settings) async {}
}

class _TestReminderSettingsController extends ReminderSettingsController {
  _TestReminderSettingsController(Ref ref)
    : super(
        ref,
        _TestReminderSettingsRepository(),
        onLoaded: () {
          ref.read(reminderSettingsLoadedProvider.notifier).state = true;
        },
      );
}

class _TestReminderSettingsRepository extends ReminderSettingsRepository {
  _TestReminderSettingsRepository()
    : super(_MemorySecureStorage(), accountKey: null);

  @override
  Future<ReminderSettings?> read() async {
    return ReminderSettings.defaultsFor(AppLanguage.en);
  }

  @override
  Future<void> write(ReminderSettings settings) async {}
}

class _TestMemoTemplateSettingsController
    extends MemoTemplateSettingsController {
  _TestMemoTemplateSettingsController(Ref ref)
    : super(ref, _TestMemoTemplateSettingsRepository());
}

class _TestMemoTemplateSettingsRepository
    extends MemoTemplateSettingsRepository {
  _TestMemoTemplateSettingsRepository()
    : super(_MemorySecureStorage(), accountKey: 'test-account');

  @override
  Future<MemoTemplateSettings> read() async => MemoTemplateSettings.defaults;

  @override
  Future<void> write(MemoTemplateSettings settings) async {}

  @override
  Future<void> clear() async {}
}

class _TestSceneMicroGuideController extends SceneMicroGuideController {
  _TestSceneMicroGuideController()
    : super(SceneMicroGuideRepository(_MemorySecureStorage()));
}

class _TestSyncCoordinator extends SyncCoordinator {
  _TestSyncCoordinator()
    : super(
        SyncDependencies(
          webDavSyncService: _FakeWebDavSyncService(),
          webDavBackupService: _FakeWebDavBackupService(),
          webDavBackupStateRepository: _FakeWebDavBackupStateRepository(),
          readWebDavSettings: () => WebDavSettings.defaults,
          readCurrentAccountKey: () => null,
          readCurrentAccount: () => null,
          readCurrentLocalLibrary: () => null,
          readDatabase: () => throw UnsupportedError('unused in screen test'),
          runMemosSync: () async => const MemoSyncSuccess(),
        ),
      );
}

class _FakeWebDavSyncService implements WebDavSyncService {
  @override
  Future<WebDavSyncMeta?> cleanDeprecatedRemotePlainFiles({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return null;
  }

  @override
  Future<WebDavSyncMeta?> fetchRemoteMeta({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return null;
  }

  @override
  Future<WebDavSyncResult> syncNow({
    required WebDavSettings settings,
    required String? accountKey,
    Map<String, bool>? conflictResolutions,
  }) async {
    return const WebDavSyncSuccess();
  }

  @override
  Future<WebDavConnectionTestResult> testConnection({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return const WebDavConnectionTestResult.success();
  }
}

class _FakeWebDavBackupService implements WebDavBackupService {
  @override
  Future<WebDavBackupResult> backupNow({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    String? password,
    bool manual = true,
    Uri? attachmentBaseUrl,
    String? attachmentAuthHeader,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    return const WebDavBackupSuccess();
  }

  @override
  Future<WebDavExportCleanupStatus> cleanPlainExport({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
    return WebDavExportCleanupStatus.notFound;
  }

  @override
  Future<WebDavExportStatus> fetchExportStatus({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
    return const WebDavExportStatus(
      webDavConfigured: false,
      encSignature: null,
      plainSignature: null,
      plainDetected: false,
      plainDeprecated: false,
      plainDetectedAt: null,
      plainRemindAfter: null,
      lastExportSuccessAt: null,
      lastUploadSuccessAt: null,
    );
  }

  @override
  Future<String?> setupBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return null;
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return const <WebDavBackupSnapshotInfo>[];
  }

  @override
  Future<String> recoverBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    return '';
  }

  @override
  Future<WebDavRestoreResult> restorePlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return const WebDavRestoreSkipped();
  }

  @override
  Future<WebDavRestoreResult> restorePlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return const WebDavRestoreSkipped();
  }

  @override
  Future<WebDavRestoreResult> restoreSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return const WebDavRestoreSkipped();
  }

  @override
  Future<WebDavRestoreResult> restoreSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return const WebDavRestoreSkipped();
  }

  @override
  Future<SyncError?> verifyBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
    bool deep = false,
  }) async {
    return null;
  }
}

class _FakeWebDavBackupStateRepository implements WebDavBackupStateRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<WebDavBackupState> read() async => WebDavBackupState.empty;

  @override
  Future<void> write(WebDavBackupState state) async {}
}
