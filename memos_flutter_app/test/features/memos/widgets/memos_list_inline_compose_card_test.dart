import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_inline_compose_card.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_controller.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_state.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  testWidgets('desktop viewport height switches editor to expands mode', (
    tester,
  ) async {
    final composer = MemoComposerController(initialText: 'hello');
    final focusNode = FocusNode();
    InlineComposeLayoutMetrics? metrics;
    addTearDown(() {
      focusNode.dispose();
      composer.dispose();
    });

    await tester.pumpWidget(
      _TestCardHost(
        child: MemosListInlineComposeCard(
          composer: composer,
          focusNode: focusNode,
          pendingDraftCount: 0,
          busy: false,
          locating: false,
          location: null,
          visibility: 'PRIVATE',
          visibilityTouched: false,
          visibilityLabel: 'Private',
          visibilityIcon: Icons.lock_outline,
          visibilityColor: Colors.blue,
          isDark: false,
          tagStats: const <TagStat>[],
          availableTemplates: const <MemoTemplate>[],
          tagColorLookup: TagColorLookup(const <TagStat>[]),
          toolbarPreferences: AppPreferences.defaults.memoToolbarPreferences,
          editorFieldKey: GlobalKey(),
          tagMenuKey: GlobalKey(),
          templateMenuKey: GlobalKey(),
          todoMenuKey: GlobalKey(),
          visibilityMenuKey: GlobalKey(),
          onSubmit: () {},
          onRemoveAttachment: (_) {},
          onOpenAttachment: (_) {},
          onRemoveLinkedMemo: (_) {},
          onRequestLocation: () {},
          onClearLocation: () {},
          onOpenTemplateMenu: () {},
          onPickGallery: () {},
          onPickFile: () {},
          onOpenLinkMemo: () {},
          onCaptureCamera: () {},
          onOpenDraftBox: () {},
          onOpenTodoMenu: () {},
          onOpenVisibilityMenu: () {},
          onCutParagraphs: () {},
          desktopEditorViewportHeight: 180,
          onLayoutMetricsChanged: (value) => metrics = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.expands, isTrue);
    expect(field.minLines, isNull);
    expect(field.maxLines, isNull);
    expect(metrics, isNotNull);
    expect(metrics!.editorViewportHeight, closeTo(180, 0.1));
    expect(metrics!.chromeHeight, greaterThan(0));
    expect(metrics!.totalHeight, greaterThan(metrics!.editorViewportHeight));
  });

  testWidgets(
    'controlled desktop viewport reports attachment preview as chrome',
    (tester) async {
      final composer = MemoComposerController(initialText: 'hello');
      final focusNode = FocusNode();
      InlineComposeLayoutMetrics? metrics;
      addTearDown(() {
        focusNode.dispose();
        composer.dispose();
      });

      await tester.pumpWidget(
        _TestCardHost(
          child: MemosListInlineComposeCard(
            composer: composer,
            focusNode: focusNode,
            pendingDraftCount: 0,
            busy: false,
            locating: false,
            location: null,
            visibility: 'PRIVATE',
            visibilityTouched: false,
            visibilityLabel: 'Private',
            visibilityIcon: Icons.lock_outline,
            visibilityColor: Colors.blue,
            isDark: false,
            tagStats: const <TagStat>[],
            availableTemplates: const <MemoTemplate>[],
            tagColorLookup: TagColorLookup(const <TagStat>[]),
            toolbarPreferences: AppPreferences.defaults.memoToolbarPreferences,
            editorFieldKey: GlobalKey(),
            tagMenuKey: GlobalKey(),
            templateMenuKey: GlobalKey(),
            todoMenuKey: GlobalKey(),
            visibilityMenuKey: GlobalKey(),
            onSubmit: () {},
            onRemoveAttachment: (_) {},
            onOpenAttachment: (_) {},
            onRemoveLinkedMemo: (_) {},
            onRequestLocation: () {},
            onClearLocation: () {},
            onOpenTemplateMenu: () {},
            onPickGallery: () {},
            onPickFile: () {},
            onOpenLinkMemo: () {},
            onCaptureCamera: () {},
            onOpenDraftBox: () {},
            onOpenTodoMenu: () {},
            onOpenVisibilityMenu: () {},
            onCutParagraphs: () {},
            desktopEditorViewportHeight: 180,
            onLayoutMetricsChanged: (value) => metrics = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialMetrics = metrics;
      expect(initialMetrics, isNotNull);

      composer.addPendingAttachments([
        const MemoComposerPendingAttachment(
          uid: 'att-1',
          filePath: 'Z:/does-not-exist.png',
          filename: 'photo.png',
          mimeType: 'image/png',
          size: 42,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(metrics, isNotNull);
      expect(metrics!.editorViewportHeight, closeTo(180, 0.1));
      expect(metrics!.chromeHeight, greaterThan(initialMetrics!.chromeHeight));
      expect(
        metrics!.chromeHeight - initialMetrics.chromeHeight,
        closeTo(72, 2),
      );
      expect(
        metrics!.totalHeight,
        closeTo(metrics!.chromeHeight + metrics!.editorViewportHeight, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('default mode keeps line-based sizing', (tester) async {
    final composer = MemoComposerController(initialText: 'hello');
    final focusNode = FocusNode();
    addTearDown(() {
      focusNode.dispose();
      composer.dispose();
    });

    await tester.pumpWidget(
      _TestCardHost(
        child: MemosListInlineComposeCard(
          composer: composer,
          focusNode: focusNode,
          pendingDraftCount: 0,
          busy: false,
          locating: false,
          location: null,
          visibility: 'PRIVATE',
          visibilityTouched: false,
          visibilityLabel: 'Private',
          visibilityIcon: Icons.lock_outline,
          visibilityColor: Colors.blue,
          isDark: false,
          tagStats: const <TagStat>[],
          availableTemplates: const <MemoTemplate>[],
          tagColorLookup: TagColorLookup(const <TagStat>[]),
          toolbarPreferences: AppPreferences.defaults.memoToolbarPreferences,
          editorFieldKey: GlobalKey(),
          tagMenuKey: GlobalKey(),
          templateMenuKey: GlobalKey(),
          todoMenuKey: GlobalKey(),
          visibilityMenuKey: GlobalKey(),
          onSubmit: () {},
          onRemoveAttachment: (_) {},
          onOpenAttachment: (_) {},
          onRemoveLinkedMemo: (_) {},
          onRequestLocation: () {},
          onClearLocation: () {},
          onOpenTemplateMenu: () {},
          onPickGallery: () {},
          onPickFile: () {},
          onOpenLinkMemo: () {},
          onCaptureCamera: () {},
          onOpenDraftBox: () {},
          onOpenTodoMenu: () {},
          onOpenVisibilityMenu: () {},
          onCutParagraphs: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.expands, isFalse);
    expect(field.minLines, isNotNull);
    expect(field.maxLines, isNotNull);
  });

  testWidgets(
    'controlled desktop height keeps tag autocomplete behavior working',
    (tester) async {
      final composer = MemoComposerController(initialText: '#wo');
      final focusNode = FocusNode();
      const tagStats = <TagStat>[
        TagStat(tag: 'work', count: 10),
        TagStat(tag: 'world', count: 5),
      ];
      addTearDown(() {
        focusNode.dispose();
        composer.dispose();
      });

      await tester.pumpWidget(
        _TestCardHost(
          child: MemosListInlineComposeCard(
            composer: composer,
            focusNode: focusNode,
            pendingDraftCount: 0,
            busy: false,
            locating: false,
            location: null,
            visibility: 'PRIVATE',
            visibilityTouched: false,
            visibilityLabel: 'Private',
            visibilityIcon: Icons.lock_outline,
            visibilityColor: Colors.blue,
            isDark: false,
            tagStats: tagStats,
            availableTemplates: const <MemoTemplate>[],
            tagColorLookup: TagColorLookup(tagStats),
            toolbarPreferences: AppPreferences.defaults.memoToolbarPreferences,
            editorFieldKey: GlobalKey(),
            tagMenuKey: GlobalKey(),
            templateMenuKey: GlobalKey(),
            todoMenuKey: GlobalKey(),
            visibilityMenuKey: GlobalKey(),
            onSubmit: () {},
            onRemoveAttachment: (_) {},
            onOpenAttachment: (_) {},
            onRemoveLinkedMemo: (_) {},
            onRequestLocation: () {},
            onClearLocation: () {},
            onOpenTemplateMenu: () {},
            onPickGallery: () {},
            onPickFile: () {},
            onOpenLinkMemo: () {},
            onCaptureCamera: () {},
            onOpenDraftBox: () {},
            onOpenTodoMenu: () {},
            onOpenVisibilityMenu: () {},
            onCutParagraphs: () {},
            desktopEditorViewportHeight: 180,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(
        const ValueKey<String>('memos-inline-compose-text-field'),
      );
      await tester.tap(field);
      await tester.showKeyboard(field);
      focusNode.requestFocus();
      composer.textController.selection = TextSelection.collapsed(
        offset: composer.text.length,
      );
      composer.syncTagAutocompleteState(tagStats: tagStats, hasFocus: true);
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(composer.tagAutocompleteIndex, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(composer.tagAutocompleteIndex, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(composer.textController.text, '#world ');
    },
  );
}

class _TestCardHost extends StatelessWidget {
  const _TestCardHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Center(child: SizedBox(width: 700, child: child)),
        ),
      ),
    );
  }
}
