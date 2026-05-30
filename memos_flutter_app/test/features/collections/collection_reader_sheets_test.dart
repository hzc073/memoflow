import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/system_fonts.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_auto_page_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_click_actions_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_more_settings_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_padding_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_search_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_style_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_tip_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_toc_sheet.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_utils.dart';
import 'package:memos_flutter_app/features/collections/reader_platform_capabilities.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/system/system_fonts_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  testWidgets('core reader sheets fit narrow mobile widths', (tester) async {
    final items = _sampleMemos();
    const widths = <double>[360, 390, 393];

    final widgets = <Widget>[
      CollectionReaderAutoPageSheet(
        isRunning: false,
        secondsPerPage: 10,
        onToggle: (_) {},
        onSecondsChanged: (_) {},
      ),
      CollectionReaderMoreSettingsSheet(
        displayConfig: CollectionReaderDisplayConfig.defaults,
        inputConfig: CollectionReaderInputConfig.defaults,
        capabilities: ReaderPlatformCapabilities.current(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        onDisplayConfigChanged: (_) {},
        onInputConfigChanged: (_) {},
        onOpenClickActions: () {},
      ),
      CollectionReaderClickActionsSheet(
        config: CollectionReaderTapRegionConfig.defaults,
        onChanged: (_) {},
      ),
      CollectionReaderTocSheet(
        entries: buildCollectionReaderTocEntries(items),
        currentIndex: 0,
        onSelect: (_) async {},
      ),
      CollectionReaderSearchSheet(
        items: items,
        onSelect: (item, result) async {},
      ),
    ];

    for (final width in widths) {
      for (final widget in widgets) {
        await _pumpSheet(tester, child: widget, width: width);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('style-related reader sheets fit narrow mobile widths', (
    tester,
  ) async {
    final prefs = CollectionReaderPreferences.defaults;
    const widths = <double>[360, 390, 393];
    final widgets = <Widget>[
      CollectionReaderPaddingSheet(
        preferences: prefs,
        onPagePaddingChanged: (_) {},
        onHeaderPaddingChanged: (_) {},
        onFooterPaddingChanged: (_) {},
        onShowHeaderLineChanged: (_) {},
        onShowFooterLineChanged: (_) {},
      ),
      CollectionReaderTipSheet(
        preferences: prefs,
        onTitleModeChanged: (_) {},
        onTitleScaleChanged: (_) {},
        onTitleTopSpacingChanged: (_) {},
        onTitleBottomSpacingChanged: (_) {},
        onTipLayoutChanged: (_) {},
      ),
      CollectionReaderStyleSheet(
        preferences: prefs,
        onThemePresetChanged: (_) {},
        onBackgroundConfigChanged: (_) {},
        onBrightnessModeChanged: (_) {},
        onBrightnessChanged: (_) {},
        onPageAnimationChanged: (_) {},
        onContentWidthModeChanged: (_) {},
        onTextScaleChanged: (_) {},
        onLineSpacingChanged: (_) {},
        onFontFamilyChanged: ({String? family, String? filePath}) {},
        onFontWeightModeChanged: (_) {},
        onLetterSpacingChanged: (_) {},
        onParagraphSpacingChanged: (_) {},
        onParagraphIndentCharsChanged: (_) {},
        onSavedStyleCardsChanged: (_) {},
        onOpenTipSettings: () {},
        onOpenPaddingSettings: () {},
      ),
    ];

    for (final width in widths) {
      for (final widget in widgets) {
        await _pumpSheet(
          tester,
          child: widget,
          width: width,
          overrides: [
            systemFontsProvider.overrideWith(
              (ref) =>
                  Future<List<SystemFontInfo>>.value(const <SystemFontInfo>[]),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      }
    }
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Widget child,
  double width = 390,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 844)),
            child: Scaffold(
              body: Center(
                child: SizedBox(width: width, height: 720, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

List<LocalMemo> _sampleMemos() {
  return <LocalMemo>[
    _memo('memo-1', 'Chapter one\nHello world'),
    _memo('memo-2', 'Chapter two\nAnother passage'),
    _memo('memo-3', 'Chapter three\nSearch target'),
  ];
}

LocalMemo _memo(String uid, String content) {
  final now = DateTime(2024, 2, 1, 8, 30);
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: content,
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: now,
    displayTime: now,
    updateTime: now,
    tags: const <String>[],
    attachments: const <Attachment>[],
    relationCount: 0,
    location: null,
    syncState: SyncState.synced,
    lastError: null,
  );
}
