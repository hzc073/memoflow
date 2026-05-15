import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/rss/rss_refresh_coordinator.dart';
import '../../application/rss/rss_feed_fetch_service.dart';
import '../../application/rss/rss_full_content_service.dart';
import '../../core/uid.dart';
import '../../data/models/collection_readable_item.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../data/models/rss_article.dart';
import '../../data/models/rss_feed.dart';
import '../../data/repositories/rss_repository.dart';
import '../memos/memo_mutation_service.dart';
import '../system/database_provider.dart';

final rssFeedFetchServiceProvider = Provider<RssFeedFetchService>((ref) {
  return RssFeedFetchService(
    repository: ref.watch(rssRepositoryProvider),
    fullContentService: ref.watch(rssFullContentServiceProvider),
  );
});

final rssFullContentServiceProvider = Provider<RssFullContentService>((ref) {
  return RssFullContentService(repository: ref.watch(rssRepositoryProvider));
});

final rssRefreshCoordinatorProvider = Provider<RssRefreshCoordinator>((ref) {
  return RssRefreshCoordinator(
    repository: ref.watch(rssRepositoryProvider),
    fetchService: ref.watch(rssFeedFetchServiceProvider),
  );
});

final collectionRssSourcesProvider =
    StreamProvider.family<List<CollectionRssSourceWithFeed>, String>((
      ref,
      collectionId,
    ) async* {
      final db = ref.watch(databaseProvider);
      final repository = ref.watch(rssRepositoryProvider);

      Future<List<CollectionRssSourceWithFeed>> load() =>
          repository.listCollectionRssSources(collectionId);

      yield await load();
      await for (final _ in db.changes) {
        yield await load();
      }
    });

final collectionRssArticlesProvider =
    StreamProvider.family<List<RssArticleWithFeed>, String>((
      ref,
      collectionId,
    ) async* {
      final db = ref.watch(databaseProvider);
      final repository = ref.watch(rssRepositoryProvider);

      Future<List<RssArticleWithFeed>> load() =>
          repository.listCollectionRssArticles(collectionId);

      yield await load();
      await for (final _ in db.changes) {
        yield await load();
      }
    });

final collectionRssActionsProvider = Provider<CollectionRssActions>((ref) {
  return CollectionRssActions(
    repository: ref.watch(rssRepositoryProvider),
    memoMutations: ref.watch(memoMutationServiceProvider),
    fullContentService: ref.watch(rssFullContentServiceProvider),
  );
});

class CollectionRssActions {
  CollectionRssActions({
    required RssRepository repository,
    required MemoMutationService memoMutations,
    RssFullContentService? fullContentService,
  }) : _repository = repository,
       _memoMutations = memoMutations,
       _fullContentService = fullContentService;

  final RssRepository _repository;
  final MemoMutationService _memoMutations;
  final RssFullContentService? _fullContentService;

  Future<void> markRead(CollectionReadableItem item, bool read) {
    final article = item.rssArticle;
    if (article == null) return Future<void>.value();
    return _repository.markArticleRead(articleId: article.id, read: read);
  }

  Future<String?> saveAsMemo(CollectionReadableItem item) async {
    final article = item.rssArticle;
    final feed = item.rssFeed;
    if (article == null || feed == null) return null;
    final existingSaved = article.savedMemoUid?.trim();
    if (existingSaved != null && existingSaved.isNotEmpty) {
      return existingSaved;
    }
    final currentArticle = await _repository.readArticleById(article.id);
    final currentSaved = currentArticle?.savedMemoUid?.trim();
    if (currentSaved != null && currentSaved.isNotEmpty) {
      return currentSaved;
    }
    final uid = generateUid(length: 16);
    final now = DateTime.now();
    final effectiveArticle = currentArticle ?? article;
    final content = _buildSavedMemoContent(
      article: effectiveArticle,
      feed: feed,
    );
    await _memoMutations.createNoteInputMemo(
      uid: uid,
      content: content,
      visibility: 'PRIVATE',
      now: now,
      tags: const <String>[],
      attachments: const <Map<String, dynamic>>[],
      location: null,
      hasAttachments: false,
      relations: const <Map<String, dynamic>>[],
      attachmentPayloads: const <Map<String, dynamic>>[],
    );
    await _memoMutations.upsertMemoClipCardMetadata(
      MemoClipCardMetadata(
        memoUid: uid,
        clipKind: MemoClipKind.article,
        platform: MemoClipPlatform.web,
        sourceName: feed.displayTitle,
        sourceAvatarUrl: feed.iconUrl,
        authorName: effectiveArticle.author,
        authorAvatarUrl: '',
        sourceUrl: effectiveArticle.link.trim().isNotEmpty
            ? effectiveArticle.link.trim()
            : feed.siteUrl,
        leadImageUrl: effectiveArticle.leadImageUrl,
        parserTag: 'rss',
        createdTime: now,
        updatedTime: now,
      ),
    );
    await _repository.updateArticleSavedMemoUid(
      articleId: article.id,
      memoUid: uid,
    );
    return uid;
  }

  Future<RssFullContentFetchResult?> fetchFullContent(
    CollectionReadableItem item,
  ) {
    final article = item.rssArticle;
    final service = _fullContentService;
    if (article == null || service == null) {
      return Future<RssFullContentFetchResult?>.value();
    }
    return service.fetchArticle(article.id);
  }

  String _buildSavedMemoContent({
    required RssArticle article,
    required RssFeed feed,
  }) {
    final title = article.title.trim();
    final link = article.link.trim();
    final source = feed.displayTitle.trim();
    final body = article.readableHtml.trim();
    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.writeln('# $title');
      buffer.writeln();
    }
    if (source.isNotEmpty || link.isNotEmpty) {
      if (source.isNotEmpty && link.isNotEmpty) {
        buffer.writeln('Source: [$source]($link)');
      } else if (source.isNotEmpty) {
        buffer.writeln('Source: $source');
      } else {
        buffer.writeln('Source: $link');
      }
      buffer.writeln();
    }
    if (body.isNotEmpty) {
      buffer.writeln(body);
      buffer.writeln();
    }
    if (link.isNotEmpty) {
      buffer.writeln('Original: $link');
    }
    return buffer.toString().trim();
  }
}
