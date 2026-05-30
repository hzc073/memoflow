import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';
import 'package:memos_flutter_app/features/collections/collection_reader_overlay.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('overlay controls fit narrow phone widths', (tester) async {
    LocaleSettings.setLocale(AppLocale.en);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                height: 844,
                child: Stack(
                  children: [
                    CollectionReaderOverlay(
                      visible: true,
                      headerData: const CollectionReaderHeaderData(
                        collectionTitle: 'Reading shelf',
                        currentItemTitle: 'Chapter title',
                        currentItemMeta: '2024-02-01 08:30',
                        positionLabel: '12 / 84',
                        showTitleAddition: true,
                      ),
                      readerMode: CollectionReaderMode.paged,
                      pageAnimation: CollectionReaderPageAnimation.simulation,
                      themePreset: CollectionReaderThemePreset.paper,
                      currentProgressText: 'Page 128 / 512',
                      sliderValue: 127,
                      sliderMax: 511,
                      controlMaxWidth: 390,
                      autoPaging: false,
                      showManageCollectionItems: true,
                      showRssSourceActions: false,
                      showRssSaveShortcut: false,
                      currentRssSaved: false,
                      canPrevChapter: true,
                      canNextChapter: true,
                      showBrightnessControl: true,
                      brightnessMode: CollectionReaderBrightnessMode.manual,
                      brightness: 0.7,
                      followPageStyle: true,
                      pageBackgroundColor: const Color(0xFFF6F0E4),
                      pageForegroundColor: const Color(0xFF2D2217),
                      accentColor: const Color(0xFF8C5A2D),
                      hostBrightness: Brightness.light,
                      onBack: _noop,
                      onSearch: _noop,
                      onSaveCurrentRssAsMemo: null,
                      onMoreSelected: (_) {},
                      onProgressTap: _noop,
                      onToggleThemePreset: _noop,
                      onModeChanged: (_) {},
                      onAnimationChanged: (_) {},
                      onShowToc: _noop,
                      onShowAutoPage: _noop,
                      onShowStyle: _noop,
                      onShowMoreSettings: _noop,
                      onPrevChapter: _noop,
                      onNextChapter: _noop,
                      onBrightnessModeChanged: (_) {},
                      onBrightnessChanged: (_) {},
                      onSliderChanged: (_) {},
                      onSliderChangeEnd: (_) {},
                      onOverlayInteraction: _noop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Reading shelf'), findsOneWidget);
    expect(find.text('12 / 84'), findsOneWidget);
    expect(find.text('Page 128 / 512'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay hides title addition when disabled', (tester) async {
    LocaleSettings.setLocale(AppLocale.en);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: CollectionReaderOverlay(
              visible: true,
              headerData: const CollectionReaderHeaderData(
                collectionTitle: 'Reading shelf',
                currentItemTitle: 'Chapter title',
                currentItemMeta: '2024-02-01 08:30',
                positionLabel: '3 / 9',
                showTitleAddition: false,
              ),
              readerMode: CollectionReaderMode.vertical,
              pageAnimation: CollectionReaderPageAnimation.none,
              themePreset: CollectionReaderThemePreset.paper,
              currentProgressText: 'Memo 3 / 9',
              sliderValue: 2,
              sliderMax: 8,
              controlMaxWidth: 800,
              autoPaging: false,
              showManageCollectionItems: true,
              showRssSourceActions: false,
              showRssSaveShortcut: false,
              currentRssSaved: false,
              canPrevChapter: true,
              canNextChapter: true,
              showBrightnessControl: false,
              brightnessMode: CollectionReaderBrightnessMode.system,
              brightness: 1,
              followPageStyle: false,
              pageBackgroundColor: const Color(0xFFF6F0E4),
              pageForegroundColor: const Color(0xFF2D2217),
              accentColor: const Color(0xFF8C5A2D),
              hostBrightness: Brightness.light,
              onBack: _noop,
              onSearch: _noop,
              onSaveCurrentRssAsMemo: null,
              onMoreSelected: (_) {},
              onProgressTap: _noop,
              onToggleThemePreset: _noop,
              onModeChanged: (_) {},
              onAnimationChanged: (_) {},
              onShowToc: _noop,
              onShowAutoPage: _noop,
              onShowStyle: _noop,
              onShowMoreSettings: _noop,
              onPrevChapter: _noop,
              onNextChapter: _noop,
              onBrightnessModeChanged: (_) {},
              onBrightnessChanged: (_) {},
              onSliderChanged: (_) {},
              onSliderChangeEnd: (_) {},
              onOverlayInteraction: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Reading shelf'), findsOneWidget);
    expect(find.text('Chapter title'), findsNothing);
    expect(find.text('2024-02-01 08:30'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide desktop overlay keeps controls inside control width', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const controlMaxWidth = 980.0;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: CollectionReaderOverlay(
              visible: true,
              headerData: const CollectionReaderHeaderData(
                collectionTitle: 'Reading shelf',
                currentItemTitle: 'Chapter title',
                currentItemMeta: '2024-02-01 08:30',
                positionLabel: '8 / 32',
                showTitleAddition: true,
              ),
              readerMode: CollectionReaderMode.paged,
              pageAnimation: CollectionReaderPageAnimation.simulation,
              themePreset: CollectionReaderThemePreset.paper,
              currentProgressText: 'Page 128 / 512',
              sliderValue: 127,
              sliderMax: 511,
              controlMaxWidth: controlMaxWidth,
              autoPaging: false,
              showManageCollectionItems: true,
              showRssSourceActions: false,
              showRssSaveShortcut: false,
              currentRssSaved: false,
              canPrevChapter: true,
              canNextChapter: true,
              showBrightnessControl: false,
              brightnessMode: CollectionReaderBrightnessMode.system,
              brightness: 1,
              followPageStyle: true,
              pageBackgroundColor: const Color(0xFFF6F0E4),
              pageForegroundColor: const Color(0xFF2D2217),
              accentColor: const Color(0xFF8C5A2D),
              hostBrightness: Brightness.light,
              onBack: _noop,
              onSearch: _noop,
              onSaveCurrentRssAsMemo: null,
              onMoreSelected: (_) {},
              onProgressTap: _noop,
              onToggleThemePreset: _noop,
              onModeChanged: (_) {},
              onAnimationChanged: (_) {},
              onShowToc: _noop,
              onShowAutoPage: _noop,
              onShowStyle: _noop,
              onShowMoreSettings: _noop,
              onPrevChapter: _noop,
              onNextChapter: _noop,
              onBrightnessModeChanged: (_) {},
              onBrightnessChanged: (_) {},
              onSliderChanged: (_) {},
              onSliderChangeEnd: (_) {},
              onOverlayInteraction: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const controlLeft = (1200 - controlMaxWidth) / 2;
    const controlRight = controlLeft + controlMaxWidth;
    final backRect = tester.getRect(
      find.byIcon(Icons.arrow_back_ios_new_rounded),
    );
    final moreRect = tester.getRect(find.byIcon(Icons.more_horiz_rounded));
    final sliderRect = tester.getRect(find.byType(Slider));
    final progressRect = tester.getRect(find.text('Page 128 / 512'));
    final searchRect = tester.getRect(find.byIcon(Icons.search_rounded));

    expect(backRect.left, greaterThanOrEqualTo(controlLeft));
    expect(moreRect.right, lessThanOrEqualTo(controlRight));
    expect(sliderRect.left, greaterThanOrEqualTo(controlLeft));
    expect(sliderRect.right, lessThanOrEqualTo(controlRight));
    expect(progressRect.center.dx, closeTo(600, 2));
    expect(searchRect.center.dx, greaterThan(controlLeft));
    expect(searchRect.center.dx, lessThan(controlRight));
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('macOS overlay top bar avoids native traffic lights', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: CollectionReaderOverlay(
              visible: true,
              headerData: const CollectionReaderHeaderData(
                collectionTitle: 'Reading shelf',
                currentItemTitle: 'Chapter title',
                currentItemMeta: '2024-02-01 08:30',
                positionLabel: '1 / 2',
                showTitleAddition: true,
              ),
              readerMode: CollectionReaderMode.vertical,
              pageAnimation: CollectionReaderPageAnimation.none,
              themePreset: CollectionReaderThemePreset.paper,
              currentProgressText: 'Memo 1 / 2',
              sliderValue: 0,
              sliderMax: 1,
              controlMaxWidth: 800,
              autoPaging: false,
              showManageCollectionItems: true,
              showRssSourceActions: false,
              showRssSaveShortcut: false,
              currentRssSaved: false,
              canPrevChapter: false,
              canNextChapter: true,
              showBrightnessControl: false,
              brightnessMode: CollectionReaderBrightnessMode.system,
              brightness: 1,
              followPageStyle: false,
              pageBackgroundColor: const Color(0xFFF6F0E4),
              pageForegroundColor: const Color(0xFF2D2217),
              accentColor: const Color(0xFF8C5A2D),
              hostBrightness: Brightness.light,
              onBack: _noop,
              onSearch: _noop,
              onSaveCurrentRssAsMemo: null,
              onMoreSelected: (_) {},
              onProgressTap: _noop,
              onToggleThemePreset: _noop,
              onModeChanged: (_) {},
              onAnimationChanged: (_) {},
              onShowToc: _noop,
              onShowAutoPage: _noop,
              onShowStyle: _noop,
              onShowMoreSettings: _noop,
              onPrevChapter: _noop,
              onNextChapter: _noop,
              onBrightnessModeChanged: (_) {},
              onBrightnessChanged: (_) {},
              onSliderChanged: (_) {},
              onSliderChangeEnd: (_) {},
              onOverlayInteraction: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.byIcon(Icons.arrow_back_ios_new_rounded)).dx,
      greaterThanOrEqualTo(kMacosTrafficLightReservedWidth),
    );
    expect(
      tester.getTopLeft(find.byIcon(Icons.arrow_back_ios_new_rounded)).dy,
      greaterThanOrEqualTo(kMacosTitleBarHeight),
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

void _noop() {}
