import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../data/models/memo_collection.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collections_provider.dart';
import 'collection_article_flow_screen.dart';
import 'collection_reader_screen.dart';
import 'collection_rss_open_refresh_gate.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionByIdProvider(collectionId));
    if (collectionAsync.isLoading && !collectionAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (collectionAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              resolveDesktopRouteAutomaticallyImplyLeading(
                context: context,
                automaticallyImplyLeading: true,
              ),
        ),
        body: Center(child: Text('${collectionAsync.error}')),
      );
    }
    final collection = collectionAsync.valueOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              resolveDesktopRouteAutomaticallyImplyLeading(
                context: context,
                automaticallyImplyLeading: true,
              ),
        ),
        body: Center(
          child: Text(context.t.strings.collections.collectionNotFound),
        ),
      );
    }
    final experience = resolveCollectionReadingExperience(collection);
    final screen = switch (experience) {
      CollectionReadingExperience.articleFlow => CollectionArticleFlowScreen(
        collectionId: collectionId,
      ),
      CollectionReadingExperience.continuousReader => CollectionReaderScreen(
        collectionId: collectionId,
      ),
    };
    if (!collection.isRss) {
      return screen;
    }
    return CollectionRssOpenRefreshGate(
      collectionId: collection.id,
      preferences: collection.view.rssRefresh,
      child: screen,
    );
  }
}
