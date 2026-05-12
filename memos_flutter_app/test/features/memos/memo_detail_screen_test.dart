// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

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
import 'package:memos_flutter_app/data/models/memo.dart';
import 'package:memos_flutter_app/data/models/memo_relation.dart';
import 'package:memos_flutter_app/data/models/reaction.dart';
import 'package:memos_flutter_app/features/memos/memo_detail_screen.dart';
import 'package:memos_flutter_app/features/memos/memo_hero_flight.dart';
import 'package:memos_flutter_app/features/memos/memo_inline_image_syntax.dart';
import 'package:memos_flutter_app/features/memos/memo_markdown.dart';
import 'package:memos_flutter_app/features/memos/widgets/memo_engagement_surface.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memo_engagement_provider.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';
import 'package:path/path.dart' as p;

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

  test(
    'detail markdown cache key changes with local inline allowlist state',
    () {
      final localUrl = Uri.file(_tempPath('cache-owned-inline.jpg')).toString();
      final content = [
        'Article body',
        '<img src="$localUrl">',
        buildThirdPartyShareMemoMarker(),
      ].join('\n');
      final memoWithoutAttachment = _buildMemo(
        uid: 'memo-cache',
        content: content,
      );
      final memoWithAttachment = _buildMemo(
        uid: 'memo-cache',
        content: content,
        attachments: [_imageAttachment(localUrl)],
      );

      final withoutAttachment = buildMemoDocumentResolvedData(
        memo: memoWithoutAttachment,
        appLanguage: AppLanguage.en,
        clipCard: null,
        baseUrl: null,
        authHeader: null,
        rebaseAbsoluteFileUrlForV024: false,
        attachAuthForSameOriginAbsolute: false,
        richContentEnabled: true,
      );
      final withAttachment = buildMemoDocumentResolvedData(
        memo: memoWithAttachment,
        appLanguage: AppLanguage.en,
        clipCard: null,
        baseUrl: null,
        authHeader: null,
        rebaseAbsoluteFileUrlForV024: false,
        attachAuthForSameOriginAbsolute: false,
        richContentEnabled: true,
      );

      expect(
        withoutAttachment.markdownCacheKey,
        isNot(equals(withAttachment.markdownCacheKey)),
      );
    },
  );

  testWidgets('detail content passes image auth context to markdown', (
    tester,
  ) async {
    final baseUrl = Uri.parse('http://192.168.13.13:45230');
    const authHeader = 'Bearer detail-token';
    const inlineImageSrc = '/file/attachments/att-1/image.png';
    final content = [
      'Article body',
      '<img src="$inlineImageSrc" alt="inline">',
      buildThirdPartyShareMemoMarker(),
    ].join('\n');
    final memo = _buildMemo(content: content);
    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: true,
      attachAuthForSameOriginAbsolute: true,
      richContentEnabled: true,
    );

    await tester.pumpWidget(
      _buildPrimaryContentTestApp(resolvedData: resolvedData),
    );

    final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
    expect(markdown.baseUrl, baseUrl);
    expect(markdown.authHeader, authHeader);
    expect(markdown.rebaseAbsoluteFileUrlForV024, isTrue);
    expect(markdown.attachAuthForSameOriginAbsolute, isTrue);
    expect(markdown.renderImages, isTrue);

    final request = resolveMemoMarkdownRemoteImageRequest(
      rawSrc: inlineImageSrc,
      baseUrl: markdown.baseUrl,
      authHeader: markdown.authHeader,
      rebaseAbsoluteFileUrlForV024: markdown.rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: markdown.attachAuthForSameOriginAbsolute,
    );
    expect(request?.headers, {'Authorization': authHeader});
  });

  testWidgets('detail renders ordinary markdown images inline when expanded', (
    tester,
  ) async {
    const content =
        'Article body\n\n'
        '![inline](https://example.com/detail-inline.png)';
    final memo = _buildMemo(content: content);
    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: null,
      authHeader: null,
      rebaseAbsoluteFileUrlForV024: false,
      attachAuthForSameOriginAbsolute: false,
      richContentEnabled: true,
    );

    expect(resolvedData.effectiveRenderInlineImages, isTrue);
    expect(resolvedData.inlineImageSyntax, MemoInlineImageSyntax.markdownOnly);
    expect(
      resolvedData.markdownArtifact.content,
      contains('<img src="https://example.com/detail-inline.png"'),
    );
    expect(resolvedData.mediaEntries, isEmpty);

    await tester.pumpWidget(
      _buildPrimaryContentTestApp(resolvedData: resolvedData),
    );

    final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
    expect(markdown.renderImages, isTrue);
    expect(markdown.imageSyntax, MemoInlineImageSyntax.markdownOnly);
  });

  test('detail ordinary markdown image mode ignores raw html images', () {
    const content =
        'Article body\n\n'
        '<img src="https://example.com/detail-html.png">';
    final memo = _buildMemo(content: content);

    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: null,
      authHeader: null,
      rebaseAbsoluteFileUrlForV024: false,
      attachAuthForSameOriginAbsolute: false,
      richContentEnabled: true,
    );

    expect(resolvedData.effectiveRenderInlineImages, isFalse);
    expect(resolvedData.inlineImageSyntax, MemoInlineImageSyntax.none);
    expect(resolvedData.markdownArtifact.content, isNot(contains('<img')));
    expect(
      resolvedData.markdownArtifact.content,
      isNot(contains('https://example.com/detail-html.png')),
    );
  });

  testWidgets('detail collapsed body keeps markdown images disabled', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    final content =
        'Article body\n\n'
        '![inline](https://example.com/detail-inline.png)\n\n'
        '${'Long detail paragraph. ' * 80}';
    final memo = _buildMemo(content: content);
    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: null,
      authHeader: null,
      rebaseAbsoluteFileUrlForV024: false,
      attachAuthForSameOriginAbsolute: false,
      richContentEnabled: true,
    );

    await tester.pumpWidget(
      _buildPrimaryContentTestApp(resolvedData: resolvedData),
    );
    await tester.pump();

    var markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
    expect(markdown.renderImages, isTrue);
    expect(find.text('Collapse'), findsOneWidget);

    await tester.tap(find.text('Collapse'));
    await tester.pump();

    markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
    expect(markdown.renderImages, isFalse);
    expect(markdown.imageSyntax, MemoInlineImageSyntax.none);
  });

  test(
    'detail keeps unreferenced attachments after inline duplicate removal',
    () {
      const inlineUrl = 'https://example.com/inline.jpg';
      const otherUrl = 'https://example.com/other.jpg';
      final memo = _buildMemo(
        content: 'Article body\n\n![inline]($inlineUrl)',
        attachments: const [
          Attachment(
            name: 'attachments/inline',
            filename: 'inline.jpg',
            type: 'image/jpeg',
            size: 1,
            externalLink: inlineUrl,
          ),
          Attachment(
            name: 'attachments/other',
            filename: 'other.jpg',
            type: 'image/jpeg',
            size: 1,
            externalLink: otherUrl,
          ),
        ],
      );

      final resolvedData = buildMemoDocumentResolvedData(
        memo: memo,
        appLanguage: AppLanguage.en,
        clipCard: null,
        baseUrl: null,
        authHeader: null,
        rebaseAbsoluteFileUrlForV024: false,
        attachAuthForSameOriginAbsolute: false,
        richContentEnabled: true,
      );

      expect(resolvedData.effectiveRenderInlineImages, isTrue);
      expect(resolvedData.mediaEntries, hasLength(1));
      expect(resolvedData.mediaEntries.single.image?.isAttachment, isTrue);
      expect(resolvedData.mediaEntries.single.image?.fullUrl, otherUrl);
    },
  );

  testWidgets('detail allows current memo local attachment inline images', (
    tester,
  ) async {
    final localUrl = Uri.file(_tempPath('detail-owned-inline.jpg')).toString();
    final content = [
      'Article body',
      '<img src="$localUrl" width="100%">',
      buildThirdPartyShareMemoMarker(),
    ].join('\n');
    final memo = _buildMemo(
      content: content,
      attachments: [_imageAttachment(localUrl)],
    );

    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: null,
      authHeader: null,
      rebaseAbsoluteFileUrlForV024: false,
      attachAuthForSameOriginAbsolute: false,
      richContentEnabled: true,
    );

    expect(resolvedData.effectiveRenderInlineImages, isTrue);
    expect(
      resolvedData.inlineImageSourcePolicy.allowedLocalImageUrls,
      contains(localUrl),
    );
    expect(resolvedData.markdownArtifact.content, contains('<img'));
    expect(resolvedData.markdownArtifact.content, contains(localUrl));
    expect(resolvedData.imageEntries, hasLength(1));
    expect(resolvedData.imageEntries.single.isAttachment, isFalse);
    expect(resolvedData.mediaEntries.where((entry) => entry.isImage), isEmpty);

    await tester.pumpWidget(
      _buildPrimaryContentTestApp(resolvedData: resolvedData),
    );

    final markdown = tester.widget<MemoMarkdown>(find.byType(MemoMarkdown));
    expect(markdown.renderImages, isTrue);
    expect(markdown.allowedLocalImageUrls, contains(localUrl));
  });

  test('detail blocks unowned local inline image urls', () {
    final localUrl = Uri.file(
      _tempPath('detail-unowned-inline.jpg'),
    ).toString();
    final content = [
      'Article body',
      '<img src="$localUrl">',
      buildThirdPartyShareMemoMarker(),
    ].join('\n');
    final memo = _buildMemo(content: content);

    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: null,
      authHeader: null,
      rebaseAbsoluteFileUrlForV024: false,
      attachAuthForSameOriginAbsolute: false,
      richContentEnabled: true,
    );

    expect(resolvedData.inlineImageSourcePolicy.allowedLocalImageUrls, isEmpty);
    expect(resolvedData.markdownArtifact.content, isNot(contains('<img')));
    expect(resolvedData.markdownArtifact.content, isNot(contains(localUrl)));
  });

  test('detail does not allow host-mutated file urls', () {
    final localPath = _tempPath('detail-host-mutated-inline.jpg');
    final canonicalUrl = Uri.file(localPath).toString();
    final hostMutatedUrl = canonicalUrl.replaceFirst(
      'file:///',
      'file://data/',
    );
    final content = [
      'Article body',
      '<img src="$hostMutatedUrl">',
      buildThirdPartyShareMemoMarker(),
    ].join('\n');
    final memo = _buildMemo(
      content: content,
      attachments: [_imageAttachment(canonicalUrl)],
    );

    final resolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: AppLanguage.en,
      clipCard: null,
      baseUrl: null,
      authHeader: null,
      rebaseAbsoluteFileUrlForV024: false,
      attachAuthForSameOriginAbsolute: false,
      richContentEnabled: true,
    );

    expect(resolvedData.inlineImageSourcePolicy.allowedLocalImageUrls, isEmpty);
    expect(resolvedData.markdownArtifact.content, isNot(contains('<img')));
    expect(
      resolvedData.markdownArtifact.content,
      isNot(contains(hostMutatedUrl)),
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

  testWidgets('detail route keeps a stable hero tag based on memo identity', (
    tester,
  ) async {
    final memo = _buildMemo(uid: 'memo-hero');

    await tester.pumpWidget(_buildTestApp(memo: memo));

    final launcherHero = tester.widget<Hero>(find.byType(Hero));
    expect(launcherHero.tag, memoHeroTagForMemo(memo));

    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pump();
    await tester.pumpAndSettle();

    final detailHero = tester.widget<Hero>(find.byType(Hero).last);
    expect(detailHero.tag, memoHeroTagForMemo(memo));
  });

  testWidgets('detail engagement surface renders likes and comments', (
    tester,
  ) async {
    final memo = _buildMemo(uid: 'memo-engagement');

    await tester.pumpWidget(
      _buildTestApp(
        memo: memo,
        showEngagement: true,
        engagementClient: _FakeMemoEngagementClient(
          reactions: [_reaction()],
          comments: [_comment('detail comment')],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pumpAndSettle();

    expect(find.byKey(memoEngagementSurfaceKey), findsOneWidget);
    expect(find.text('Like 1'), findsOneWidget);
    expect(find.text('Comment 1'), findsOneWidget);
    expect(
      find.textContaining('detail comment', findRichText: true),
      findsOneWidget,
    );
  });
}

Widget _buildTestApp({
  required LocalMemo memo,
  bool showEngagement = false,
  MemoEngagementClient? engagementClient,
}) {
  LocaleSettings.setLocale(AppLocale.en);
  final overrides = <Override>[
    appSessionProvider.overrideWith((ref) => _TestSessionController()),
    appPreferencesProvider.overrideWith(
      (ref) => _TestAppPreferencesController(ref),
    ),
    tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
    memoRelationsProvider.overrideWith(
      (ref, memoUid) =>
          Stream<List<MemoRelation>>.value(const <MemoRelation>[]),
    ),
  ];
  if (engagementClient != null) {
    overrides.add(
      memoEngagementClientProvider.overrideWithValue(engagementClient),
    );
  }
  return ProviderScope(
    overrides: overrides,
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _DetailRouteLauncher(memo: memo, showEngagement: showEngagement),
      ),
    ),
  );
}

Widget _buildPrimaryContentTestApp({
  required MemoDocumentResolvedData resolvedData,
}) {
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
        home: Scaffold(
          body: MemoDocumentPrimaryContent(resolvedData: resolvedData),
        ),
      ),
    ),
  );
}

class _DetailRouteLauncher extends StatelessWidget {
  const _DetailRouteLauncher({
    required this.memo,
    required this.showEngagement,
  });

  final LocalMemo memo;
  final bool showEngagement;

  @override
  Widget build(BuildContext context) {
    final heroTag = memoHeroTagForMemo(memo);
    return Scaffold(
      body: Center(
        child: Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            child: ElevatedButton(
              key: const ValueKey('open-detail'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  PageRouteBuilder<void>(
                    transitionDuration: const Duration(milliseconds: 400),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 400,
                    ),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        MemoDetailScreen(
                          initialMemo: memo,
                          showEngagement: showEngagement,
                        ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: const Text('Open detail'),
            ),
          ),
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

Attachment _imageAttachment(String externalLink) {
  return Attachment(
    name: 'attachments/photo',
    filename: 'photo.jpg',
    type: 'image/jpeg',
    size: 1,
    externalLink: externalLink,
  );
}

String _tempPath(String filename) {
  return p.join(Directory.systemTemp.path, 'memo-detail-inline', filename);
}

Reaction _reaction({
  String name = 'reactions/reaction-1',
  String creator = 'users/me',
  String reactionType = '❤️',
}) {
  return Reaction(
    name: name,
    creator: creator,
    contentId: 'memos/memo-engagement',
    reactionType: reactionType,
  );
}

Memo _comment(String content) {
  final now = DateTime.utc(2024, 1, 2, 3, 4, 5);
  return Memo(
    name: 'memos/comment-1',
    creator: 'users/me',
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: now,
    updateTime: now,
    tags: const <String>[],
    attachments: const <Attachment>[],
  );
}

class _FakeMemoEngagementClient implements MemoEngagementClient {
  _FakeMemoEngagementClient({
    List<Reaction> reactions = const <Reaction>[],
    List<Memo> comments = const <Memo>[],
  }) : _reactions = List<Reaction>.from(reactions),
       _comments = List<Memo>.from(comments);

  List<Reaction> _reactions;
  final List<Memo> _comments;

  @override
  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  listMemoReactions({required String memoUid, int pageSize = 50}) async {
    return (
      reactions: List<Reaction>.from(_reactions),
      nextPageToken: '',
      totalSize: _reactions.length,
    );
  }

  @override
  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  listMemoComments({required String memoUid, int pageSize = 50}) async {
    return (
      memos: List<Memo>.from(_comments),
      nextPageToken: '',
      totalSize: _comments.length,
    );
  }

  @override
  Future<Reaction> upsertMemoReaction({
    required String memoUid,
    required String reactionType,
  }) async {
    final reaction = _reaction(reactionType: reactionType);
    _reactions.add(reaction);
    return reaction;
  }

  @override
  Future<void> deleteMemoReaction({required Reaction reaction}) async {
    _reactions = _reactions
        .where((item) => item.name != reaction.name)
        .toList();
  }

  @override
  Future<Memo> createMemoComment({
    required String memoUid,
    required String content,
    required String visibility,
  }) async {
    final comment = _comment(content);
    _comments.insert(0, comment);
    return comment;
  }
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
