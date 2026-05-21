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
import 'package:memos_flutter_app/core/app_motion.dart';
import 'package:memos_flutter_app/core/platform_layout.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_adapter.dart';
import 'package:memos_flutter_app/data/ai/ai_semantic_memo_search_service.dart';
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
import 'package:memos_flutter_app/features/memos/memos_list_floating_collapse_controller.dart';
import 'package:memos_flutter_app/features/memos/memos_list_screen.dart';
import 'package:memos_flutter_app/features/memos/memos_list_route_delegate.dart';
import 'package:memos_flutter_app/features/memos/memos_list_viewport_coordinator.dart';
import 'package:memos_flutter_app/features/memos/memo_detail_screen.dart';
import 'package:memos_flutter_app/features/memos/memo_editor_screen.dart';
import 'package:memos_flutter_app/features/memos/widgets/floating_collapse_button.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_floating_actions.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_list_providers.dart';
import 'package:memos_flutter_app/state/memos/desktop_memo_preview_session.dart';
import 'package:memos_flutter_app/state/memos/desktop_home_pane_state.dart';
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

  testWidgets('windows wide layout opens desktop preview pane on memo tap', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(
        uid: 'memo-1',
        content:
            'First desktop preview memo\n\n'
            '<img src="https://example.com/clip.jpg">\n\n'
            '${buildThirdPartyShareMemoMarker()}',
      ),
      _buildMemo(uid: 'memo-2', content: 'Second desktop preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(
      find.textContaining('First desktop preview memo', findRichText: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    final paneFinder = find.byKey(
      const ValueKey<String>('desktop-memo-preview-pane'),
    );
    Finder previewText(String text) => find.descendant(
      of: paneFinder,
      matching: find.textContaining(text, findRichText: true),
    );

    expect(paneFinder, findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey<String>('desktop-memo-preview-edit')),
          )
          .onPressed,
      isNull,
    );
    expect(previewText('First desktop preview memo'), findsNothing);
    expect(find.byType(MemoDetailScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(previewText('First desktop preview memo'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await _pumpScreenFrames(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MemosListScreen)),
    );
    var previewSession = container.read(desktopMemoPreviewSessionProvider);
    expect(paneFinder, findsOneWidget);
    expect(previewSession.phase, DesktopMemoPreviewPhase.ready);
    expect(previewSession.data?.memo.uid, 'memo-1');

    await tester.tap(find.byType(MemoListCard).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(paneFinder, findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey<String>('desktop-memo-preview-edit')),
          )
          .onPressed,
      isNull,
    );
    expect(previewText('First desktop preview memo'), findsNothing);
    expect(previewText('Second desktop preview memo'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(previewText('Second desktop preview memo'), findsNothing);

    await tester.pump(const Duration(milliseconds: 80));
    await _pumpScreenFrames(tester);

    previewSession = container.read(desktopMemoPreviewSessionProvider);
    expect(previewSession.phase, DesktopMemoPreviewPhase.ready);
    expect(previewSession.data?.memo.uid, 'memo-2');
    expect(previewText('Second desktop preview memo'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-preview-pane-toggle')),
    );
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
      findsOneWidget,
    );
    expect(
      container.read(desktopHomePaneStateProvider).previewVisible,
      isFalse,
    );
    expect(
      container.read(desktopHomePaneStateProvider).selectedMemoUid,
      isNull,
    );
    expect(
      tester.widget<MemoListCard>(find.byType(MemoListCard).at(1)).selected,
      isFalse,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('windows wide layout cached preview reopen still shows loader', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Cached desktop preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    final paneFinder = find.byKey(
      const ValueKey<String>('desktop-memo-preview-pane'),
    );
    Finder previewText() => find.descendant(
      of: paneFinder,
      matching: find.textContaining(
        'Cached desktop preview memo',
        findRichText: true,
      ),
    );

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(AppMotion.desktopPreviewInitialLoaderMin);
    await tester.pump(AppMotion.desktopPreviewContentReveal);
    await _pumpScreenFrames(tester);

    expect(previewText(), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-preview-pane-toggle')),
    );
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(paneFinder, findsOneWidget);
    expect(previewText(), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey<String>('desktop-memo-preview-edit')),
          )
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(previewText(), findsNothing);

    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(AppMotion.desktopPreviewInitialLoaderMin);
    await tester.pump(AppMotion.desktopPreviewContentReveal);
    await _pumpScreenFrames(tester);

    expect(previewText(), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('windows wide layout preview edit button opens memo editor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Preview edit target memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(AppMotion.desktopPreviewInitialLoaderMin);
    await tester.pump(AppMotion.desktopPreviewContentReveal);
    await _pumpScreenFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop-memo-preview-edit')),
    );
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('windows-desktop-modal-surface')),
      findsOneWidget,
    );
    expect(find.byType(MemoEditorScreen), findsOneWidget);
    expect(find.byType(MemoDetailScreen), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows wide layout starts preview warmup on press down and opens after hold threshold',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Press threshold preview memo'),
      ]);
      await _pumpScreenFrames(tester);

      final paneFinder = find.byKey(
        const ValueKey<String>('desktop-memo-preview-pane'),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MemoListCard).first),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await tester.pump();

      expect(
        container.read(desktopMemoPreviewSessionProvider).requestedMemo?.uid,
        'memo-1',
      );
      expect(
        container.read(desktopHomePaneStateProvider).previewVisible,
        isFalse,
      );

      await tester.pump(const Duration(milliseconds: 60));
      expect(
        container.read(desktopHomePaneStateProvider).previewVisible,
        isFalse,
      );

      await tester.pump(const Duration(milliseconds: 40));
      expect(
        container.read(desktopHomePaneStateProvider).previewVisible,
        isTrue,
      );
      expect(paneFinder, findsOneWidget);

      await gesture.up();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout cancels pending press preview before threshold',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Cancelled threshold preview memo'),
      ]);
      await _pumpScreenFrames(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MemoListCard).first),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await tester.pump();
      expect(
        container.read(desktopMemoPreviewSessionProvider).requestedMemo?.uid,
        'memo-1',
      );

      await tester.pump(const Duration(milliseconds: 40));
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        container.read(desktopHomePaneStateProvider).previewVisible,
        isFalse,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('windows wide layout Enter opens full detail for selected memo', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Enter preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpScreenFrames(tester);

    expect(find.byType(MemoDetailScreen), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows wide layout inline compose Enter does not open selected memo',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
          enableCompose: true,
          enableDesktopResizableHomeInlineCompose: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Inline compose Enter memo'),
      ]);
      await _pumpScreenFrames(tester);

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );
      expect(
        container.read(desktopHomePaneStateProvider).selectedMemoUid,
        'memo-1',
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
        findsOneWidget,
      );

      final editorFinder = find.byKey(
        const ValueKey<String>('memos-inline-compose-text-field'),
      );
      await tester.tap(editorFinder);
      await tester.enterText(editorFinder, 'Draft line');
      await tester.pump();
      expect(
        tester.widget<TextField>(editorFinder).focusNode?.hasFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoDetailScreen), findsNothing);
      expect(
        tester.widget<TextField>(editorFinder).controller?.text,
        contains('Draft line'),
      );
      expect(
        tester.widget<TextField>(editorFinder).focusNode?.hasFocus,
        isTrue,
      );
      expect(
        container.read(desktopHomePaneStateProvider).selectedMemoUid,
        'memo-1',
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout clicking selected memo clears preview without draft loss',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
          enableCompose: true,
          enableDesktopResizableHomeInlineCompose: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Deselect preview memo'),
      ]);
      await _pumpScreenFrames(tester);

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );
      expect(
        container.read(desktopHomePaneStateProvider).selectedMemoUid,
        'memo-1',
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
        findsOneWidget,
      );

      final editorFinder = find.byKey(
        const ValueKey<String>('memos-inline-compose-text-field'),
      );
      await tester.tap(editorFinder);
      await tester.enterText(editorFinder, 'Draft survives deselect');
      await tester.pump();

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      final paneState = container.read(desktopHomePaneStateProvider);
      expect(paneState.selectedMemoUid, isNull);
      expect(paneState.previewVisible, isFalse);
      expect(paneState.secondaryPaneMode, DesktopHomeSecondaryPaneMode.none);
      expect(
        tester.widget<TextField>(editorFinder).controller?.text,
        'Draft survives deselect',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _pumpScreenFrames(tester);
      expect(find.byType(MemoDetailScreen), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('windows wide layout detail edit returns to home compose pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Wide detail edit memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpScreenFrames(tester);

    final fullDetailEditButton = find.descendant(
      of: find.byType(MemoDetailScreen).last,
      matching: find.byIcon(Icons.edit),
    );
    expect(fullDetailEditButton, findsOneWidget);

    await tester.tap(fullDetailEditButton);
    await _pumpScreenFrames(tester);
    await _pumpScreenFrames(tester);

    expect(find.byType(MemoDetailScreen), findsNothing);
    expect(find.byType(MemoEditorScreen), findsOneWidget);
    expect(find.byType(MemoListCard), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows expanded layout detail edit opens centered editor surface',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1280, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Expanded detail edit memo'),
      ]);
      await _pumpScreenFrames(tester);

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      final detailEditButton = find.descendant(
        of: find.byType(MemoDetailScreen),
        matching: find.byIcon(Icons.edit),
      );
      expect(detailEditButton, findsOneWidget);

      await tester.tap(detailEditButton);
      await _pumpScreenFrames(tester);
      await _pumpScreenFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('windows-desktop-modal-surface')),
        findsOneWidget,
      );
      expect(find.byType(MemoEditorScreen), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('windows wide layout secondary click opens memo context menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Context menu memo'),
    ]);
    await _pumpScreenFrames(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MemoListCard).first),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS desktop secondary click opens memo context menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1280, 1200),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'macOS context menu memo'),
    ]);
    await _pumpScreenFrames(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MemoListCard).first),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS desktop memo cards use shared desktop max width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1200),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'macOS bounded memo card'),
    ]);
    await _pumpScreenFrames(tester);

    expect(
      tester.getRect(find.byType(MemoListCard).first).width,
      lessThanOrEqualTo(kMemoFlowDesktopMemoCardMaxWidth),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS wide layout opens desktop preview pane on memo tap', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'macOS desktop preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    final paneFinder = find.byKey(
      const ValueKey<String>('desktop-memo-preview-pane'),
    );
    expect(paneFinder, findsOneWidget);
    expect(find.byType(MemoDetailScreen), findsNothing);

    await tester.pump(AppMotion.desktopPreviewInitialLoaderMin);
    await tester.pump(AppMotion.desktopPreviewContentReveal);
    await _pumpScreenFrames(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MemosListScreen)),
    );
    final previewSession = container.read(desktopMemoPreviewSessionProvider);
    expect(previewSession.phase, DesktopMemoPreviewPhase.ready);
    expect(previewSession.data?.memo.uid, 'memo-1');
    expect(
      tester.widget<MemoListCard>(find.byType(MemoListCard).first).selected,
      isTrue,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('windows wide layout persists preview pane width changes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);
    final devicePrefsRepo = _TestDevicePreferencesRepository(
      DevicePreferences.defaultsForLanguage(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
        devicePreferencesRepository: devicePrefsRepo,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Resizable preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    final originalWidth = tester
        .getRect(
          find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
        )
        .width;

    await tester.drag(
      find.byKey(
        const ValueKey<String>('windows-desktop-secondary-pane-resizer'),
      ),
      const Offset(-80, 0),
    );
    await _pumpScreenFrames(tester);

    expect(
      devicePrefsRepo.stored.desktopHomeLayoutPreference.secondaryPaneWidth,
      greaterThan(420),
    );

    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(<LocalMemo>[
          _buildMemo(uid: 'memo-1', content: 'Resizable preview memo'),
        ]),
        screenSize: const Size(1600, 1800),
        showDrawer: true,
        devicePreferencesRepository: devicePrefsRepo,
      ),
    );
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    final restoredWidth = tester
        .getRect(
          find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
        )
        .width;
    expect(restoredWidth, greaterThan(originalWidth));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('windows wide layout closes preview pane on escape', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Escape preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpScreenFrames(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MemosListScreen)),
    );
    expect(
      container.read(desktopHomePaneStateProvider).previewVisible,
      isFalse,
    );
    expect(
      container.read(desktopHomePaneStateProvider).selectedMemoUid,
      isNull,
    );
    expect(
      tester.widget<MemoListCard>(find.byType(MemoListCard).first).selected,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpScreenFrames(tester);
    expect(find.byType(MemoDetailScreen), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('windows wide layout preview close button clears selection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Close preview button memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MemosListScreen)),
    );
    expect(
      container.read(desktopHomePaneStateProvider).selectedMemoUid,
      'memo-1',
    );
    expect(
      find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
      findsOneWidget,
    );

    final closeButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('desktop-memo-preview-close')),
    );
    expect(closeButton.onPressed, isNotNull);
    closeButton.onPressed!();
    await _pumpScreenFrames(tester);

    final paneState = container.read(desktopHomePaneStateProvider);
    expect(paneState.selectedMemoUid, isNull);
    expect(paneState.previewVisible, isFalse);
    expect(paneState.secondaryPaneMode, DesktopHomeSecondaryPaneMode.none);
    expect(
      tester.widget<MemoListCard>(find.byType(MemoListCard).first).selected,
      isFalse,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows wide layout escape preview close preserves inline compose draft',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
          enableCompose: true,
          enableDesktopResizableHomeInlineCompose: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Draft close preview memo'),
      ]);
      await _pumpScreenFrames(tester);

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      final editorFinder = find.byKey(
        const ValueKey<String>('memos-inline-compose-text-field'),
      );
      await tester.tap(editorFinder);
      await tester.enterText(editorFinder, 'Draft survives preview close');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpScreenFrames(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );
      final paneState = container.read(desktopHomePaneStateProvider);
      expect(paneState.selectedMemoUid, isNull);
      expect(paneState.previewVisible, isFalse);
      expect(paneState.secondaryPaneMode, DesktopHomeSecondaryPaneMode.none);
      expect(
        tester.widget<TextField>(editorFinder).controller?.text,
        'Draft survives preview close',
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout closes preview when selected memo leaves results',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Selected preview memo'),
        _buildMemo(uid: 'memo-2', content: 'Replacement preview memo'),
      ]);
      await _pumpScreenFrames(tester);

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
        findsOneWidget,
      );

      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-2', content: 'Replacement preview memo'),
      ]);
      await _pumpScreenFrames(tester);
      await _pumpScreenFrames(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );
      expect(
        container.read(desktopHomePaneStateProvider).previewVisible,
        isFalse,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout list scroll does not auto open preview pane',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(
        List<LocalMemo>.generate(
          12,
          (index) => _buildMemo(
            uid: 'memo-$index',
            content: 'Scrollable preview memo $index',
          ),
        ),
      );
      await _pumpScreenFrames(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await _pumpScreenFrames(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MemosListScreen)),
      );
      expect(
        container.read(desktopHomePaneStateProvider).previewVisible,
        isFalse,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('windows wide layout list scroll keeps preview pane open', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(
      List<LocalMemo>.generate(
        12,
        (index) => _buildMemo(
          uid: 'memo-$index',
          content: 'Scrollable active preview memo $index',
        ),
      ),
    );
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
      findsOneWidget,
    );

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows wide layout floating collapse button collapses active memo via screen wiring',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: _buildLongPlainTextMemoContent()),
      ]);
      await _pumpScreenFrames(tester);

      final collapseFinder = find.descendant(
        of: find.byType(MemoListCard).first,
        matching: find.widgetWithText(TextButton, 'Collapse'),
      );
      final memoCardState =
          tester.state(find.byType(MemoListCard).first) as dynamic;
      memoCardState.debugExpandForTest();
      await _pumpScreenFrames(tester);
      expect(collapseFinder, findsOneWidget);

      final controller = _screenFloatingCollapseController(tester);
      controller.upsertGeometry(
        'memo-1',
        const MemoFloatingCollapseGeometry(
          cardTopOffset: 0,
          cardBottomOffset: 1600,
          toggleTopOffset: 1200,
          toggleBottomOffset: 1240,
        ),
      );
      controller.updateViewportMetrics(
        _viewportMetrics(pixels: 0, maxScrollExtent: 2400, viewport: 500),
      );
      await tester.pump();

      expect(_floatingCollapseButton(tester).visible, isTrue);
      expect(
        find.descendant(
          of: find.byType(MemoFloatingCollapseButton),
          matching: find.byIcon(Icons.unfold_less_rounded),
        ),
        findsOneWidget,
      );

      _floatingCollapseButton(tester).onPressed();
      await _pumpScreenFrames(tester);

      expect(collapseFinder, findsNothing);
      expect(
        find.descendant(
          of: find.byType(MemoListCard).first,
          matching: find.widgetWithText(TextButton, 'Expand'),
        ),
        findsOneWidget,
      );
      expect(_floatingCollapseButton(tester).visible, isFalse);
      expect(controller.value.memoUid, isNull);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout floating collapse restores active memo scroll anchor',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 700),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-a', content: _buildLongPlainTextMemoContent()),
        _buildMemo(uid: 'memo-b', content: _buildSixLineMemoContent('B')),
        _buildMemo(uid: 'memo-c', content: _buildSixLineMemoContent('C')),
      ]);
      await _pumpScreenFrames(tester);

      final firstCardFinder = find.byType(MemoListCard).first;
      final memoCardState = tester.state(firstCardFinder) as dynamic;
      memoCardState.debugExpandForTest();
      await _pumpScreenFrames(tester);

      final scrollController = _screenScrollController(tester);
      final anchor = memoCardState.currentCardTopScrollOffset() as double?;
      expect(anchor, isNotNull);

      final deepOffset = (anchor! + 1800)
          .clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          )
          .toDouble();
      expect(deepOffset, greaterThan(anchor + 50));
      scrollController.jumpTo(deepOffset);
      await _pumpScreenFrames(tester);
      expect(scrollController.offset, closeTo(deepOffset, 0.1));
      final controller = _screenFloatingCollapseController(tester);
      controller.upsertGeometry(
        'memo-a',
        MemoFloatingCollapseGeometry(
          cardTopOffset: anchor,
          cardBottomOffset: anchor + 2400,
          toggleTopOffset: anchor + 2200,
          toggleBottomOffset: anchor + 2240,
        ),
      );
      controller.updateViewportMetrics(
        _viewportMetrics(
          pixels: scrollController.offset,
          maxScrollExtent: scrollController.position.maxScrollExtent,
          viewport: scrollController.position.viewportDimension,
        ),
      );
      await tester.pump();
      expect(_floatingCollapseButton(tester).visible, isTrue);

      _floatingCollapseButton(tester).onPressed();
      await _pumpScreenFrames(tester);

      final expectedOffset = anchor
          .clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          )
          .toDouble();
      expect(scrollController.position.maxScrollExtent, greaterThan(100));
      expect(scrollController.offset, closeTo(expectedOffset, 1));
      expect(tester.getRect(firstCardFinder).bottom, greaterThan(0));
      expect(tester.getRect(firstCardFinder).top, lessThan(700));
      expect(
        find.descendant(
          of: firstCardFinder,
          matching: find.widgetWithText(TextButton, 'Expand'),
        ),
        findsOneWidget,
      );
      expect(_floatingCollapseButton(tester).visible, isFalse);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout floating collapse ignores stale active memo safely',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 900),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Visible memo remains mounted.'),
      ]);
      await _pumpScreenFrames(tester);

      final controller = _screenFloatingCollapseController(tester);
      controller.upsertGeometry(
        'missing-memo',
        const MemoFloatingCollapseGeometry(
          cardTopOffset: 0,
          cardBottomOffset: 1600,
          toggleTopOffset: 1200,
          toggleBottomOffset: 1240,
        ),
      );
      controller.updateViewportMetrics(
        _viewportMetrics(pixels: 0, maxScrollExtent: 2400, viewport: 500),
      );
      await tester.pump();

      expect(_floatingCollapseButton(tester).visible, isTrue);
      expect(controller.value.memoUid, 'missing-memo');

      _floatingCollapseButton(tester).onPressed();
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsOneWidget);
      expect(controller.value.memoUid, 'missing-memo');
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'windows wide layout prunes floating collapse candidate when active memo leaves results',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      final activeMemo = _buildMemo(
        uid: 'memo-1',
        content: _buildLongPlainTextMemoContent(),
      );
      final replacementMemo = _buildMemo(
        uid: 'memo-2',
        content: 'Replacement memo remains visible.',
      );

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1600, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[activeMemo, replacementMemo]);
      await _pumpScreenFrames(tester);

      final collapseFinder = find.descendant(
        of: find.byType(MemoListCard).first,
        matching: find.widgetWithText(TextButton, 'Collapse'),
      );
      final memoCardState =
          tester.state(find.byType(MemoListCard).first) as dynamic;
      memoCardState.debugExpandForTest();
      await _pumpScreenFrames(tester);
      expect(collapseFinder, findsOneWidget);

      final controller = _screenFloatingCollapseController(tester);
      controller.upsertGeometry(
        'memo-1',
        const MemoFloatingCollapseGeometry(
          cardTopOffset: 0,
          cardBottomOffset: 1600,
          toggleTopOffset: 1200,
          toggleBottomOffset: 1240,
        ),
      );
      controller.updateViewportMetrics(
        _viewportMetrics(pixels: 0, maxScrollExtent: 2400, viewport: 500),
      );
      await tester.pump();

      expect(_floatingCollapseButton(tester).visible, isTrue);
      expect(controller.value.memoUid, 'memo-1');

      memosController.add(<LocalMemo>[replacementMemo]);
      await _pumpScreenFrames(tester);
      await _pumpScreenFrames(tester);

      expect(_floatingCollapseButton(tester).visible, isFalse);
      expect(controller.value.memoUid, isNull);
      expect(find.byType(MemoListCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('windows narrow layout still pushes memo detail route', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1280, 1800),
        showDrawer: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Narrow route memo'),
    ]);
    await _pumpScreenFrames(tester);

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    expect(find.byType(MemoDetailScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MemosListScreen)),
    );
    expect(
      container.read(desktopHomePaneStateProvider).previewVisible,
      isFalse,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'windows expanded layout can open preview pane from command bar',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(
          memosStream: memosController.stream,
          screenSize: const Size(1280, 1800),
          showDrawer: true,
        ),
      );
      memosController.add(<LocalMemo>[
        _buildMemo(uid: 'memo-1', content: 'Expanded preview memo'),
      ]);
      await _pumpScreenFrames(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-preview-pane-toggle')),
      );
      await _pumpScreenFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('desktop-memo-preview-empty-pane')),
        findsOneWidget,
      );

      await tester.tap(find.byType(MemoListCard).first);
      await tester.pump(const Duration(milliseconds: 420));
      await _pumpScreenFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
        findsOneWidget,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('windows home compose mode still allows opening preview pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memosController = StreamController<List<LocalMemo>>.broadcast();
    addTearDown(memosController.close);

    await tester.pumpWidget(
      _buildHarness(
        memosStream: memosController.stream,
        screenSize: const Size(1600, 1800),
        showDrawer: true,
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
      ),
    );
    memosController.add(<LocalMemo>[
      _buildMemo(uid: 'memo-1', content: 'Home compose preview memo'),
    ]);
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-resizable-panel-right')),
      findsOneWidget,
    );

    await tester.tap(find.byType(MemoListCard).first);
    await tester.pump(const Duration(milliseconds: 420));
    await _pumpScreenFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('desktop-memo-preview-pane')),
      findsOneWidget,
    );
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
    expect(
      draggedTopLeftRect.top,
      greaterThanOrEqualTo(initialTopLeftRect.top),
    );

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

    final shell = tester.widget<DesktopResizablePanelShell>(
      find.byType(DesktopResizablePanelShell),
    );

    expect(restoredTopLeftRect.left, greaterThan(8));
    expect(restoredTopLeftRect.top, greaterThan(2));
    expect(restoredRightRect.right, lessThanOrEqualTo(900));
    expect(
      shell.viewportSize.height,
      greaterThanOrEqualTo(shell.rect.bottom + shell.hitZoneExtent),
    );

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

  testWidgets('AI search starts directly when preflight needs no indexing', (
    tester,
  ) async {
    var aiSearchCalls = 0;
    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(const <LocalMemo>[]),
        overrides: [
          aiSearchIndexPreflightProvider.overrideWith(
            (ref, query) async => AiSemanticMemoSearchIndexPreflight.empty,
          ),
          aiSearchMemosProvider.overrideWith((ref, query) async {
            aiSearchCalls += 1;
            return const <LocalMemo>[];
          }),
        ],
      ),
    );
    await _pumpScreenFrames(tester);

    final screenState = _screenState(tester);
    (screenState.debugSearchController as TextEditingController).text =
        'what to eat';
    screenState.debugStartAiSearch();
    await _pumpScreenFrames(tester);

    expect(screenState.debugAiSearchActive as bool, isTrue);
    expect(find.text('Build AI search index?'), findsNothing);
    expect(aiSearchCalls, greaterThan(0));
  });

  testWidgets('AI search index prompt cancel keeps keyword search active', (
    tester,
  ) async {
    var aiSearchCalls = 0;
    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(const <LocalMemo>[]),
        overrides: [
          aiSearchIndexPreflightProvider.overrideWith(
            (ref, query) async => _preflight(needsIndexing: true),
          ),
          aiSearchMemosProvider.overrideWith((ref, query) async {
            aiSearchCalls += 1;
            return const <LocalMemo>[];
          }),
        ],
      ),
    );
    await _pumpScreenFrames(tester);

    final screenState = _screenState(tester);
    (screenState.debugSearchController as TextEditingController).text =
        'what to eat';
    screenState.debugStartAiSearch();
    await tester.pump();
    await tester.pump();

    expect(find.text('Build AI search index?'), findsOneWidget);
    expect(find.text('Estimated indexing tokens: 128'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await _pumpScreenFrames(tester);

    expect(screenState.debugAiSearchActive as bool, isFalse);
    expect(aiSearchCalls, 0);
  });

  testWidgets('AI search index prompt continue starts AI search', (
    tester,
  ) async {
    var aiSearchCalls = 0;
    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(const <LocalMemo>[]),
        overrides: [
          aiSearchIndexPreflightProvider.overrideWith(
            (ref, query) async => _preflight(needsIndexing: true),
          ),
          aiSearchMemosProvider.overrideWith((ref, query) async {
            aiSearchCalls += 1;
            return const <LocalMemo>[];
          }),
        ],
      ),
    );
    await _pumpScreenFrames(tester);

    final screenState = _screenState(tester);
    (screenState.debugSearchController as TextEditingController).text =
        'what to eat';
    screenState.debugStartAiSearch();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Continue with AI search'));
    await _pumpScreenFrames(tester);

    expect(screenState.debugAiSearchActive as bool, isTrue);
    expect(aiSearchCalls, greaterThan(0));
  });

  testWidgets('AI search missing config keeps existing recovery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        memosStream: Stream.value(const <LocalMemo>[]),
        overrides: [
          aiSearchIndexPreflightProvider.overrideWith((ref, query) async {
            throw const AiSemanticMemoSearchConfigurationException(
              'Configure an embedding model before using AI search.',
            );
          }),
          aiSearchMemosProvider.overrideWith((ref, query) async {
            throw const AiSemanticMemoSearchConfigurationException(
              'Configure an embedding model before using AI search.',
            );
          }),
        ],
      ),
    );
    await _pumpScreenFrames(tester);

    final screenState = _screenState(tester);
    (screenState.debugSearchController as TextEditingController).text =
        'what to eat';
    screenState.debugStartAiSearch();
    await _pumpScreenFrames(tester);

    expect(find.text('Build AI search index?'), findsNothing);
    expect(find.text('AI search needs an embedding model'), findsOneWidget);
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
  List<Override> overrides = const <Override>[],
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
      ...overrides,
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

String _buildLongPlainTextMemoContent() {
  return List<String>.generate(
    220,
    (index) =>
        'Long memo paragraph $index with enough words to keep the '
        'expanded body tall for floating collapse testing.',
  ).join('\n\n');
}

String _buildSixLineMemoContent(String label) {
  return List<String>.generate(
    6,
    (index) => 'Memo $label line $index keeps the collapsed list scrollable.',
  ).join('\n');
}

ScrollController _screenScrollController(WidgetTester tester) {
  return tester
      .widget<CustomScrollView>(find.byType(CustomScrollView).first)
      .controller!;
}

MemoFloatingCollapseButton _floatingCollapseButton(WidgetTester tester) {
  return tester.widget<MemoFloatingCollapseButton>(
    find.byType(MemoFloatingCollapseButton),
  );
}

MemosListFloatingCollapseController _screenFloatingCollapseController(
  WidgetTester tester,
) {
  final screenState = tester.state(find.byType(MemosListScreen)) as dynamic;
  return screenState.debugFloatingCollapseController
      as MemosListFloatingCollapseController;
}

dynamic _screenState(WidgetTester tester) {
  return tester.state(find.byType(MemosListScreen)) as dynamic;
}

AiSemanticMemoSearchIndexPreflight _preflight({
  required bool needsIndexing,
  AiBackendKind backendKind = AiBackendKind.remoteApi,
}) {
  return AiSemanticMemoSearchIndexPreflight(
    profileKey: 'test-embedding',
    profileDisplayName: 'Test Embedding',
    backendKind: backendKind,
    baseUrl: backendKind == AiBackendKind.remoteApi
        ? 'https://example.com/v1'
        : 'http://localhost:11434',
    model: 'test-embedding-model',
    memoCount: needsIndexing ? 2 : 0,
    chunkCount: needsIndexing ? 3 : 0,
    estimatedTokenCount: needsIndexing ? 128 : 0,
  );
}

MemosListViewportMetrics _viewportMetrics({
  required double pixels,
  required double maxScrollExtent,
  required double viewport,
}) {
  return MemosListViewportMetrics(
    pixels: pixels,
    maxScrollExtent: maxScrollExtent,
    viewportDimension: viewport,
    axis: Axis.vertical,
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
