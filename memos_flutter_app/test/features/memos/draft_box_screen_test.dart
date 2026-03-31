import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memos_flutter_app/core/memoflow_palette.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/features/memos/widgets/draft_box_memo_card.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('renders draft cards with delete buttons instead of more menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardListHarness(
        drafts: [
          _buildDraft(uid: 'draft-1', content: 'First draft'),
          _buildDraft(uid: 'draft-2', content: 'Second draft'),
        ],
      ),
    );

    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('draft-box-card-draft-1')),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('shows time and localized visibility label', (tester) async {
    final draft = _buildDraft(
      uid: 'draft-1',
      content: 'Visible draft',
      visibility: 'PROTECTED',
      updatedTime: DateTime.utc(2025, 1, 2, 3, 4),
    );

    await tester.pumpWidget(_buildCardHarness(draft: draft));

    expect(find.text('Protected'), findsOneWidget);
    expect(
      find.text(DateFormat('yyyy-MM-dd HH:mm').format(draft.updatedTime.toLocal())),
      findsOneWidget,
    );
  });

  testWidgets('tapping card body triggers restore callback', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _buildCardHarness(
        draft: _buildDraft(uid: 'draft-1', content: 'Tap to open'),
        onTap: () => tapCount++,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('draft-box-open-draft-1')));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('tapping media opens preview instead of restore callback', (
    tester,
  ) async {
    final observer = _TestNavigatorObserver();
    var tapCount = 0;

    await tester.pumpWidget(
      _buildCardHarness(
        draft: _buildDraft(
          uid: 'draft-media',
          content: '![](https://example.com/photo.png)',
        ),
        onTap: () => tapCount++,
        navigatorObservers: [observer],
      ),
    );

    final initialPushCount = observer.pushCount;
    await tester.tap(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('draft-box-media-draft-media'),
            ),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(observer.pushCount, initialPushCount + 1);
    expect(tapCount, 0);
  });

  testWidgets('delete button shows confirmation dialog', (tester) async {
    await tester.pumpWidget(
      _DraftDeleteHarness(
        draft: _buildDraft(uid: 'draft-1', content: 'Draft'),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-delete-draft-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete draft'), findsOneWidget);
    expect(find.text('Delete this draft?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('confirming delete removes card and shows snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _DraftDeleteHarness(
        draft: _buildDraft(uid: 'draft-1', content: 'Draft'),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-delete-draft-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('draft-box-card-draft-1')),
      findsNothing,
    );
    expect(find.text('Draft deleted'), findsOneWidget);
  });

  testWidgets('selected draft shows editing badge and highlighted border', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardHarness(
        draft: _buildDraft(uid: 'draft-1', content: 'Editing draft'),
        selected: true,
      ),
    );

    expect(find.text('Editing'), findsOneWidget);
    final container = tester.widget<Container>(
      find.byKey(const ValueKey<String>('draft-box-card-draft-1')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, MemoFlowPalette.primary.withValues(alpha: 0.35));
  });
}

Widget _buildCardListHarness({required List<ComposeDraftRecord> drafts}) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (var index = 0; index < drafts.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == drafts.length - 1 ? 0 : 10,
                  ),
                  child: DraftBoxMemoCard(
                    draft: drafts[index],
                    selected: false,
                    onTap: () {},
                    onDelete: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildCardHarness({
  required ComposeDraftRecord draft,
  bool selected = false,
  VoidCallback? onTap,
  VoidCallback? onDelete,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorObservers: navigatorObservers,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: DraftBoxMemoCard(
                draft: draft,
                selected: selected,
                onTap: onTap ?? () {},
                onDelete: onDelete ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TestNavigatorObserver extends NavigatorObserver {
  var pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushCount++;
  }
}

ComposeDraftRecord _buildDraft({
  required String uid,
  required String content,
  String visibility = 'PRIVATE',
  DateTime? updatedTime,
}) {
  final now = updatedTime ?? DateTime.utc(2025, 1, 2, 3, 4, 5);
  return ComposeDraftRecord(
    uid: uid,
    workspaceKey: 'workspace-1',
    snapshot: ComposeDraftSnapshot(content: content, visibility: visibility),
    createdTime: now.subtract(const Duration(minutes: 1)),
    updatedTime: now,
  );
}

class _DraftDeleteHarness extends StatefulWidget {
  const _DraftDeleteHarness({required this.draft});

  final ComposeDraftRecord draft;

  @override
  State<_DraftDeleteHarness> createState() => _DraftDeleteHarnessState();
}

class _DraftDeleteHarnessState extends State<_DraftDeleteHarness> {
  var _deleted = false;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (screenContext) => Center(
                child: SizedBox(
                  width: 420,
                  child: _deleted
                      ? const SizedBox.shrink()
                      : DraftBoxMemoCard(
                          draft: widget.draft,
                          selected: false,
                          onTap: () {},
                          onDelete: () async {
                            final confirmed = await showDialog<bool>(
                              context: screenContext,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(
                                  dialogContext
                                      .t
                                      .strings
                                      .legacy
                                      .msg_delete_draft,
                                ),
                                content: Text(
                                  dialogContext
                                      .t
                                      .strings
                                      .legacy
                                      .msg_delete_draft_confirm,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: Text(
                                      dialogContext
                                          .t
                                          .strings
                                          .legacy
                                          .msg_cancel_2,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: Text(
                                      dialogContext.t.strings.legacy.msg_delete,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !mounted) return;
                            setState(() => _deleted = true);
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  screenContext
                                      .t
                                      .strings
                                      .legacy
                                      .msg_draft_deleted,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
