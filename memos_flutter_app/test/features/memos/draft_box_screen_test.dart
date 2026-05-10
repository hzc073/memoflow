import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/memoflow_palette.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/data/models/memo_relation.dart';
import 'package:memos_flutter_app/data/models/shortcut.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/features/memos/draft_box_navigation_screen.dart';
import 'package:memos_flutter_app/features/memos/memo_editor_screen.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';
import 'package:memos_flutter_app/features/memos/note_input_sheet.dart';
import 'package:memos_flutter_app/features/memos/widgets/draft_box_memo_card.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/compose_draft_provider.dart';
import 'package:memos_flutter_app/state/memos/memo_composer_state.dart';
import 'package:memos_flutter_app/state/memos/memo_editor_controller.dart';
import 'package:memos_flutter_app/state/memos/memo_editor_draft_provider.dart';
import 'package:memos_flutter_app/state/memos/memo_editor_providers.dart';
import 'package:memos_flutter_app/state/memos/memos_list_providers.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/note_draft_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/user_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      find.text(
        DateFormat('yyyy-MM-dd HH:mm').format(draft.updatedTime.toLocal()),
      ),
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

    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-open-draft-1')),
    );
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
    await tester.pump(const Duration(seconds: 21));
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

  testWidgets('card refreshes markdown when the same draft uid changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardHarness(
        draft: _buildDraft(uid: 'draft-1', content: 'Original draft body'),
      ),
    );
    await tester.pumpAndSettle();

    final initialMarkdown = tester.widget<MemoMarkdown>(
      find.byType(MemoMarkdown),
    );
    expect(initialMarkdown.data, contains('Original draft body'));

    await tester.pumpWidget(
      _buildCardHarness(
        draft: _buildDraft(
          uid: 'draft-1',
          content: 'Updated draft body',
          updatedTime: DateTime.utc(2025, 1, 2, 3, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final updatedMarkdown = tester.widget<MemoMarkdown>(
      find.byType(MemoMarkdown),
    );
    expect(updatedMarkdown.data, contains('Updated draft body'));
    expect(updatedMarkdown.data, isNot(contains('Original draft body')));
    expect(updatedMarkdown.cacheKey, isNot(initialMarkdown.cacheKey));
  });

  testWidgets('navigation Draft Box selection opens note input in shell', (
    tester,
  ) async {
    final repository = _FakeComposeDraftRepository([
      _buildDraft(uid: 'draft-nav', content: 'Navigation draft content'),
    ]);
    addTearDown(repository.dispose);
    final container = _buildNavigationContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const MediaQuery(
              data: MediaQueryData(size: Size(430, 900)),
              child: DraftBoxNavigationScreen(
                presentation: HomeScreenPresentation.embeddedBottomNav,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-open-draft-nav')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DraftBoxNavigationScreen), findsOneWidget);
    expect(find.byType(NoteInputSheet), findsOneWidget);
    expect(find.text('Navigation draft content'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Edited from nav');
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();

    expect(find.byType(DraftBoxNavigationScreen), findsOneWidget);
    expect(find.byType(NoteInputSheet), findsNothing);
    final updatedCard = tester.widget<DraftBoxMemoCard>(
      find.byType(DraftBoxMemoCard),
    );
    expect(updatedCard.draft.snapshot.content, 'Edited from nav');
    final updatedMarkdown = tester.widget<MemoMarkdown>(
      find.byType(MemoMarkdown),
    );
    expect(updatedMarkdown.data, contains('Edited from nav'));
    expect(updatedMarkdown.data, isNot(contains('Navigation draft content')));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('edit drafts show label and open memo editor from navigation', (
    tester,
  ) async {
    final repository = _FakeComposeDraftRepository([
      _buildDraft(
        uid: 'edit-draft',
        content: 'Edited memo draft',
        kind: ComposeDraftKind.editMemo,
        targetMemoUid: 'memo-1',
      ),
    ]);
    addTearDown(repository.dispose);
    final container = _buildNavigationContainer(
      repository,
      resolvedMemos: <String, LocalMemo>{
        'memo-1': _buildLocalMemo(uid: 'memo-1', content: 'Original memo'),
      },
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const MediaQuery(
              data: MediaQueryData(size: Size(430, 900)),
              child: DraftBoxNavigationScreen(
                presentation: HomeScreenPresentation.embeddedBottomNav,
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpRouteFrames(tester);

    expect(find.text('Edit draft'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-open-edit-draft')),
    );
    await _pumpRouteFrames(tester);

    expect(find.byType(MemoEditorScreen), findsOneWidget);
    expect(find.text('Edited memo draft'), findsOneWidget);
    expect(find.byType(NoteInputSheet), findsNothing);
  });

  testWidgets('missing edit draft target stays in Draft Box', (tester) async {
    final repository = _FakeComposeDraftRepository([
      _buildDraft(
        uid: 'edit-draft-missing',
        content: 'Orphan edit draft',
        kind: ComposeDraftKind.editMemo,
      ),
    ]);
    addTearDown(repository.dispose);
    final container = _buildNavigationContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const MediaQuery(
              data: MediaQueryData(size: Size(430, 900)),
              child: DraftBoxNavigationScreen(
                presentation: HomeScreenPresentation.embeddedBottomNav,
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpRouteFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-open-edit-draft-missing')),
    );
    await _pumpRouteFrames(tester);

    expect(find.byType(MemoEditorScreen), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('draft-box-card-edit-draft-missing')),
      findsOneWidget,
    );
    expect(
      tester.widget<MemoMarkdown>(find.byType(MemoMarkdown)).data,
      contains('Orphan edit draft'),
    );
    expect(
      find.text(
        'The original memo cannot be opened right now. The edit draft remains in Draft Box.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('edit draft close can update the same Draft Box card', (
    tester,
  ) async {
    final repository = _FakeComposeDraftRepository([
      _buildDraft(
        uid: 'edit-draft',
        content: 'Old edit draft',
        kind: ComposeDraftKind.editMemo,
        targetMemoUid: 'memo-1',
      ),
    ]);
    addTearDown(repository.dispose);
    final container = _buildNavigationContainer(
      repository,
      resolvedMemos: <String, LocalMemo>{
        'memo-1': _buildLocalMemo(uid: 'memo-1', content: 'Original memo'),
      },
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const MediaQuery(
              data: MediaQueryData(size: Size(430, 900)),
              child: DraftBoxNavigationScreen(
                presentation: HomeScreenPresentation.embeddedBottomNav,
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpRouteFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('draft-box-open-edit-draft')),
    );
    await _pumpRouteFrames(tester);

    await tester.enterText(find.byType(TextField).first, 'Updated edit draft');
    await Navigator.of(
      tester.element(find.byType(MemoEditorScreen)),
    ).maybePop();
    await _pumpRouteFrames(tester);
    await tester.tap(find.text('Add to Draft Box'));
    await _pumpRouteFrames(tester);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byType(MemoEditorScreen), findsNothing);
    expect(find.byType(DraftBoxMemoCard), findsOneWidget);
    expect(
      repository.listDraftsSync.where((draft) => draft.isEditMemoDraft),
      hasLength(1),
    );
    expect(
      repository.listDraftsSync.single.snapshot.content,
      'Updated edit draft',
    );
    final updatedMarkdown = tester.widget<MemoMarkdown>(
      find.byType(MemoMarkdown),
    );
    expect(updatedMarkdown.data, contains('Updated edit draft'));
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

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump();
}

ProviderContainer _buildNavigationContainer(
  _FakeComposeDraftRepository repository, {
  Map<String, LocalMemo> resolvedMemos = const <String, LocalMemo>{},
}) {
  return ProviderContainer(
    overrides: [
      composeDraftRepositoryProvider.overrideWith((ref) => repository),
      memosListControllerProvider.overrideWith(
        (ref) => _FakeMemosListController(resolvedMemos),
      ),
      memoEditorDraftRepositoryProvider.overrideWith(
        (ref) => _FakeMemoEditorDraftRepository(),
      ),
      memoEditorControllerProvider.overrideWith(
        (ref) => _FakeMemoEditorController(),
      ),
      noteDraftRepositoryProvider.overrideWith(
        (ref) => _FakeNoteDraftRepository(),
      ),
      currentWorkspacePreferencesProvider.overrideWith(
        (ref) => _TestWorkspacePreferencesController(ref),
      ),
      workspacePreferencesLoadedProvider.overrideWith((ref) => true),
      tagStatsProvider.overrideWith((ref) => Stream.value(const <TagStat>[])),
      tagColorLookupProvider.overrideWith(
        (ref) => TagColorLookup(const <TagStat>[]),
      ),
      userGeneralSettingProvider.overrideWith(
        (ref) async => const UserGeneralSetting(),
      ),
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      syncCoordinatorProvider.overrideWith((ref) => _NoopSyncFacade()),
    ],
  );
}

class _FakeComposeDraftRepository implements ComposeDraftRepository {
  _FakeComposeDraftRepository(List<ComposeDraftRecord> drafts)
    : _drafts = List<ComposeDraftRecord>.of(drafts);

  final _changes = StreamController<void>.broadcast();
  final List<ComposeDraftRecord> _drafts;
  var _saveCount = 0;

  List<ComposeDraftRecord> get listDraftsSync =>
      List<ComposeDraftRecord>.of(_drafts);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  String get workspaceKey => 'workspace-1';

  Future<void> dispose() => _changes.close();

  @override
  Future<void> clearDrafts() async {
    _drafts.clear();
    _notifyChanged();
  }

  @override
  Future<void> deleteDraft(
    String uid, {
    Set<String> keepPaths = const <String>{},
  }) async {
    _drafts.removeWhere((draft) => draft.uid == uid);
    _notifyChanged();
  }

  @override
  Future<ComposeDraftRecord?> getByUid(String uid) async {
    return getByUidWithoutLegacyImport(uid);
  }

  @override
  Future<ComposeDraftRecord?> getByUidWithoutLegacyImport(String uid) async {
    final normalized = uid.trim();
    for (final draft in _drafts) {
      if (draft.uid == normalized) return draft;
    }
    return null;
  }

  @override
  Future<ComposeDraftRecord?> getEditDraftForMemo(String targetMemoUid) async {
    final normalized = targetMemoUid.trim();
    for (final draft in _drafts) {
      if (draft.isEditMemoDraft && draft.targetMemoUid == normalized) {
        return draft;
      }
    }
    return null;
  }

  @override
  Future<ComposeDraftRecord?> latestDraft() async {
    return _drafts.isEmpty ? null : _drafts.first;
  }

  @override
  Future<ComposeDraftRecord?> latestCreateDraft() async {
    for (final draft in _drafts) {
      if (draft.isCreateMemoDraft) return draft;
    }
    return null;
  }

  @override
  Future<List<ComposeDraftRecord>> listDrafts({int? limit}) async {
    return limit == null
        ? List<ComposeDraftRecord>.of(_drafts)
        : _drafts.take(limit).toList(growable: false);
  }

  @override
  Future<void> replaceAllDrafts(Iterable<ComposeDraftRecord> drafts) async {
    _drafts
      ..clear()
      ..addAll(drafts);
    _notifyChanged();
  }

  @override
  Future<void> deleteEditDraftForMemo(String targetMemoUid) async {
    final normalized = targetMemoUid.trim();
    _drafts.removeWhere(
      (draft) => draft.isEditMemoDraft && draft.targetMemoUid == normalized,
    );
    _notifyChanged();
  }

  @override
  Future<String?> saveSnapshot({
    String? draftUid,
    required ComposeDraftSnapshot snapshot,
  }) async {
    final normalizedUid = draftUid?.trim();
    if (!snapshot.hasSavableContent) {
      if (normalizedUid != null && normalizedUid.isNotEmpty) {
        _drafts.removeWhere((draft) => draft.uid == normalizedUid);
        _notifyChanged();
      }
      return null;
    }
    final uid = normalizedUid?.isNotEmpty == true
        ? normalizedUid!
        : 'draft-saved';
    final existingIndex = _drafts.indexWhere((draft) => draft.uid == uid);
    final existing = existingIndex < 0 ? null : _drafts[existingIndex];
    final now = DateTime.utc(2025, 1, 3, 0, 0, _saveCount++);
    final record = ComposeDraftRecord(
      uid: uid,
      workspaceKey: workspaceKey,
      snapshot: snapshot,
      createdTime: existing?.createdTime ?? now,
      updatedTime: now,
    );
    if (existingIndex < 0) {
      _drafts.add(record);
    } else {
      _drafts[existingIndex] = record;
    }
    _notifyChanged();
    return uid;
  }

  @override
  Future<String?> saveEditDraft({
    required String targetMemoUid,
    required ComposeDraftSnapshot snapshot,
    String? targetMemoContentFingerprint,
    DateTime? targetMemoUpdateTime,
  }) async {
    final normalizedTarget = targetMemoUid.trim();
    if (normalizedTarget.isEmpty || !snapshot.hasSavableContent) {
      return null;
    }
    final existingIndex = _drafts.indexWhere(
      (draft) =>
          draft.isEditMemoDraft && draft.targetMemoUid == normalizedTarget,
    );
    final existing = existingIndex < 0 ? null : _drafts[existingIndex];
    final now = DateTime.utc(2025, 1, 3, 0, 1, _saveCount++);
    final record = ComposeDraftRecord(
      uid: existing?.uid ?? 'edit-draft-saved',
      workspaceKey: workspaceKey,
      kind: ComposeDraftKind.editMemo,
      targetMemoUid: normalizedTarget,
      targetMemoContentFingerprint: targetMemoContentFingerprint,
      targetMemoUpdateTime: targetMemoUpdateTime,
      snapshot: snapshot,
      createdTime: existing?.createdTime ?? now,
      updatedTime: now,
    );
    if (existingIndex < 0) {
      _drafts.add(record);
    } else {
      _drafts[existingIndex] = record;
    }
    _notifyChanged();
    return record.uid;
  }

  void _notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}

class _FakeNoteDraftRepository extends NoteDraftRepository {
  _FakeNoteDraftRepository()
    : super(const FlutterSecureStorage(), accountKey: 'workspace-1');

  String _stored = '';

  @override
  Future<String> read() async => _stored;

  @override
  Future<void> write(String text) async {
    _stored = text;
  }

  @override
  Future<void> clear() async {
    _stored = '';
  }
}

class _FakeMemoEditorDraftRepository extends MemoEditorDraftRepository {
  _FakeMemoEditorDraftRepository()
    : super(const FlutterSecureStorage(), accountKey: 'workspace-1');

  final _stored = <String, String>{};

  @override
  Future<String> read({required String memoUid}) async =>
      _stored[memoUid.trim()] ?? '';

  @override
  Future<void> write({required String memoUid, required String text}) async {
    final uid = memoUid.trim();
    if (uid.isEmpty) return;
    _stored[uid] = text;
  }

  @override
  Future<void> clear({required String memoUid}) async {
    _stored.remove(memoUid.trim());
  }
}

class _FakeMemoEditorController implements MemoEditorController {
  @override
  Future<List<MemoRelation>> listMemoRelationsAll({
    required String memoUid,
  }) async {
    return const <MemoRelation>[];
  }

  @override
  Future<void> saveMemo({
    required LocalMemo? existing,
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required DateTime createTime,
    required DateTime now,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required bool locationChanged,
    required int relationCount,
    required bool hasPrimaryChanges,
    required List<Attachment> attachmentsToDelete,
    required bool includeRelations,
    required List<Map<String, dynamic>> relations,
    required bool shouldSyncAttachments,
    required bool hasPendingAttachments,
    required List<MemoEditorPendingAttachment> pendingAttachments,
  }) async {}
}

class _FakeMemosListController implements MemosListController {
  _FakeMemosListController(this._memosByUid);

  final Map<String, LocalMemo> _memosByUid;

  @override
  Future<void> logEmptyViewDiagnostics({
    required String queryKey,
    required String state,
    required int providerCount,
    required int animatedCount,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useAiSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) async {}

  @override
  Future<void> createQuickInputMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
  }) async {}

  @override
  Future<int> retryOutboxErrors({required String memoUid}) async => 0;

  @override
  Future<void> createInlineComposeMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required List<Map<String, dynamic>> relations,
    required List<MemoComposerPendingAttachment> pendingAttachments,
    MemoLocation? location,
  }) async {}

  @override
  Future<void> updateMemo(
    LocalMemo memo, {
    bool? pinned,
    String? state,
  }) async {}

  @override
  Future<void> adjustMemoTime({
    required LocalMemo memo,
    required DateTime selectedTime,
  }) async {}

  @override
  Future<void> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
  }) async {}

  @override
  Future<void> deleteMemo(
    LocalMemo memo, {
    void Function()? onMovedToRecycleBin,
  }) async {}

  @override
  Future<bool> hasAnyLocalMemos() async => _memosByUid.isNotEmpty;

  @override
  Future<MemosListMemoResolveResult> resolveMemoForOpen({
    required String uid,
  }) async {
    final memo = _memosByUid[uid.trim()];
    return memo == null
        ? const MemosListMemoResolveResult.notFound()
        : MemosListMemoResolveResult.found(memo);
  }

  @override
  Future<Shortcut> createShortcut({
    required String title,
    required String filter,
  }) async {
    return Shortcut(
      name: 'shortcuts/shortcut-1',
      id: 'shortcut-1',
      title: title,
      filter: filter,
    );
  }
}

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository()
    : super(
        PreferencesMigrationService(const FlutterSecureStorage()),
        workspaceKey: 'workspace-1',
      );

  @override
  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() async {
    return StorageReadResult.success(WorkspacePreferences.defaults);
  }

  @override
  Future<WorkspacePreferences> read() async => WorkspacePreferences.defaults;

  @override
  Future<void> write(WorkspacePreferences prefs) async {}
}

class _TestWorkspacePreferencesController
    extends WorkspacePreferencesController {
  _TestWorkspacePreferencesController(Ref ref)
    : super(ref, _TestWorkspacePreferencesRepository()) {
    state = WorkspacePreferences.defaults;
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        AsyncValue.data(
          AppSessionState(
            accounts: [_testAccount],
            currentKey: _testAccountKey,
          ),
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
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }
}

class _NoopSyncFacade extends DesktopSyncFacade {
  _NoopSyncFacade() : super(SyncCoordinatorState.initial);

  @override
  void applyRemoteStateSnapshot(SyncCoordinatorState next) {
    state = next;
  }

  @override
  Future<WebDavExportCleanupStatus> cleanWebDavPlainExport() async {
    return WebDavExportCleanupStatus.notFound;
  }

  @override
  Future<WebDavSyncMeta?> cleanWebDavDeprecatedPlainFiles() async {
    return null;
  }

  @override
  Future<WebDavExportStatus> fetchWebDavExportStatus() async {
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
  Future<WebDavSyncMeta?> fetchWebDavSyncMeta() async {
    return null;
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listWebDavBackupSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return const <WebDavBackupSnapshotInfo>[];
  }

  @override
  Future<String> recoverWebDavBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    return '';
  }

  @override
  Future<SyncRunResult> requestSync(SyncRequest request) async {
    return const SyncRunStarted();
  }

  @override
  Future<SyncRunResult> requestWebDavBackup({
    required SyncRequestReason reason,
    String? password,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    return const SyncRunStarted();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<void> resolveLocalScanConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> retryPending() async {}

  @override
  Future<WebDavConnectionTestResult> testWebDavConnection({
    required WebDavSettings settings,
  }) async {
    return const WebDavConnectionTestResult.success();
  }

  @override
  Future<SyncError?> verifyWebDavBackup({
    required String password,
    required bool deep,
  }) async {
    return null;
  }
}

const _testAccountKey = 'workspace-1';
final _testAccount = Account(
  key: _testAccountKey,
  baseUrl: Uri.parse('https://example.com'),
  personalAccessToken: 'token',
  user: User.empty(),
  instanceProfile: InstanceProfile.empty(),
);

ComposeDraftRecord _buildDraft({
  required String uid,
  required String content,
  String visibility = 'PRIVATE',
  ComposeDraftKind kind = ComposeDraftKind.createMemo,
  String? targetMemoUid,
  DateTime? updatedTime,
}) {
  final now = updatedTime ?? DateTime.utc(2025, 1, 2, 3, 4, 5);
  return ComposeDraftRecord(
    uid: uid,
    workspaceKey: 'workspace-1',
    kind: kind,
    targetMemoUid: targetMemoUid,
    snapshot: ComposeDraftSnapshot(content: content, visibility: visibility),
    createdTime: now.subtract(const Duration(minutes: 1)),
    updatedTime: now,
  );
}

LocalMemo _buildLocalMemo({required String uid, required String content}) {
  final now = DateTime.utc(2025, 1, 2, 3, 4, 5);
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: 'fingerprint-$uid',
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: now,
    updateTime: now,
    tags: const <String>[],
    attachments: const <Attachment>[],
    relationCount: 0,
    location: null,
    syncState: SyncState.synced,
    lastError: null,
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
