import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/state/memos/memo_composer_controller.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_state.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoComposerController', () {
    test('supports undo and redo for text edits', () {
      final controller = MemoComposerController(initialText: 'hello');
      addTearDown(controller.dispose);

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      controller.insertText(' world');

      expect(controller.text, 'hello world');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      controller.undo();

      expect(controller.text, 'hello');
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      controller.redo();

      expect(controller.text, 'hello world');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
    });

    test('applies smart enter for task items', () {
      final controller = MemoComposerController(initialText: '- [ ] item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '- [ ] item\n- [ ] ');
    });

    test('applies smart enter for unordered list items', () {
      final controller = MemoComposerController(initialText: '- item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '- item\n- ');
    });

    test('applies smart enter for unordered list items with CRLF', () {
      final controller = MemoComposerController(initialText: '- item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\r\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 2,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '- item\r\n- ');
    });

    test(
      'applies smart enter for unordered list items when cursor update lags',
      () {
        final controller = MemoComposerController(initialText: '- item');
        addTearDown(controller.dispose);

        controller.textController.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        controller.textController.value = controller.textController.value
            .copyWith(
              text: '${controller.text}\n',
              selection: TextSelection.collapsed(
                offset: controller.text.length,
              ),
              composing: TextRange.empty,
            );

        expect(controller.text, '- item\n- ');
        expect(
          controller.textController.selection,
          const TextSelection.collapsed(offset: 9),
        );
      },
    );

    test('applies smart enter for ordered list items', () {
      final controller = MemoComposerController(initialText: '1. item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '1. item\n2. ');
    });

    test(
      'applies smart enter for checked task items as unchecked next item',
      () {
        final controller = MemoComposerController(initialText: '- [x] done');
        addTearDown(controller.dispose);

        controller.textController.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        controller.textController.value = controller.textController.value
            .copyWith(
              text: '${controller.text}\n',
              selection: TextSelection.collapsed(
                offset: controller.text.length + 1,
              ),
              composing: TextRange.empty,
            );

        expect(controller.text, '- [x] done\n- [ ] ');
      },
    );

    test('applies smart enter for ordered list items with CRLF', () {
      final controller = MemoComposerController(initialText: '1. item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\r\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 2,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '1. item\r\n2. ');
    });

    test('preserves indentation while incrementing ordered list items', () {
      final controller = MemoComposerController(initialText: '  3. item');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '  3. item\n  4. ');
    });

    test('smart enter exits an empty ordered list item', () {
      final controller = MemoComposerController(initialText: '1. ');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '\n');
    });

    test('smart enter exits an empty unordered list item', () {
      final controller = MemoComposerController(initialText: '- ');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '\n');
    });

    test('smart enter exits an empty task list item', () {
      final controller = MemoComposerController(initialText: '- [ ] ');
      addTearDown(controller.dispose);

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.textController.value = controller.textController.value
          .copyWith(
            text: '${controller.text}\n',
            selection: TextSelection.collapsed(
              offset: controller.text.length + 1,
            ),
            composing: TextRange.empty,
          );

      expect(controller.text, '\n');
    });

    test('wraps selections with formatting markers', () {
      final controller = MemoComposerController(initialText: 'hello');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.toggleBold();
      expect(controller.text, '**hello**');

      controller.replaceText('hello');
      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.toggleUnderline();
      expect(controller.text, '<u>hello</u>');

      controller.replaceText('hello');
      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.toggleHighlight();
      expect(controller.text, '==hello==');
    });

    test('inline formatting toggles can unwrap when applied again', () {
      final controller = MemoComposerController(initialText: '**hello**');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      controller.toggleBold();
      expect(controller.text, 'hello');

      controller.replaceText('<u>hello</u>');
      controller.textController.selection = const TextSelection.collapsed(
        offset: 5,
      );
      controller.toggleUnderline();
      expect(controller.text, 'hello');

      controller.replaceText('==hello==');
      controller.textController.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      controller.toggleHighlight();
      expect(controller.text, 'hello');
    });

    test('inline formatting toggles unwrap empty wrappers on second tap', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);

      controller.toggleHighlight();
      expect(controller.text, '====');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 2),
      );
      controller.toggleHighlight();
      expect(controller.text, '');

      controller.toggleBold();
      expect(controller.text, '****');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 2),
      );
      controller.toggleBold();
      expect(controller.text, '');
    });

    test('legacy list wrappers toggle paragraph styles', () {
      final controller = MemoComposerController(initialText: 'seed');
      addTearDown(controller.dispose);

      controller.applyTemplateContent('templated body');
      expect(controller.text, 'templated body');

      controller.textController.selection = TextSelection.collapsed(offset: 5);
      controller.insertUnorderedListMarker();
      expect(controller.text, '- templated body');

      controller.replaceText('templated body');
      controller.textController.selection = const TextSelection.collapsed(
        offset: 5,
      );
      controller.insertOrderedListMarker();
      expect(controller.text, '1. templated body');

      controller.replaceText('templated body');
      controller.textController.selection = const TextSelection.collapsed(
        offset: 5,
      );
      controller.insertTaskCheckbox();
      expect(controller.text, '- [ ] templated body');
    });

    test('unordered list wrapper applies to the current line', () {
      final controller = MemoComposerController(initialText: '11111\n2222');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 10,
      );
      controller.insertUnorderedListMarker();

      expect(controller.text, '11111\n- 2222');
    });

    test('ordered list wrapper applies to the current line', () {
      final controller = MemoComposerController(initialText: '11111\n2222');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 10,
      );
      controller.insertOrderedListMarker();

      expect(controller.text, '11111\n1. 2222');
    });

    test('task list wrapper applies to the current line', () {
      final controller = MemoComposerController(initialText: '11111\n2222');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 10,
      );
      controller.insertTaskCheckbox();

      expect(controller.text, '11111\n- [ ] 2222');
    });

    test('heading wrapper applies to the current line', () {
      final controller = MemoComposerController(initialText: '11111\n2222');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 10,
      );
      controller.toggleHeading2();

      expect(controller.text, '11111\n## 2222');
    });

    test('quote wrapper applies to the current line', () {
      final controller = MemoComposerController(initialText: '11111\n2222');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 10,
      );
      controller.toggleQuote();

      expect(controller.text, '11111\n> 2222');
    });

    test('inserts markdown snippets with expected cursor placement', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);

      controller.insertCodeBlock();
      expect(controller.text, '```\n\n```');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 4),
      );

      controller.replaceText('');
      controller.insertInlineMath();
      expect(controller.text, '\$\$'.replaceAll('\\', ''));
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 1),
      );

      controller.replaceText('');
      controller.insertBlockMath();
      expect(controller.text, '\$\$\n\n\$\$'.replaceAll('\\', ''));
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 3),
      );

      controller.replaceText('');
      controller.insertTableTemplate();
      expect(
        controller.text,
        '| Column 1 | Column 2 |\n| --- | --- |\n| Value 1 | Value 2 |',
      );
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 2),
      );
    });

    test('cuts current paragraph only after clipboard succeeds', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance;
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      String? copiedText;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );

      final controller = MemoComposerController(initialText: 'first\n\nsecond');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 2,
      );

      final result = await controller.cutCurrentParagraphs();

      expect(result, isTrue);
      expect(copiedText, 'first');
      expect(controller.text, 'second');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 0),
      );
    });

    test('cuts the current line only after clipboard succeeds', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance;
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      String? copiedText;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );

      final controller = MemoComposerController(
        initialText: '11111\n2222\n\n3333',
      );
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 8,
      );

      final result = await controller.cutCurrentParagraphs();

      expect(result, isTrue);
      expect(copiedText, '2222');
      expect(controller.text, '11111\n\n3333');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 6),
      );
    });

    test('keeps text untouched when clipboard cut fails', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance;
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-error');
          }
          return null;
        },
      );

      final controller = MemoComposerController(initialText: 'first\n\nsecond');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 2,
      );

      final result = await controller.cutCurrentParagraphs();

      expect(result, isFalse);
      expect(controller.text, 'first\n\nsecond');
    });

    test('navigates and applies tag autocomplete suggestions', () {
      final controller = MemoComposerController(initialText: 'See #wo');
      addTearDown(controller.dispose);
      final tags = <TagStat>[
        const TagStat(tag: 'work', path: 'work', count: 3),
        const TagStat(tag: 'world', path: 'world', count: 2),
        const TagStat(tag: 'personal', path: 'personal', count: 1),
      ];

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      controller.syncTagAutocompleteState(tagStats: tags, hasFocus: true);

      expect(
        controller
            .currentTagSuggestions(tags, hasFocus: true)
            .map((tag) => tag.path)
            .toList(),
        <String>['work', 'world'],
      );
      expect(controller.tagAutocompleteIndex, 0);

      final moved = controller.handleTagAutocompleteKeyEvent(
        KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
        ),
        tagStats: tags,
        hasFocus: true,
      );
      expect(moved, KeyEventResult.handled);
      expect(controller.tagAutocompleteIndex, 1);

      final applied = controller.handleTagAutocompleteKeyEvent(
        KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
        ),
        tagStats: tags,
        hasFocus: true,
      );
      expect(applied, KeyEventResult.handled);
      expect(controller.text, 'See #world ');
      expect(controller.tagAutocompleteToken, isNull);
    });

    test('manages pending attachments', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const first = MemoComposerPendingAttachment(
        uid: 'a1',
        filePath: '/tmp/1.png',
        filename: '1.png',
        mimeType: 'image/png',
        size: 10,
      );

      controller.addPendingAttachments(const [first]);
      expect(controller.pendingAttachments, hasLength(1));

      controller.replacePendingAttachment(
        'a1',
        first.copyWith(filename: 'updated.png', size: 12),
      );
      expect(controller.pendingAttachments.single.filename, 'updated.png');
      expect(controller.pendingAttachments.single.size, 12);

      expect(controller.removePendingAttachment('a1'), isTrue);
      expect(controller.pendingAttachments, isEmpty);
    });

    test('deduplicates pending attachments by uid', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const first = MemoComposerPendingAttachment(
        uid: 'same',
        filePath: '/tmp/1.png',
        filename: '1.png',
        mimeType: 'image/png',
        size: 10,
      );
      const duplicateUid = MemoComposerPendingAttachment(
        uid: 'same',
        filePath: '/tmp/2.png',
        filename: '2.png',
        mimeType: 'image/png',
        size: 20,
      );

      controller.addPendingAttachments(const [first, duplicateUid]);

      expect(controller.pendingAttachments, hasLength(1));
      expect(controller.pendingAttachments.single.filePath, '/tmp/1.png');
    });

    test('tracks pending attachment readiness status', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const ready = MemoComposerPendingAttachment(
        uid: 'ready',
        filePath: '/tmp/ready.png',
        filename: 'ready.png',
        mimeType: 'image/png',
        size: 10,
      );
      const staging = MemoComposerPendingAttachment(
        uid: 'staging',
        filePath: '/tmp/staging.png',
        filename: 'staging.png',
        mimeType: 'image/png',
        size: 20,
        processingStatus: AttachmentProcessingStatus.staging,
      );

      controller.addPendingAttachments(const [ready, staging]);

      expect(controller.readyPendingAttachmentCount, 1);
      expect(controller.hasUnreadyPendingAttachments, isTrue);
      expect(controller.unreadyPendingAttachments.single.uid, 'staging');

      final updated = controller.updatePendingAttachment(
        'staging',
        (current) => current.copyWith(
          processingStatus: AttachmentProcessingStatus.ready,
        ),
      );

      expect(updated, isTrue);
      expect(controller.readyPendingAttachmentCount, 2);
      expect(controller.hasUnreadyPendingAttachments, isFalse);
    });

    test('manages linked memos without duplicates', () {
      final controller = MemoComposerController();
      addTearDown(controller.dispose);
      const memo = MemoComposerLinkedMemo(name: 'memos/1', label: 'First');

      expect(controller.addLinkedMemo(memo), isTrue);
      expect(controller.addLinkedMemo(memo), isFalse);
      expect(controller.linkedMemoNames, <String>{'memos/1'});

      expect(controller.removeLinkedMemo('memos/1'), isTrue);
      expect(controller.linkedMemos, isEmpty);

      controller.addLinkedMemo(memo);
      controller.clearLinkedMemos();
      expect(controller.linkedMemos, isEmpty);
    });
  });
}
