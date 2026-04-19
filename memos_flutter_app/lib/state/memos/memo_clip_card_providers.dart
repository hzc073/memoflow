import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/memo_clip_card_metadata.dart';
import '../system/database_provider.dart';

final memoClipCardsProvider = StreamProvider<List<MemoClipCardMetadata>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchMemoClipCards().map(
        (rows) =>
            rows.map(MemoClipCardMetadata.fromDb).toList(growable: false),
      );
});

final memoClipCardMapProvider = Provider<Map<String, MemoClipCardMetadata>>((
  ref,
) {
  final asyncCards = ref.watch(memoClipCardsProvider);
  return asyncCards.maybeWhen(
    data: (cards) => {
      for (final card in cards) card.memoUid: card,
    },
    orElse: () => <String, MemoClipCardMetadata>{},
  );
});

final memoClipCardByUidProvider =
    Provider.family<MemoClipCardMetadata?, String>((ref, memoUid) {
      final map = ref.watch(memoClipCardMapProvider);
      return map[memoUid];
    });
