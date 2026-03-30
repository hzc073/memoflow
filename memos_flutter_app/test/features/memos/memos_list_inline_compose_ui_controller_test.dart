import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:memos_flutter_app/features/memos/memos_list_inline_compose_ui_controller.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_controller.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'attachDraftSync applies draft once and preserves later user edits',
    () async {
      final container = ProviderContainer();
      final draftProvider = StateProvider<AsyncValue<String>>(
        (ref) => const AsyncData<String>('saved draft'),
      );
      final composer = MemoComposerController();
      final focusNode = FocusNode();
      final controller = MemosListInlineComposeUiController(
        composer: composer,
        focusNode: focusNode,
        currentTagStats: () => const <TagStat>[],
        readDraft: () => container.read(draftProvider),
        listenDraft: (listener) => container.listen<AsyncValue<String>>(
          draftProvider,
          (previous, next) => listener(next),
        ),
        saveDraft: (_) {},
        busy: () => false,
      );
      addTearDown(() {
        controller.dispose();
        composer.dispose();
        focusNode.dispose();
        container.dispose();
      });

      controller.attachDraftSync();
      expect(composer.textController.text, 'saved draft');
      expect(controller.draftApplied, isTrue);

      composer.textController.text = 'user changed text';
      container.read(draftProvider.notifier).state = const AsyncData<String>(
        'new draft from provider',
      );
      await Future<void>.delayed(Duration.zero);

      expect(composer.textController.text, 'user changed text');
    },
  );

  test('undo is blocked while mutation busy and works when idle', () {
    final container = ProviderContainer();
    final draftProvider = StateProvider<AsyncValue<String>>(
      (ref) => const AsyncData<String>(''),
    );
    final composer = MemoComposerController(initialText: 'first');
    final focusNode = FocusNode();
    var busy = true;
    final controller = MemosListInlineComposeUiController(
      composer: composer,
      focusNode: focusNode,
      currentTagStats: () => const <TagStat>[],
      readDraft: () => container.read(draftProvider),
      listenDraft: (listener) => container.listen<AsyncValue<String>>(
        draftProvider,
        (previous, next) => listener(next),
      ),
      saveDraft: (_) {},
      busy: () => busy,
    );
    addTearDown(() {
      controller.dispose();
      composer.dispose();
      focusNode.dispose();
      container.dispose();
    });

    composer.textController.text = 'second';
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(composer.textController.text, 'second');

    busy = false;
    controller.undo();
    expect(composer.textController.text, 'first');
  });

  test('shouldUseInlineComposeForCurrentWindow follows layout guards', () {
    final container = ProviderContainer();
    final draftProvider = StateProvider<AsyncValue<String>>(
      (ref) => const AsyncData<String>(''),
    );
    final composer = MemoComposerController();
    final focusNode = FocusNode();
    final controller = MemosListInlineComposeUiController(
      composer: composer,
      focusNode: focusNode,
      currentTagStats: () => const <TagStat>[],
      readDraft: () => container.read(draftProvider),
      listenDraft: (listener) => container.listen<AsyncValue<String>>(
        draftProvider,
        (previous, next) => listener(next),
      ),
      saveDraft: (_) {},
      busy: () => false,
    );
    addTearDown(() {
      controller.dispose();
      composer.dispose();
      focusNode.dispose();
      container.dispose();
    });

    expect(
      controller.shouldUseInlineComposeForCurrentWindow(
        enableCompose: false,
        searching: false,
        screenWidth: 1200,
      ),
      isFalse,
    );
    expect(
      controller.shouldUseInlineComposeForCurrentWindow(
        enableCompose: true,
        searching: true,
        screenWidth: 1200,
      ),
      isFalse,
    );
    expect(
      controller.shouldUseInlineComposeForCurrentWindow(
        enableCompose: true,
        searching: false,
        screenWidth: 759,
      ),
      isFalse,
    );
    expect(
      controller.shouldUseInlineComposeForCurrentWindow(
        enableCompose: true,
        searching: false,
        screenWidth: 760,
      ),
      isTrue,
    );
  });

  testWidgets(
    'resolveInlineVisibilityPresentation maps protected and private',
    (tester) async {
      final container = ProviderContainer();
      final draftProvider = StateProvider<AsyncValue<String>>(
        (ref) => const AsyncData<String>(''),
      );
      final composer = MemoComposerController();
      final focusNode = FocusNode();
      final controller = MemosListInlineComposeUiController(
        composer: composer,
        focusNode: focusNode,
        currentTagStats: () => const <TagStat>[],
        readDraft: () => container.read(draftProvider),
        listenDraft: (listener) => container.listen<AsyncValue<String>>(
          draftProvider,
          (previous, next) => listener(next),
        ),
        saveDraft: (_) {},
        busy: () => false,
      );
      addTearDown(() {
        controller.dispose();
        composer.dispose();
        focusNode.dispose();
        container.dispose();
      });

      late MemosListInlineVisibilityPresentation protected;
      late MemosListInlineVisibilityPresentation fallback;
      await tester.pumpWidget(
        _buildHarness(
          child: Builder(
            builder: (context) {
              protected = controller.resolveInlineVisibilityPresentation(
                context,
                'PROTECTED',
              );
              fallback = controller.resolveInlineVisibilityPresentation(
                context,
                'unexpected',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(protected.icon, Icons.verified_user);
      expect(protected.label, isNotEmpty);
      expect(fallback.icon, Icons.lock);
      expect(fallback.label, isNotEmpty);
    },
  );
}

Widget _buildHarness({required Widget child}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    ),
  );
}
