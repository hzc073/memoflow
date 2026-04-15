import 'package:intl/intl.dart';

import '../../data/models/collection_reader.dart';
import 'collection_reader_page_models.dart';

class ReaderTipStrings {
  const ReaderTipStrings({
    required this.left,
    required this.center,
    required this.right,
  });

  final String left;
  final String center;
  final String right;
}

ReaderTipStrings buildReaderTipStrings({
  required ReaderPage page,
  required CollectionReaderTipLayout tipLayout,
  required String collectionTitle,
  required String chapterTitle,
  required int globalPageIndex,
  required int totalPages,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  return ReaderTipStrings(
    left: _resolveTipSlot(
      slot: page.headerTip?.leftSlot ?? tipLayout.headerLeft,
      page: page,
      collectionTitle: collectionTitle,
      chapterTitle: chapterTitle,
      globalPageIndex: globalPageIndex,
      totalPages: totalPages,
      now: moment,
    ),
    center: _resolveTipSlot(
      slot: page.headerTip?.centerSlot ?? tipLayout.headerCenter,
      page: page,
      collectionTitle: collectionTitle,
      chapterTitle: chapterTitle,
      globalPageIndex: globalPageIndex,
      totalPages: totalPages,
      now: moment,
    ),
    right: _resolveTipSlot(
      slot: page.headerTip?.rightSlot ?? tipLayout.headerRight,
      page: page,
      collectionTitle: collectionTitle,
      chapterTitle: chapterTitle,
      globalPageIndex: globalPageIndex,
      totalPages: totalPages,
      now: moment,
    ),
  );
}

ReaderTipStrings buildReaderFooterTipStrings({
  required ReaderPage page,
  required CollectionReaderTipLayout tipLayout,
  required String collectionTitle,
  required String chapterTitle,
  required int globalPageIndex,
  required int totalPages,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  return ReaderTipStrings(
    left: _resolveTipSlot(
      slot: page.footerTip?.leftSlot ?? tipLayout.footerLeft,
      page: page,
      collectionTitle: collectionTitle,
      chapterTitle: chapterTitle,
      globalPageIndex: globalPageIndex,
      totalPages: totalPages,
      now: moment,
    ),
    center: _resolveTipSlot(
      slot: page.footerTip?.centerSlot ?? tipLayout.footerCenter,
      page: page,
      collectionTitle: collectionTitle,
      chapterTitle: chapterTitle,
      globalPageIndex: globalPageIndex,
      totalPages: totalPages,
      now: moment,
    ),
    right: _resolveTipSlot(
      slot: page.footerTip?.rightSlot ?? tipLayout.footerRight,
      page: page,
      collectionTitle: collectionTitle,
      chapterTitle: chapterTitle,
      globalPageIndex: globalPageIndex,
      totalPages: totalPages,
      now: moment,
    ),
  );
}

String _resolveTipSlot({
  required CollectionReaderTipSlot slot,
  required ReaderPage page,
  required String collectionTitle,
  required String chapterTitle,
  required int globalPageIndex,
  required int totalPages,
  required DateTime now,
}) {
  return switch (slot) {
    CollectionReaderTipSlot.none => '',
    CollectionReaderTipSlot.collectionTitle => collectionTitle,
    CollectionReaderTipSlot.chapterTitle => chapterTitle,
    CollectionReaderTipSlot.time => DateFormat('HH:mm').format(now),
    CollectionReaderTipSlot.battery => '',
    CollectionReaderTipSlot.batteryPercentage => '',
    CollectionReaderTipSlot.page => '${globalPageIndex + 1}',
    CollectionReaderTipSlot.totalProgress => totalPages <= 0
        ? ''
        : '${(((globalPageIndex + 1) / totalPages) * 100).round()}%',
    CollectionReaderTipSlot.pageAndTotal => totalPages <= 0
        ? ''
        : '${globalPageIndex + 1}/$totalPages',
    CollectionReaderTipSlot.timeBattery =>
      '${DateFormat('HH:mm').format(now)}  ',
    CollectionReaderTipSlot.timeBatteryPercentage =>
      '${DateFormat('HH:mm').format(now)}  ',
  };
}
