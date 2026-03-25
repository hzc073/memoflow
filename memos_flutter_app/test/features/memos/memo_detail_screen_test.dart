import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/pointer_double_tap_listener.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/memo_relation.dart';
import 'package:memos_flutter_app/features/memos/memo_detail_screen.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('defers heavy detail sections until route transition settles', (
    tester,
  ) async {
    final memo = _buildMemo(
      content: 'Memo body for deferred detail sections',
      attachments: const [
        Attachment(
          name: 'attachments/doc-1',
          filename: 'notes.txt',
          type: 'text/plain',
          size: 12,
          externalLink: '',
        ),
      ],
    );

    await tester.pumpWidget(_buildTestApp(memo: memo));
    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MemoDetailScreen), findsOneWidget);
    expect(find.byType(MemoMarkdown), findsOneWidget);
    expect(find.text('Attachments'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('Attachments'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
  });

  test('detail markdown cache key changes with content fingerprint', () {
    final memoA = _buildMemo(uid: 'memo-1', content: 'first body');
    final memoB = _buildMemo(uid: 'memo-1', content: 'second body');

    expect(
      memoDetailMarkdownCacheKey(memoA, renderImages: false),
      isNot(equals(memoDetailMarkdownCacheKey(memoB, renderImages: false))),
    );
  });

  testWidgets('detail body enables double tap edit for normal memos', (
    tester,
  ) async {
    final memo = _buildMemo();

    await tester.pumpWidget(_buildTestApp(memo: memo));
    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pumpAndSettle();

    final listener = tester.widget<PointerDoubleTapListener>(
      find.byKey(const ValueKey('memo-detail-edit-hit-area')),
    );

    expect(listener.onDoubleTap, isNotNull);
  });

  testWidgets('detail body disables double tap edit for archived memos', (
    tester,
  ) async {
    final memo = _buildMemo(state: 'ARCHIVED');

    await tester.pumpWidget(_buildTestApp(memo: memo));
    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pumpAndSettle();

    final listener = tester.widget<PointerDoubleTapListener>(
      find.byKey(const ValueKey('memo-detail-edit-hit-area')),
    );

    expect(listener.onDoubleTap, isNull);
  });
}

Widget _buildTestApp({required LocalMemo memo}) {
  LocaleSettings.setLocale(AppLocale.en);
  return ProviderScope(
    overrides: [
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref),
      ),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
      memoRelationsProvider.overrideWith(
        (ref, memoUid) =>
            Stream<List<MemoRelation>>.value(const <MemoRelation>[]),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _DetailRouteLauncher(memo: memo),
      ),
    ),
  );
}

class _DetailRouteLauncher extends StatelessWidget {
  const _DetailRouteLauncher({required this.memo});

  final LocalMemo memo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('open-detail'),
          onPressed: () {
            Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 400),
                reverseTransitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (context, animation, secondaryAnimation) =>
                    MemoDetailScreen(initialMemo: memo),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            );
          },
          child: const Text('Open detail'),
        ),
      ),
    );
  }
}

LocalMemo _buildMemo({
  String uid = 'memo-1',
  String content = 'memo body',
  String state = 'NORMAL',
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
    updateTime: now,
    tags: const <String>[],
    attachments: attachments,
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
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
  _TestAppPreferencesRepository()
    : super(const FlutterSecureStorage(), accountKey: null);

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
