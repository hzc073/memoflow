// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

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
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_reminder.dart';
import 'package:memos_flutter_app/data/repositories/location_settings_repository.dart';
import 'package:memos_flutter_app/features/memos/memos_list_floating_collapse_controller.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';
import 'package:memos_flutter_app/features/memos/memo_image_grid.dart';
import 'package:memos_flutter_app/features/memos/memo_inline_image_syntax.dart';
import 'package:memos_flutter_app/features/memos/memo_media_cache_key.dart';
import 'package:memos_flutter_app/features/memos/memo_media_grid.dart';
import 'package:memos_flutter_app/features/memos/memo_time_adjustment_sheet.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card_container.dart';
import 'package:memos_flutter_app/features/image_preview/widgets/image_preview_tile.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memo_clip_card_providers.dart';
import 'package:memos_flutter_app/state/memos/memos_list_providers.dart';
import 'package:memos_flutter_app/state/settings/location_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/reminder_settings_provider.dart';
import 'package:memos_flutter_app/state/system/reminder_providers.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('card menu exposes creation time change only for normal memos', (
    tester,
  ) async {
    late List<PopupMenuEntry<MemoCardAction>> normalItems;
    late List<PopupMenuEntry<MemoCardAction>> archivedItems;

    await tester.pumpWidget(
      _buildTimeAdjustmentHarness(
        Builder(
          builder: (context) {
            normalItems = buildMemoCardActionMenuItems(
              context: context,
              memo: _buildMemo(),
              deleteColor: Colors.red,
            );
            archivedItems = buildMemoCardActionMenuItems(
              context: context,
              memo: _buildMemo(state: 'ARCHIVED'),
              deleteColor: Colors.red,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(_menuValues(normalItems), contains(MemoCardAction.adjustTime));
    expect(
      _menuValues(archivedItems),
      isNot(contains(MemoCardAction.adjustTime)),
    );
  });

  testWidgets('normal memo more menu renders grouped action popover', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(memo: _buildMemo()));

    await _openCardMoreMenu(tester);

    expect(find.byKey(memoCardActionPopoverKey), findsOneWidget);
    expect(find.byKey(memoCardActionPrimarySectionKey), findsOneWidget);
    expect(find.byKey(memoCardActionSecondarySectionKey), findsOneWidget);
    expect(find.byKey(memoCardActionDangerSectionKey), findsOneWidget);
    expect(
      find.text(t.strings.collections.reader.moreSettingsTitle),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.copy)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.edit)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.reminder)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.togglePinned)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.addToCollection)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.archive)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.adjustTime)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.history)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.delete)),
      findsOneWidget,
    );
  });

  testWidgets('archived memo more menu renders archived action subset', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(memo: _buildMemo(state: 'ARCHIVED')));

    await _openCardMoreMenu(tester);

    expect(find.byKey(memoCardActionPopoverKey), findsOneWidget);
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.copy)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.history)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.restore)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.delete)),
      findsOneWidget,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.edit)),
      findsNothing,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.reminder)),
      findsNothing,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.togglePinned)),
      findsNothing,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.addToCollection)),
      findsNothing,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.archive)),
      findsNothing,
    );
    expect(
      find.byKey(memoCardActionItemKey(MemoCardAction.adjustTime)),
      findsNothing,
    );
  });

  testWidgets('memo more menu selects one action and dismisses outside', (
    tester,
  ) async {
    final selectedActions = <MemoCardAction>[];
    await tester.pumpWidget(
      _buildHarness(memo: _buildMemo(), onAction: selectedActions.add),
    );

    await _openCardMoreMenu(tester);
    await tester.tap(find.byKey(memoCardActionItemKey(MemoCardAction.edit)));
    await tester.pumpAndSettle();

    expect(selectedActions, [MemoCardAction.edit]);
    expect(find.byKey(memoCardActionPopoverKey), findsNothing);

    await _openCardMoreMenu(tester);
    await tester.tapAt(const Offset(6, 6));
    await tester.pumpAndSettle();

    expect(selectedActions, [MemoCardAction.edit]);
    expect(find.byKey(memoCardActionPopoverKey), findsNothing);
  });

  testWidgets('memo more menu stays within viewport near bottom right edge', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 480));
    await tester.pumpWidget(_buildPopoverEdgeHarness(memo: _buildMemo()));

    await tester.tap(find.byTooltip('edge-menu'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(memoCardActionPopoverKey));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(360));
    expect(rect.bottom, lessThanOrEqualTo(480));
  });

  testWidgets('button and context menu paths expose shared action metadata', (
    tester,
  ) async {
    final memo = _buildMemo();
    await tester.pumpWidget(_buildHarness(memo: memo));
    await _openCardMoreMenu(tester);
    final buttonActions = _visiblePopoverActions();
    await tester.tapAt(const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(find.byKey(memoCardActionPopoverKey), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_buildContextMenuHarness(memo: memo));
    await tester.tap(find.text('context-menu'));
    await tester.pumpAndSettle();
    final contextActions = _visiblePopoverActions();
    await tester.tapAt(const Offset(6, 6));
    await tester.pumpAndSettle();

    expect(contextActions, buttonActions);
    expect(
      contextActions,
      unorderedEquals(_descriptorActionsForContext(tester, memo)),
    );
  });

  testWidgets('creation time sheet cancels without a result', (tester) async {
    var completed = false;
    DateTime? result;

    await tester.pumpWidget(
      _buildTimeAdjustmentHarness(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showMemoTimeAdjustmentSheet(
                context: context,
                memo: _buildMemo(),
              );
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(memoTimeAdjustmentSheetKey), findsOneWidget);
    expect(find.text(t.strings.memoTimeAdjustment.action), findsOneWidget);
    expect(find.textContaining('2024-01-02'), findsWidgets);
    expect(find.textContaining('03:04'), findsWidgets);

    await tester.tap(find.byKey(memoTimeAdjustmentCancelButtonKey));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('creation time sheet saves current effective time', (
    tester,
  ) async {
    DateTime? result;
    final displayTime = DateTime(2024, 2, 3, 4, 5, 6);
    final memo = _buildMemo(displayTime: displayTime);

    await tester.pumpWidget(
      _buildTimeAdjustmentHarness(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showMemoTimeAdjustmentSheet(
                context: context,
                memo: memo,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(memoTimeAdjustmentSaveButtonKey));
    await tester.pumpAndSettle();

    expect(result, displayTime);
  });

  test(
    'attachment source fingerprint changes when preview metadata changes',
    () {
      const base = Attachment(
        name: 'attachments/att-1',
        filename: 'sample.jpg',
        type: 'image/jpeg',
        size: 42,
        externalLink: 'file:///old/sample.jpg',
        width: 640,
        height: 480,
        hash: 'old-hash',
      );
      final original = memoMediaAttachmentSourceFingerprint(const [base]);

      final variants = <Attachment>[
        const Attachment(
          name: 'attachments/att-2',
          filename: 'sample.jpg',
          type: 'image/jpeg',
          size: 42,
          externalLink: 'file:///old/sample.jpg',
          width: 640,
          height: 480,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'renamed.jpg',
          type: 'image/jpeg',
          size: 42,
          externalLink: 'file:///old/sample.jpg',
          width: 640,
          height: 480,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'sample.jpg',
          type: 'image/png',
          size: 42,
          externalLink: 'file:///old/sample.jpg',
          width: 640,
          height: 480,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'sample.jpg',
          type: 'image/jpeg',
          size: 43,
          externalLink: 'file:///old/sample.jpg',
          width: 640,
          height: 480,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'sample.jpg',
          type: 'image/jpeg',
          size: 42,
          externalLink: 'file:///new/sample.jpg',
          width: 640,
          height: 480,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'sample.jpg',
          type: 'image/jpeg',
          size: 42,
          externalLink: 'file:///old/sample.jpg',
          width: 800,
          height: 480,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'sample.jpg',
          type: 'image/jpeg',
          size: 42,
          externalLink: 'file:///old/sample.jpg',
          width: 640,
          height: 600,
          hash: 'old-hash',
        ),
        const Attachment(
          name: 'attachments/att-1',
          filename: 'sample.jpg',
          type: 'image/jpeg',
          size: 42,
          externalLink: 'file:///old/sample.jpg',
          width: 640,
          height: 480,
          hash: 'new-hash',
        ),
      ];

      for (final variant in variants) {
        expect(
          memoMediaAttachmentSourceFingerprint([variant]),
          isNot(original),
        );
      }
    },
  );

  testWidgets('memo card press feedback uses fixed one pixel offset', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(memo: _buildMemo()));
    await tester.pump();

    final pressOffset = find.byKey(memoListCardPressOffsetKey);
    expect(pressOffset, findsOneWidget);
    expect(
      find.ancestor(of: pressOffset, matching: find.byType(AnimatedScale)),
      findsNothing,
    );
    expect(_pressOffsetY(tester), 0);

    final gesture = await tester.startGesture(tester.getCenter(pressOffset));
    await tester.pump();

    expect(_pressOffsetY(tester), 1);

    await gesture.moveBy(const Offset(32, 0));
    await tester.pump();

    expect(_pressOffsetY(tester), 0);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_pressOffsetY(tester), 0);
  });

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

  testWidgets(
    'rebuilds preview item when attachment local source changes without updateTime change',
    (tester) async {
      final memoUid =
          'memo-source-refresh-${DateTime.now().microsecondsSinceEpoch}';
      const oldPath = '/tmp/memoflow-test/queued-photo.png';
      const newPath = '/tmp/memoflow-test/private-photo.png';
      final expectedOldPath = Uri.file(oldPath).toFilePath();
      final expectedNewPath = Uri.file(newPath).toFilePath();
      Attachment attachmentFor(String path) {
        return Attachment(
          name: 'attachments/att-1',
          filename: 'photo.png',
          type: 'image/png',
          size: 42,
          externalLink: Uri.file(path).toString(),
          width: 1,
          height: 1,
          hash: 'same-hash',
        );
      }

      await tester.pumpWidget(
        _buildHarness(
          memo: _buildMemo(
            uid: memoUid,
            content: 'memo with image',
            attachments: [attachmentFor(oldPath)],
          ),
        ),
      );
      await tester.pump();

      var tile = tester.widget<ImagePreviewTile>(
        find.byType(ImagePreviewTile).first,
      );
      expect(tile.item.localFile?.path, expectedOldPath);

      await tester.pumpWidget(
        _buildHarness(
          memo: _buildMemo(
            uid: memoUid,
            content: 'memo with image',
            attachments: [attachmentFor(newPath)],
          ),
        ),
      );
      await tester.pump();

      tile = tester.widget<ImagePreviewTile>(
        find.byType(ImagePreviewTile).first,
      );
      expect(tile.item.localFile?.path, expectedNewPath);
      expect(tile.item.localFile?.path, isNot(expectedOldPath));
    },
  );

  testWidgets('uses explicit hero tag when provided', (tester) async {
    final memo = _buildMemo();
    const heroTag = 'memo-list:visible:0:memo-1';

    await tester.pumpWidget(_buildHarness(memo: memo, heroTag: heroTag));
    await tester.pumpAndSettle();

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, heroTag);
  });

  testWidgets('clip cards enable expanded article body mode on memo cards', (
    tester,
  ) async {
    final memo = _buildMemo(
      content:
          '# Clip title\n\n'
          'Intro paragraph.\n\n'
          '<img src="https://example.com/clip.jpg">\n\n'
          '${'Detailed body paragraph. ' * 80}\n\n'
          '${buildThirdPartyShareMemoMarker()}',
    );
    final clipCard = _buildClipCardMetadata(memo.uid);

    await tester.pumpWidget(
      _buildHarness(memo: memo, clipCardMetadata: clipCard),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<MemoListCard>(find.byType(MemoListCard));
    expect(card.useExpandedArticleBody, isTrue);
  });

  testWidgets(
    'MemoListCard hides media grid and renders inline images in expanded article mode',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));

      final memo = _buildMemo(content: '# Clip title');
      final body =
          'Intro paragraph.\n\n'
          '<img src="https://example.com/clip.jpg">\n\n'
          '${'Detailed body paragraph. ' * 80}';
      const imageEntry = MemoImageEntry(
        id: 'inline_0',
        title: 'clip',
        mimeType: 'image/*',
        previewUrl: 'https://example.com/clip.jpg',
        fullUrl: 'https://example.com/clip.jpg',
      );

      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: MemoListCard(
                    memo: memo,
                    dateText: '2024-01-02',
                    reminderText: null,
                    tagColors: TagColorLookup(const []),
                    initiallyExpanded: false,
                    highlightQuery: null,
                    collapseLongContent: true,
                    collapseReferences: true,
                    isAudioPlaying: false,
                    isAudioLoading: false,
                    audioPositionListenable: null,
                    audioDurationListenable: null,
                    imageEntries: const [imageEntry],
                    mediaEntries: const [MemoMediaEntry.image(imageEntry)],
                    contentTextOverride: body,
                    contentHeader: const SizedBox.shrink(),
                    useExpandedArticleBody: true,
                    locationProvider: LocationServiceProvider.google,
                    onAudioSeek: null,
                    onAudioTap: null,
                    syncStatus: MemoSyncStatus.none,
                    onToggleTask: (_) {},
                    onTap: () {},
                    onAction: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MemoMediaGrid), findsOneWidget);
      var markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isFalse);
      expect(markdown.data, contains('Intro paragraph.'));
      expect(markdown.data, isNot(contains('<img')));
      expect(markdown.data.trimRight(), endsWith('...'));

      await tester.tap(find.text('Expand'));
      await _pumpTestFrames(tester);

      expect(find.byType(MemoMediaGrid), findsNothing);
      markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isTrue);
      expect(
        markdown.data,
        contains('<img src="https://example.com/clip.jpg">'),
      );
      expect(markdown.data, contains('Detailed body paragraph.'));
    },
  );

  testWidgets(
    'MemoListCard allowlists memo-owned local inline images in expanded article mode',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      final localUrl = Uri.file(
        '/tmp/memoflow-test/owned-inline.png',
      ).toString();
      final imageFile = File.fromUri(Uri.parse(localUrl));
      final body =
          'Intro paragraph.\n\n'
          '<img src="$localUrl">\n\n'
          '${'Detailed body paragraph. ' * 80}';
      final attachment = Attachment(
        name: 'attachments/att-owned',
        filename: 'owned.png',
        type: 'image/png',
        size: 1,
        externalLink: localUrl,
        width: 1,
        height: 1,
      );
      final imageEntry = MemoImageEntry(
        id: 'inline_0',
        title: 'owned.png',
        mimeType: 'image/*',
        localFile: imageFile,
      );
      final memo = _buildMemo(
        content: '# Clip title\n\n$body\n\n${buildThirdPartyShareMemoMarker()}',
        attachments: [attachment],
      );

      await tester.pumpWidget(
        _buildDirectCardHarness(
          memo: memo,
          contentTextOverride: body,
          imageEntries: [imageEntry],
          mediaEntries: [MemoMediaEntry.image(imageEntry)],
          initiallyExpanded: true,
        ),
      );
      await tester.pump();

      final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isTrue);
      expect(markdown.allowedLocalImageUrls, contains(localUrl));
      expect(markdown.imagePreviewItems, hasLength(1));
      expect(
        markdown.imagePreviewItems!.single.localFile?.path,
        imageFile.path,
      );
      expect(markdown.onOpenImagePreview, isNotNull);
      expect(find.byType(MemoMediaGrid), findsNothing);
    },
  );

  testWidgets(
    'MemoListCard blocks unowned local inline images in expanded article mode',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      final localUrl = Uri.file(
        '/tmp/memoflow-test/unowned-inline.png',
      ).toString();
      final body =
          'Intro paragraph.\n\n'
          '<img src="$localUrl">\n\n'
          '${'Detailed body paragraph. ' * 80}';
      final memo = _buildMemo(
        content: '# Clip title\n\n$body\n\n${buildThirdPartyShareMemoMarker()}',
      );

      await tester.pumpWidget(
        _buildDirectCardHarness(
          memo: memo,
          contentTextOverride: body,
          initiallyExpanded: true,
        ),
      );
      await tester.pump();

      final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isTrue);
      expect(markdown.allowedLocalImageUrls, isEmpty);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'MemoListCard collapsed article preview keeps inline images disabled',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      final localUrl = Uri.file(
        '/tmp/memoflow-test/owned-collapsed.png',
      ).toString();
      final body =
          'Intro paragraph.\n\n'
          '<img src="$localUrl">\n\n'
          '${'Detailed body paragraph. ' * 80}';
      final memo = _buildMemo(
        content: '# Clip title\n\n$body\n\n${buildThirdPartyShareMemoMarker()}',
        attachments: [
          Attachment(
            name: 'attachments/att-collapsed',
            filename: 'owned-collapsed.png',
            type: 'image/png',
            size: 1,
            externalLink: localUrl,
          ),
        ],
      );

      await tester.pumpWidget(
        _buildDirectCardHarness(memo: memo, contentTextOverride: body),
      );
      await tester.pumpAndSettle();

      final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isFalse);
      expect(markdown.allowedLocalImageUrls, isEmpty);
      expect(markdown.data, isNot(contains('<img')));
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'MemoListCard preserves remote inline image request configuration',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      final baseUrl = Uri.parse('https://memos.example.test');
      final body = 'Intro paragraph.\n\n${'Detailed body paragraph. ' * 80}';
      final memo = _buildMemo(
        content: '# Clip title\n\n$body\n\n${buildThirdPartyShareMemoMarker()}',
      );

      await tester.pumpWidget(
        _buildDirectCardHarness(
          memo: memo,
          contentTextOverride: body,
          initiallyExpanded: true,
          baseUrl: baseUrl,
          authHeader: 'Bearer token',
          rebaseAbsoluteFileUrlForV024: true,
          attachAuthForSameOriginAbsolute: true,
        ),
      );
      await tester.pump();

      final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isTrue);
      expect(markdown.baseUrl, baseUrl);
      expect(markdown.authHeader, 'Bearer token');
      expect(markdown.rebaseAbsoluteFileUrlForV024, isTrue);
      expect(markdown.attachAuthForSameOriginAbsolute, isTrue);
    },
  );

  testWidgets(
    'MemoListCard markdown cache key changes when local inline policy changes',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      final contentUrl = Uri.file(
        '/tmp/memoflow-test/content-inline.png',
      ).toString();
      final replacementUrl = Uri.file(
        '/tmp/memoflow-test/other-attachment.png',
      ).toString();
      final body =
          'Intro paragraph.\n\n'
          '<img src="$contentUrl">\n\n'
          '${'Detailed body paragraph. ' * 80}';
      Attachment attachmentFor(String url) {
        return Attachment(
          name: 'attachments/att-cache',
          filename: 'cache.png',
          type: 'image/png',
          size: 1,
          externalLink: url,
        );
      }

      await tester.pumpWidget(
        _buildDirectCardHarness(
          memo: _buildMemo(
            content:
                '# Clip title\n\n$body\n\n${buildThirdPartyShareMemoMarker()}',
            attachments: [attachmentFor(contentUrl)],
          ),
          contentTextOverride: body,
          initiallyExpanded: true,
        ),
      );
      await tester.pump();

      final firstMarkdown = tester.widget<MemoMarkdown>(
        find.byType(MemoMarkdown),
      );
      final firstCacheKey = firstMarkdown.cacheKey;
      expect(firstMarkdown.allowedLocalImageUrls, contains(contentUrl));

      await tester.pumpWidget(
        _buildDirectCardHarness(
          memo: _buildMemo(
            content:
                '# Clip title\n\n$body\n\n${buildThirdPartyShareMemoMarker()}',
            attachments: [attachmentFor(replacementUrl)],
          ),
          contentTextOverride: body,
          initiallyExpanded: true,
        ),
      );
      await tester.pump();

      final secondMarkdown = tester.widget<MemoMarkdown>(
        find.byType(MemoMarkdown),
      );
      expect(secondMarkdown.allowedLocalImageUrls, isEmpty);
      expect(secondMarkdown.cacheKey, isNot(firstCacheKey));
    },
  );

  testWidgets(
    'MemoListCard expands normal memo cards from preview text to full body content',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));

      final content =
          '# Heading\n\n'
          'Intro paragraph before the inline image.\n\n'
          '<img src="https://example.com/raw-body.jpg">\n\n'
          '${List<String>.generate(8, (index) => 'Expanded body paragraph $index with enough text to keep the preview truncated.').join('\n\n')}\n\n'
          'Tail marker visible after expand.';
      final memo = _buildMemo(content: content);
      final memoCardKey = GlobalKey<MemoListCardState>();

      await tester.pumpWidget(
        _buildHarness(
          memo: memo,
          memoCardKey: memoCardKey,
          wrapInScrollView: true,
        ),
      );
      await tester.pumpAndSettle();

      var markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isFalse);
      expect(markdown.data, isNot(contains('<img')));
      expect(markdown.data.trimRight(), endsWith('...'));
      expect(
        find.textContaining(
          'Tail marker visible after expand.',
          findRichText: true,
        ),
        findsNothing,
      );
      expect(find.text('Expand'), findsOneWidget);

      memoCardKey.currentState!.debugExpandForTest();
      await _pumpTestFrames(tester);

      markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isFalse);
      expect(
        markdown.data,
        contains('<img src="https://example.com/raw-body.jpg">'),
      );
      expect(markdown.data, contains('Tail marker visible after expand.'));
      expect(
        find.textContaining(
          'Tail marker visible after expand.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Collapse'), findsOneWidget);
    },
  );

  testWidgets(
    'normal memo card expands markdown images inline and suppresses duplicate grid',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));

      final content =
          'Intro paragraph before the markdown image.\n\n'
          '![inline](https://example.com/raw-body.jpg)\n\n'
          '${List<String>.generate(8, (index) => 'Expanded body paragraph $index with enough text to keep the preview truncated.').join('\n\n')}\n\n'
          'Tail marker visible after expand.';
      final memo = _buildMemo(content: content);
      final memoCardKey = GlobalKey<MemoListCardState>();

      await tester.pumpWidget(
        _buildHarness(
          memo: memo,
          memoCardKey: memoCardKey,
          wrapInScrollView: true,
        ),
      );
      await tester.pumpAndSettle();

      var markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isFalse);
      expect(markdown.imageSyntax, MemoInlineImageSyntax.none);
      expect(find.byType(MemoMediaGrid), findsOneWidget);

      memoCardKey.currentState!.debugExpandForTest();
      await _pumpTestFrames(tester);

      markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.renderImages, isTrue);
      expect(markdown.imageSyntax, MemoInlineImageSyntax.markdownOnly);
      expect(markdown.data, contains('![inline]'));
      expect(find.byType(MemoMediaGrid), findsNothing);
    },
  );

  testWidgets(
    'expanded markdown image body keeps unreferenced attachment grid entries',
    (tester) async {
      const inlineImage = MemoImageEntry(
        id: 'inline_0',
        title: 'inline',
        mimeType: 'image/*',
        previewUrl: 'https://example.com/inline.jpg',
        fullUrl: 'https://example.com/inline.jpg',
      );
      const attachmentImage = MemoImageEntry(
        id: 'attachments/att-1',
        title: 'attachment',
        mimeType: 'image/*',
        previewUrl: 'https://example.com/attachment.jpg',
        fullUrl: 'https://example.com/attachment.jpg',
        isAttachment: true,
      );
      final memo = _buildMemo(
        content:
            'Intro paragraph.\n\n'
            '![inline](https://example.com/inline.jpg)\n\n'
            '${'Detailed body paragraph. ' * 80}',
      );

      await tester.pumpWidget(
        _buildDirectCardHarness(
          memo: memo,
          imageEntries: const [inlineImage, attachmentImage],
          mediaEntries: const [
            MemoMediaEntry.image(inlineImage),
            MemoMediaEntry.image(attachmentImage),
          ],
          initiallyExpanded: true,
          expandedInlineImageSyntax: MemoInlineImageSyntax.markdownOnly,
        ),
      );
      await tester.pump();

      final grid = tester.widget<MemoMediaGrid>(find.byType(MemoMediaGrid));
      expect(grid.entries, hasLength(1));
      expect(grid.entries.single.image?.isAttachment, isTrue);
      final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
      expect(markdown.imageSyntax, MemoInlineImageSyntax.markdownOnly);
    },
  );

  testWidgets(
    'macOS memo card media grid keeps square tiles when height limited',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 900));

      try {
        final images = List<MemoImageEntry>.generate(
          9,
          (index) => MemoImageEntry(
            id: 'attachments/att-$index',
            title: 'attachment-$index',
            mimeType: 'image/jpeg',
            previewUrl: 'https://example.com/att-$index.jpg',
            fullUrl: 'https://example.com/att-$index.jpg',
            isAttachment: true,
          ),
        );

        await tester.pumpWidget(
          _buildDirectCardHarness(
            memo: _buildMemo(content: 'macOS media grid memo'),
            imageEntries: images,
            mediaEntries: images.map(MemoMediaEntry.image).toList(),
          ),
        );
        await tester.pumpAndSettle();

        final tileRect = tester.getRect(find.byType(ImagePreviewTile).first);
        final gridRect = tester.getRect(find.byType(MemoMediaGrid).first);
        expect(tileRect.width, closeTo(tileRect.height, 0.1));
        expect(gridRect.width, lessThan(420));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'MemosListMemoCardContainer publishes floating geometry and clears it after floating collapse',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));

      final memo = _buildMemo(content: _buildLongMemoContent());
      final memoCardKey = GlobalKey<MemoListCardState>();
      final publishedGeometries = <MemoFloatingCollapseGeometry?>[];

      await tester.pumpWidget(
        _buildHarness(
          memo: memo,
          memoCardKey: memoCardKey,
          wrapInScrollView: true,
          onFloatingGeometryChanged: publishedGeometries.add,
        ),
      );
      await _pumpTestFrames(tester);

      expect(
        publishedGeometries.whereType<MemoFloatingCollapseGeometry>(),
        isEmpty,
      );

      await tester.tap(find.text('Expand'));
      await _pumpTestFrames(tester);

      expect(
        publishedGeometries
            .whereType<MemoFloatingCollapseGeometry>()
            .isNotEmpty,
        isTrue,
      );

      memoCardKey.currentState!.collapseFromFloating();
      await _pumpTestFrames(tester);

      expect(publishedGeometries.last, isNull);
      expect(find.text('Expand'), findsOneWidget);
      expect(find.text('Collapse'), findsNothing);
    },
  );

  testWidgets(
    'MemosListMemoCardContainer clears floating geometry when the card is removed',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 2200));

      final memo = _buildMemo(content: _buildLongMemoContent());
      final publishedGeometries = <MemoFloatingCollapseGeometry?>[];

      await tester.pumpWidget(
        _buildHarness(
          memo: memo,
          wrapInScrollView: true,
          onFloatingGeometryChanged: publishedGeometries.add,
        ),
      );
      await _pumpTestFrames(tester);

      await tester.tap(find.text('Expand'));
      await _pumpTestFrames(tester);

      expect(
        publishedGeometries
            .whereType<MemoFloatingCollapseGeometry>()
            .isNotEmpty,
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(publishedGeometries.last, isNull);
    },
  );
}

Widget _buildHarness({
  required LocalMemo memo,
  OutboxMemoStatus outboxStatus = const OutboxMemoStatus.empty(),
  Map<String, MemoReminder> reminderMap = const <String, MemoReminder>{},
  ReminderSettings? reminderSettings,
  MemoClipCardMetadata? clipCardMetadata,
  String? playingMemoUid,
  bool removing = false,
  Object? heroTag,
  VoidCallback? onTap,
  ValueChanged<MemoCardAction>? onAction,
  ValueChanged<int>? onToggleTask,
  GlobalKey<MemoListCardState>? memoCardKey,
  ValueChanged<MemoFloatingCollapseGeometry?>? onFloatingGeometryChanged,
  bool wrapInScrollView = false,
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
      memoClipCardMapProvider.overrideWith(
        (ref) => clipCardMetadata == null
            ? const <String, MemoClipCardMetadata>{}
            : <String, MemoClipCardMetadata>{
                clipCardMetadata.memoUid: clipCardMetadata,
              },
      ),
      memoReminderMapProvider.overrideWith((ref) => reminderMap),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              Widget body = Center(
                child: SizedBox(
                  width: 420,
                  child: MemosListMemoCardContainer(
                    memoCardKey: memoCardKey ?? GlobalKey<MemoListCardState>(),
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
                    onFloatingGeometryChanged:
                        onFloatingGeometryChanged ?? (_) {},
                    onAction: onAction ?? (_) {},
                  ),
                ),
              );
              if (wrapInScrollView) {
                body = SingleChildScrollView(child: body);
              }
              return body;
            },
          ),
        ),
      ),
    ),
  );
}

Widget _buildDirectCardHarness({
  required LocalMemo memo,
  String? contentTextOverride,
  List<MemoImageEntry> imageEntries = const <MemoImageEntry>[],
  List<MemoMediaEntry> mediaEntries = const <MemoMediaEntry>[],
  bool initiallyExpanded = false,
  Uri? baseUrl,
  String? authHeader,
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
  MemoInlineImageSyntax expandedInlineImageSyntax =
      MemoInlineImageSyntax.markdownAndHtml,
}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: MemoListCard(
              memo: memo,
              dateText: '2024-01-02',
              reminderText: null,
              tagColors: TagColorLookup(const []),
              initiallyExpanded: initiallyExpanded,
              highlightQuery: null,
              collapseLongContent: true,
              collapseReferences: true,
              isAudioPlaying: false,
              isAudioLoading: false,
              audioPositionListenable: null,
              audioDurationListenable: null,
              imageEntries: imageEntries,
              mediaEntries: mediaEntries,
              contentTextOverride: contentTextOverride,
              contentHeader: const SizedBox.shrink(),
              useExpandedArticleBody: true,
              expandedInlineImageSyntax: expandedInlineImageSyntax,
              baseUrl: baseUrl,
              authHeader: authHeader,
              rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
              attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
              locationProvider: LocationServiceProvider.google,
              onAudioSeek: null,
              onAudioTap: null,
              syncStatus: MemoSyncStatus.none,
              onToggleTask: (_) {},
              onTap: () {},
              onAction: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

String _buildLongMemoContent() {
  return List<String>.generate(
    320,
    (index) =>
        'Long memo paragraph $index with enough words to keep the '
        'expanded article body tall for floating collapse coverage.',
  ).join('\n\n');
}

Future<void> _pumpTestFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
}

double _pressOffsetY(WidgetTester tester) {
  final pressOffset = tester.widget<AnimatedContainer>(
    find.byKey(memoListCardPressOffsetKey),
  );
  return pressOffset.transform?.getTranslation().y ?? 0;
}

MemoClipCardMetadata _buildClipCardMetadata(String memoUid) {
  final now = DateTime(2024, 1, 2, 3, 4, 5);
  return MemoClipCardMetadata(
    memoUid: memoUid,
    clipKind: MemoClipKind.article,
    platform: MemoClipPlatform.wechat,
    sourceName: 'Example Source',
    sourceAvatarUrl: '',
    authorName: '',
    authorAvatarUrl: '',
    sourceUrl: 'https://example.com/article',
    leadImageUrl: '',
    parserTag: 'wechat',
    createdTime: now,
    updatedTime: now,
  );
}

LocalMemo _buildMemo({
  String uid = 'memo-1',
  String content = 'memo body',
  String state = 'NORMAL',
  DateTime? displayTime,
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
    state: state,
    createTime: now,
    displayTime: displayTime,
    updateTime: now,
    tags: const <String>[],
    attachments: attachments,
    relationCount: 0,
    syncState: syncState,
    lastError: null,
  );
}

List<MemoCardAction?> _menuValues(List<PopupMenuEntry<MemoCardAction>> items) {
  return items
      .whereType<PopupMenuItem<MemoCardAction>>()
      .map((item) => item.value)
      .toList(growable: false);
}

Future<void> _openCardMoreMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(t.strings.legacy.msg_more).first);
  await tester.pumpAndSettle();
}

List<MemoCardAction> _visiblePopoverActions() {
  return [
    for (final action in MemoCardAction.values)
      if (find.byKey(memoCardActionItemKey(action)).evaluate().isNotEmpty)
        action,
  ];
}

List<MemoCardAction> _descriptorActionsForContext(
  WidgetTester tester,
  LocalMemo memo,
) {
  final context = tester.element(find.byType(Scaffold).first);
  return buildMemoCardActionOrder(context: context, memo: memo);
}

Widget _buildTimeAdjustmentHarness(Widget child) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _buildPopoverEdgeHarness({required LocalMemo memo}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: Builder(
            builder: (context) => IconButton(
              tooltip: 'edge-menu',
              onPressed: () {
                showMemoCardActionPopover(
                  context: context,
                  memo: memo,
                  anchorContext: context,
                );
              },
              icon: const Icon(Icons.more_horiz),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildContextMenuHarness({required LocalMemo memo}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showMemoCardContextMenu(
                  context: context,
                  memo: memo,
                  globalPosition: const Offset(320, 220),
                );
              },
              child: const Text('context-menu'),
            ),
          ),
        ),
      ),
    ),
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
