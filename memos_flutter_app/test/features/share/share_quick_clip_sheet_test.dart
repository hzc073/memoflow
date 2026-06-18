import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/share_quick_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_quick_clip_sheet.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('typing # shows tag suggestions and tapping applies tag', (
    tester,
  ) async {
    ShareQuickClipSubmission? submission;

    await tester.pumpWidget(
      _QuickClipSheetHarness(
        tagStats: const <TagStat>[
          TagStat(tag: 'work', count: 10),
          TagStat(tag: 'world', count: 5),
        ],
        payload: const SharePayload(
          type: SharePayloadType.text,
          text: 'https://example.com/article',
        ),
        onSubmission: (value) => submission = value,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-quick-clip')));
    await tester.pumpAndSettle();

    final tagField = find.byType(TextField);
    await tester.tap(tagField);
    await tester.enterText(tagField, '#wo');
    await tester.pumpAndSettle();

    expect(find.text('#work'), findsOneWidget);
    expect(find.text('#world'), findsOneWidget);

    await tester.tap(find.text('#world'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(tagField);
    expect(textField.controller!.text, '#world ');

    await tester.tap(find.text('Clip now'));
    await tester.pumpAndSettle();

    expect(submission, isNotNull);
    expect(submission!.tags, ['#world']);
  });

  testWidgets('tag suggestions follow caret position in quick clip input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _QuickClipSheetHarness(
        tagStats: const <TagStat>[
          TagStat(tag: 'work', count: 10),
          TagStat(tag: 'world', count: 5),
        ],
        payload: const SharePayload(
          type: SharePayloadType.text,
          text: 'https://example.com/article',
        ),
        onSubmission: (_) {},
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-quick-clip')));
    await tester.pumpAndSettle();

    final tagField = find.byType(TextField);
    await tester.tap(tagField);
    await tester.enterText(tagField, '#wo');
    await tester.pumpAndSettle();

    final initialSuggestionLeft = tester.getTopLeft(find.text('#world')).dx;

    await tester.enterText(tagField, '#hello #wo');
    await tester.pumpAndSettle();

    final movedSuggestionLeft = tester.getTopLeft(find.text('#world')).dx;
    expect(movedSuggestionLeft, greaterThan(initialSuggestionLeft));
  });
}

class _QuickClipSheetHarness extends StatelessWidget {
  const _QuickClipSheetHarness({
    required this.tagStats,
    required this.payload,
    required this.onSubmission,
  });

  final List<TagStat> tagStats;
  final SharePayload payload;
  final ValueChanged<ShareQuickClipSubmission?> onSubmission;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        tagStatsProvider.overrideWith((ref) async* {
          yield tagStats;
        }),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: FilledButton(
                    key: const ValueKey<String>('open-quick-clip'),
                    onPressed: () async {
                      final result = await showShareQuickClipSheet(
                        context,
                        payload: payload,
                      );
                      onSubmission(result);
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
