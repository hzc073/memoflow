import '../../data/models/attachment.dart';
import '../../data/models/collection_reader.dart';
import '../../data/models/local_memo.dart';

enum ReaderBlockKind {
  metaHeader,
  markdownText,
  image,
  video,
  attachmentList,
  location,
  spacer,
}

enum ReaderTextRole { body, heading, quote, code, listItem, tableRow }

class ReaderBlock {
  const ReaderBlock({
    required this.kind,
    required this.id,
    this.text,
    this.textRole = ReaderTextRole.body,
    this.attachments = const <Attachment>[],
    this.locationLabel,
    this.heightHint,
    this.charStart,
    this.charEnd,
  });

  final ReaderBlockKind kind;
  final String id;
  final String? text;
  final ReaderTextRole textRole;
  final List<Attachment> attachments;
  final String? locationLabel;
  final double? heightHint;
  final int? charStart;
  final int? charEnd;
}

class ReaderChapterDocument {
  const ReaderChapterDocument({
    required this.memo,
    required this.memoIndex,
    required this.blocks,
    required this.contentText,
  });

  final LocalMemo memo;
  final int memoIndex;
  final List<ReaderBlock> blocks;
  final String contentText;
}

class ReaderPageBlock {
  const ReaderPageBlock({
    required this.kind,
    required this.id,
    this.text,
    this.textRole = ReaderTextRole.body,
    this.attachments = const <Attachment>[],
    this.locationLabel,
    this.charStart,
    this.charEnd,
    this.height,
  });

  final ReaderBlockKind kind;
  final String id;
  final String? text;
  final ReaderTextRole textRole;
  final List<Attachment> attachments;
  final String? locationLabel;
  final int? charStart;
  final int? charEnd;
  final double? height;
}

class ReaderPageReservedInsets {
  const ReaderPageReservedInsets({
    required this.top,
    required this.bottom,
  });

  static const zero = ReaderPageReservedInsets(top: 0, bottom: 0);

  final double top;
  final double bottom;
}

class ReaderTipRenderData {
  const ReaderTipRenderData({
    required this.mode,
    required this.leftSlot,
    required this.centerSlot,
    required this.rightSlot,
  });

  final CollectionReaderTipDisplayMode mode;
  final CollectionReaderTipSlot leftSlot;
  final CollectionReaderTipSlot centerSlot;
  final CollectionReaderTipSlot rightSlot;
}

class ReaderTitleRenderData {
  const ReaderTitleRenderData({
    required this.title,
    required this.subtitle,
    required this.mode,
  });

  final String title;
  final String subtitle;
  final CollectionReaderTitleMode mode;
}

class ReaderPage {
  const ReaderPage({
    required this.memoUid,
    required this.memoIndex,
    required this.chapterPageIndex,
    required this.contentCharStart,
    required this.contentCharEnd,
    required this.blocks,
    required this.isFirstPage,
    required this.isLastPage,
    required this.reservedInsets,
    required this.headerTip,
    required this.footerTip,
    required this.title,
  });

  final String memoUid;
  final int memoIndex;
  final int chapterPageIndex;
  final int contentCharStart;
  final int contentCharEnd;
  final List<ReaderPageBlock> blocks;
  final bool isFirstPage;
  final bool isLastPage;
  final ReaderPageReservedInsets reservedInsets;
  final ReaderTipRenderData? headerTip;
  final ReaderTipRenderData? footerTip;
  final ReaderTitleRenderData? title;

  String get cacheKey => '$memoUid:$chapterPageIndex';
}

class ReaderChapterLayout {
  const ReaderChapterLayout({
    required this.memo,
    required this.memoIndex,
    required this.cacheKey,
    required this.document,
    required this.pages,
  });

  final LocalMemo memo;
  final int memoIndex;
  final String cacheKey;
  final ReaderChapterDocument document;
  final List<ReaderPage> pages;
}

class ReaderResolvedPage {
  const ReaderResolvedPage({required this.globalPageIndex, required this.page});

  final int globalPageIndex;
  final ReaderPage page;
}

class ReaderPageTarget {
  const ReaderPageTarget({
    required this.memoIndex,
    required this.chapterPageIndex,
  });

  final int memoIndex;
  final int chapterPageIndex;
}

class ReaderChapterPageMetrics {
  const ReaderChapterPageMetrics({
    required this.memoUid,
    required this.memoIndex,
    required this.pageCount,
    required this.globalPageStartIndex,
  });

  final String memoUid;
  final int memoIndex;
  final int pageCount;
  final int globalPageStartIndex;

  int get globalPageEndExclusive => globalPageStartIndex + pageCount;
}

class CollectionReaderPageMap {
  const CollectionReaderPageMap({
    required this.chapters,
    required this.totalPages,
  });

  final List<ReaderChapterPageMetrics> chapters;
  final int totalPages;
}

class CollectionReaderPagedBook {
  const CollectionReaderPagedBook({
    required this.chapters,
    required this.pages,
  });

  final List<ReaderChapterLayout> chapters;
  final List<ReaderResolvedPage> pages;

  int get totalPages => pages.length;
}
