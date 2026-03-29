import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memos_flutter_app/core/memo_template_renderer.dart';
import 'package:memos_flutter_app/core/top_toast.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/memo.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/features/memos/gallery_attachment_picker.dart'
    as gallery_picker;
import 'package:memos_flutter_app/features/memos/memos_list_inline_compose_coordinator.dart';
import 'package:memos_flutter_app/features/voice/voice_record_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_controller.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_state.dart';
import 'package:memos_flutter_app/state/settings/user_settings_provider.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('visibility uses user default and normalizes explicit values', (
    tester,
  ) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      overrides: [
        userGeneralSettingProvider.overrideWith(
          (ref) => const UserGeneralSetting(memoVisibility: 'public'),
        ),
      ],
    );

    expect(handle.coordinator.currentVisibility(), 'PUBLIC');
    expect(handle.coordinator.visibilityTouched, isFalse);

    handle.coordinator.setVisibility('unknown');
    await tester.pump();

    expect(handle.coordinator.visibility, 'PRIVATE');
    expect(handle.coordinator.currentVisibility(), 'PRIVATE');
    expect(handle.coordinator.visibilityTouched, isTrue);

    handle.coordinator.resetVisibilityToDefaultTouchState();
    await tester.pump();

    expect(handle.coordinator.visibilityTouched, isFalse);
    expect(handle.coordinator.currentVisibility(), 'PUBLIC');
  });

  testWidgets('linked memo selection deduplicates and removal syncs composer', (
    tester,
  ) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    final selectedMemo = _buildMemo(
      name: 'memos/memo-1',
      content: 'Memo body that should become the chip label',
    );

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      selectLinkedMemoOverride: (_, _) async => selectedMemo,
    );

    await handle.coordinator.openLinkMemoSheet(handle.context);
    await tester.pump();
    await handle.coordinator.openLinkMemoSheet(handle.context);
    await tester.pump();

    expect(composer.linkedMemos, hasLength(1));
    expect(handle.coordinator.linkedMemoNames, {'memos/memo-1'});

    handle.coordinator.removeLinkedMemo('memos/memo-1');
    await tester.pump();

    expect(composer.linkedMemos, isEmpty);
  });

  testWidgets('gallery attachments append to composer', (
    tester,
  ) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-attachments',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final galleryFile = File(
      '${tempDir.path}${Platform.pathSeparator}gallery.png',
    )..writeAsBytesSync(const [1, 2, 3, 4]);

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      pickGalleryOverride: (_) async => gallery_picker.GalleryAttachmentPickResult(
        attachments: [
          gallery_picker.PickedLocalAttachment(
            filePath: galleryFile.path,
            filename: 'gallery.png',
            mimeType: 'image/png',
            size: galleryFile.lengthSync(),
            skipCompression: true,
          ),
        ],
        skippedCount: 0,
      ),
    );

    await handle.coordinator.pickGalleryAttachments(handle.context);
    dismissTopToast();
    await tester.pump();

    expect(composer.pendingAttachments, hasLength(1));
    expect(composer.pendingAttachments.single.filename, 'gallery.png');
    expect(composer.pendingAttachments.first.skipCompression, isTrue);
  });

  testWidgets('file picker attachments append to composer', (tester) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-file-picker',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final pickedFile = File(
      '${tempDir.path}${Platform.pathSeparator}picked.txt',
    )..writeAsStringSync('hello');

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      pickFilesOverride: () async => FilePickerResult([
        PlatformFile(
          name: 'picked.txt',
          size: pickedFile.lengthSync(),
          path: pickedFile.path,
        ),
      ]),
    );

    await handle.coordinator.pickAttachments(handle.context);
    dismissTopToast();
    await tester.pump();

    expect(composer.pendingAttachments, hasLength(1));
    expect(composer.pendingAttachments.single.filename, 'picked.txt');
    expect(composer.pendingAttachments.single.size, 5);
  });

  testWidgets('voice attachment appends and ignores missing file', (tester) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-voice-attachment',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final voiceFile = File(
      '${tempDir.path}${Platform.pathSeparator}voice.m4a',
    )..writeAsBytesSync(const [5, 6, 7]);

    final handle = await _pumpCoordinatorHarness(tester, composer: composer);

    handle.coordinator.addVoiceAttachment(
      handle.context,
      VoiceRecordResult(
        filePath: voiceFile.path,
        fileName: 'voice.m4a',
        size: voiceFile.lengthSync(),
        duration: const Duration(seconds: 2),
        suggestedContent: '',
      ),
    );
    dismissTopToast();
    await tester.pump();

    expect(composer.pendingAttachments, hasLength(1));
    expect(composer.pendingAttachments.single.filename, 'voice.m4a');

    handle.coordinator.addVoiceAttachment(
      handle.context,
      const VoiceRecordResult(
        filePath: '',
        fileName: 'missing.m4a',
        size: 0,
        duration: Duration.zero,
        suggestedContent: '',
      ),
    );
    await tester.pump();

    expect(composer.pendingAttachments, hasLength(1));
  });

  testWidgets('capture photo adds pending attachment on Windows override', (
    tester,
  ) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-camera',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final photoFile = File(
      '${tempDir.path}${Platform.pathSeparator}camera.jpg',
    )..writeAsBytesSync(const [9, 8, 7]);

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      captureWindowsPhotoOverride: () async => XFile(photoFile.path),
    );

    await handle.coordinator.capturePhoto(handle.context);
    dismissTopToast();
    await tester.pump();

    expect(composer.pendingAttachments, hasLength(1));
    expect(composer.pendingAttachments.single.filename, 'camera.jpg');
    expect(composer.pendingAttachments.single.mimeType, 'image/jpeg');
  }, skip: !Platform.isWindows);

  testWidgets('prepareSubmissionDraft builds payload from current state', (
    tester,
  ) async {
    final composer = MemoComposerController(initialText: 'Hello #work');
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-draft',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final attachmentFile = File(
      '${tempDir.path}${Platform.pathSeparator}draft.png',
    )..writeAsBytesSync(const [1, 2, 3]);
    final location = const MemoLocation(
      placeholder: 'Office',
      latitude: 1.23,
      longitude: 4.56,
    );

    composer.addLinkedMemo(
      const MemoComposerLinkedMemo(name: 'memos/related', label: 'Related'),
    );
    composer.addPendingAttachments([
      MemoComposerPendingAttachment(
        uid: 'att-1',
        filePath: attachmentFile.path,
        filename: 'draft.png',
        mimeType: 'image/png',
        size: attachmentFile.lengthSync(),
      ),
    ]);

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      pickLocationOverride: (_, _) async => location,
    );

    handle.coordinator.setVisibility('public');
    await handle.coordinator.requestLocation(handle.context);
    dismissTopToast();
    await tester.pump();

    final draft = await handle.coordinator.prepareSubmissionDraft(
      handle.context,
    );

    expect(draft, isNotNull);
    expect(draft!.content, 'Hello #work');
    expect(draft.visibility, 'PUBLIC');
    expect(draft.tags, ['work']);
    expect(draft.location, location);
    expect(draft.pendingAttachments, hasLength(1));
    expect(draft.relations, hasLength(1));
    expect(
      draft.relations.single,
      containsPair('type', 'REFERENCE'),
    );
    expect(draft.attachmentsPayload, hasLength(1));
    expect(
      draft.attachmentsPayload.single,
      containsPair('externalLink', Uri.file(attachmentFile.path).toString()),
    );
  });

  testWidgets('relation only submission is blocked without voice flow', (
    tester,
  ) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    var voiceCallCount = 0;
    composer.addLinkedMemo(
      const MemoComposerLinkedMemo(name: 'memos/related', label: 'Related'),
    );

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      recordVoiceOverride: (_) async {
        voiceCallCount += 1;
        return null;
      },
    );

    final draft = await handle.coordinator.prepareSubmissionDraft(
      handle.context,
    );
    dismissTopToast();
    await tester.pump();

    expect(draft, isNull);
    expect(voiceCallCount, 0);
  });

  testWidgets('empty submission opens voice flow and appends attachment', (
    tester,
  ) async {
    final composer = MemoComposerController();
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-voice',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final voiceFile = File(
      '${tempDir.path}${Platform.pathSeparator}voice.m4a',
    )..writeAsBytesSync(const [5, 4, 3]);
    var voiceCallCount = 0;

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      recordVoiceOverride: (_) async {
        voiceCallCount += 1;
        return VoiceRecordResult(
          filePath: voiceFile.path,
          fileName: 'voice.m4a',
          size: voiceFile.lengthSync(),
          duration: const Duration(seconds: 1),
          suggestedContent: '',
        );
      },
    );

    final draft = await handle.coordinator.prepareSubmissionDraft(
      handle.context,
    );
    await tester.pump();

    expect(draft, isNull);
    expect(voiceCallCount, 1);
    expect(composer.pendingAttachments, hasLength(1));
    expect(composer.pendingAttachments.single.filename, 'voice.m4a');
  });

  testWidgets('resetAfterSuccessfulSubmit clears transient state only', (
    tester,
  ) async {
    final composer = MemoComposerController(initialText: 'Hello');
    addTearDown(composer.dispose);
    final tempDir = Directory.systemTemp.createTempSync(
      'inline-compose-coordinator-reset',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final attachmentFile = File(
      '${tempDir.path}${Platform.pathSeparator}reset.png',
    )..writeAsBytesSync(const [1, 2, 3]);
    const location = MemoLocation(
      placeholder: 'Desk',
      latitude: 11,
      longitude: 22,
    );

    composer.addPendingAttachments([
      MemoComposerPendingAttachment(
        uid: 'att-1',
        filePath: attachmentFile.path,
        filename: 'reset.png',
        mimeType: 'image/png',
        size: attachmentFile.lengthSync(),
      ),
    ]);
    composer.addLinkedMemo(
      const MemoComposerLinkedMemo(name: 'memos/linked', label: 'Linked'),
    );

    final handle = await _pumpCoordinatorHarness(
      tester,
      composer: composer,
      pickLocationOverride: (_, _) async => location,
    );

    handle.coordinator.setVisibility('public');
    await handle.coordinator.requestLocation(handle.context);
    dismissTopToast();
    await tester.pump();

    handle.coordinator.resetAfterSuccessfulSubmit();
    await tester.pump();

    expect(composer.text, isEmpty);
    expect(composer.pendingAttachments, isEmpty);
    expect(composer.linkedMemos, isEmpty);
    expect(handle.coordinator.location, isNull);
    expect(handle.coordinator.locating, isFalse);
    expect(handle.coordinator.currentVisibility(), 'PUBLIC');
    expect(handle.coordinator.visibilityTouched, isTrue);
  });
}

Future<_CoordinatorHarnessHandle> _pumpCoordinatorHarness(
  WidgetTester tester, {
  required MemoComposerController composer,
  List<Override> overrides = const [],
  InlineComposeLocationPicker? pickLocationOverride,
  InlineComposeGalleryPicker? pickGalleryOverride,
  InlineComposeFilesPicker? pickFilesOverride,
  InlineComposeVoiceRecorder? recordVoiceOverride,
  InlineComposeLinkedMemoSelector? selectLinkedMemoOverride,
  InlineComposeAttachmentViewer? openAttachmentViewerOverride,
  InlineComposeWindowsCapture? captureWindowsPhotoOverride,
}) async {
  final completer = Completer<_CoordinatorHarnessHandle>();

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _CoordinatorHarness(
            composer: composer,
            pickLocationOverride: pickLocationOverride,
            pickGalleryOverride: pickGalleryOverride,
            pickFilesOverride: pickFilesOverride,
            recordVoiceOverride: recordVoiceOverride,
            selectLinkedMemoOverride: selectLinkedMemoOverride,
            openAttachmentViewerOverride: openAttachmentViewerOverride,
            captureWindowsPhotoOverride: captureWindowsPhotoOverride,
            onReady: (handle) {
              if (!completer.isCompleted) {
                completer.complete(handle);
              }
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return completer.future;
}

class _CoordinatorHarnessHandle {
  const _CoordinatorHarnessHandle({
    required this.coordinator,
    required this.context,
  });

  final MemosListInlineComposeCoordinator coordinator;
  final BuildContext context;
}

class _CoordinatorHarness extends ConsumerStatefulWidget {
  const _CoordinatorHarness({
    required this.composer,
    required this.onReady,
    this.pickLocationOverride,
    this.pickGalleryOverride,
    this.pickFilesOverride,
    this.recordVoiceOverride,
    this.selectLinkedMemoOverride,
    this.openAttachmentViewerOverride,
    this.captureWindowsPhotoOverride,
  });

  final MemoComposerController composer;
  final ValueChanged<_CoordinatorHarnessHandle> onReady;
  final InlineComposeLocationPicker? pickLocationOverride;
  final InlineComposeGalleryPicker? pickGalleryOverride;
  final InlineComposeFilesPicker? pickFilesOverride;
  final InlineComposeVoiceRecorder? recordVoiceOverride;
  final InlineComposeLinkedMemoSelector? selectLinkedMemoOverride;
  final InlineComposeAttachmentViewer? openAttachmentViewerOverride;
  final InlineComposeWindowsCapture? captureWindowsPhotoOverride;

  @override
  ConsumerState<_CoordinatorHarness> createState() =>
      _CoordinatorHarnessState();
}

class _CoordinatorHarnessState extends ConsumerState<_CoordinatorHarness> {
  late final MemosListInlineComposeCoordinator coordinator;

  @override
  void initState() {
    super.initState();
    coordinator = MemosListInlineComposeCoordinator(
      ref: ref,
      composer: widget.composer,
      templateRenderer: MemoTemplateRenderer(),
      imagePicker: ImagePicker(),
      pickLocationOverride: widget.pickLocationOverride,
      pickGalleryOverride: widget.pickGalleryOverride,
      pickFilesOverride: widget.pickFilesOverride,
      recordVoiceOverride: widget.recordVoiceOverride,
      selectLinkedMemoOverride: widget.selectLinkedMemoOverride,
      openAttachmentViewerOverride: widget.openAttachmentViewerOverride,
      captureWindowsPhotoOverride: widget.captureWindowsPhotoOverride,
      showToastOverride: (_, _, {duration = const Duration(seconds: 4)}) {},
      showSnackBarOverride: (_, _) {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReady(
        _CoordinatorHarnessHandle(
          coordinator: coordinator,
          context: context,
        ),
      );
    });
  }

  @override
  void dispose() {
    coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

Memo _buildMemo({required String name, required String content}) {
  return Memo(
    name: name,
    creator: 'users/test',
    content: content,
    contentFingerprint: '',
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updateTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    tags: const <String>[],
    attachments: const <Attachment>[],
  );
}
