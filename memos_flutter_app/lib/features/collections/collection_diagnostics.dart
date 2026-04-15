import 'dart:convert';

import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';
import '../../state/collections/collection_resolver.dart';

String buildCollectionDiagnosticsReport({
  required MemoCollection collection,
  MemoCollectionPreview? preview,
  List<LocalMemo>? items,
}) {
  final report = <String, Object?>{
    'collection': <String, Object?>{
      'id': collection.id,
      'title': collection.title,
      'descriptionLength': collection.description.trim().length,
      'type': collection.type.name,
      'iconKey': collection.iconKey,
      'accentColorHex': collection.accentColorHex,
      'pinned': collection.pinned,
      'archived': collection.archived,
      'hideWhenEmpty': collection.hideWhenEmpty,
      'sortOrder': collection.sortOrder,
      'createdTime': collection.createdTime.toIso8601String(),
      'updatedTime': collection.updatedTime.toIso8601String(),
    },
    'rules': collection.rules.toJson(),
    'cover': collection.cover.toJson(),
    'view': collection.view.toJson(),
    if (preview != null)
      'preview': <String, Object?>{
        'itemCount': preview.itemCount,
        'imageItemCount': preview.imageItemCount,
        'latestUpdateTime': preview.latestUpdateTime?.toIso8601String(),
        'sampleMemoUids': preview.sampleItems
            .take(5)
            .map((item) => item.uid)
            .toList(growable: false),
        'ruleSummary': preview.ruleSummary,
        'effectiveAccentColorHex': preview.effectiveAccentColorHex,
        'coverAttachmentName': preview.coverAttachment?.name,
      },
    if (items != null)
      'resolvedItems': <String, Object?>{
        'count': items.length,
        'memoUids': items
            .take(10)
            .map((item) => item.uid)
            .toList(growable: false),
        'imageMemoCount': items
            .where((item) => item.attachments.any((a) => a.isImage))
            .length,
      },
  };

  return const JsonEncoder.withIndent('  ').convert(report);
}
