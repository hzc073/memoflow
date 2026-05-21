import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/features/image_preview/widgets/image_preview_gallery_body.dart';
import 'package:memos_flutter_app/features/image_preview/widgets/image_preview_tile.dart';
import 'package:memos_flutter_app/features/memos/memo_image_grid.dart';
import 'package:memos_flutter_app/features/memos/memo_media_grid.dart';
import 'package:memos_flutter_app/features/memos/memo_video_grid.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/system/scene_micro_guide_provider.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
      return;
    }
    _data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

class _FixedSceneMicroGuideRepository extends SceneMicroGuideRepository {
  _FixedSceneMicroGuideRepository(this._seen) : super(_MemorySecureStorage());

  final Set<SceneMicroGuideId> _seen;

  @override
  Future<Set<SceneMicroGuideId>> read() async => _seen;

  @override
  Future<void> write(Set<SceneMicroGuideId> ids) async {}
}

Widget _buildTestApp(Widget child) {
  LocaleSettings.setLocale(AppLocale.en);
  final repository = _FixedSceneMicroGuideRepository(const <SceneMicroGuideId>{
    SceneMicroGuideId.attachmentGalleryControls,
  });
  return ProviderScope(
    overrides: <Override>[
      sceneMicroGuideRepositoryProvider.overrideWithValue(repository),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    ),
  );
}

MemoImageEntry _image(String id) =>
    MemoImageEntry(id: id, title: id, mimeType: 'image/png');

MemoVideoEntry _video(String id) =>
    MemoVideoEntry(id: id, title: id, mimeType: 'video/mp4', size: 1);

void main() {
  test('pure image taps stay on shared image preview flow', () {
    expect(
      resolveMemoMediaTapBehavior(
        entries: <MemoMediaEntry>[
          MemoMediaEntry.image(_image('img-1')),
          MemoMediaEntry.image(_image('img-2')),
        ],
        mediaIndex: 0,
        visibleCount: 2,
      ),
      MemoMediaTapBehavior.imagePreview,
    );
  });

  test('mixed media image taps open full gallery', () {
    expect(
      resolveMemoMediaTapBehavior(
        entries: <MemoMediaEntry>[
          MemoMediaEntry.image(_image('img-1')),
          MemoMediaEntry.video(_video('video-1')),
        ],
        mediaIndex: 0,
        visibleCount: 2,
      ),
      MemoMediaTapBehavior.mixedGallery,
    );
  });

  test('overflow on the last visible image opens full gallery', () {
    expect(
      resolveMemoMediaTapBehavior(
        entries: <MemoMediaEntry>[
          MemoMediaEntry.image(_image('img-1')),
          MemoMediaEntry.image(_image('img-2')),
          MemoMediaEntry.video(_video('video-1')),
        ],
        mediaIndex: 1,
        visibleCount: 2,
      ),
      MemoMediaTapBehavior.mixedGallery,
    );
  });

  test('overflow on the last visible video opens full gallery', () {
    expect(
      resolveMemoMediaTapBehavior(
        entries: <MemoMediaEntry>[
          MemoMediaEntry.image(_image('img-1')),
          MemoMediaEntry.video(_video('video-1')),
          MemoMediaEntry.video(_video('video-2')),
        ],
        mediaIndex: 1,
        visibleCount: 2,
      ),
      MemoMediaTapBehavior.mixedGallery,
    );
  });

  test('visible video without overflow still opens video screen', () {
    expect(
      resolveMemoMediaTapBehavior(
        entries: <MemoMediaEntry>[
          MemoMediaEntry.image(_image('img-1')),
          MemoMediaEntry.video(_video('video-1')),
        ],
        mediaIndex: 1,
        visibleCount: 2,
      ),
      MemoMediaTapBehavior.videoScreen,
    );
  });

  testWidgets('pure image grid opens shared preview widget on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        MemoMediaGrid(
          entries: <MemoMediaEntry>[MemoMediaEntry.image(_image('img-1'))],
          columns: 1,
          borderColor: Colors.white24,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ImagePreviewTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(ImagePreviewGalleryBody), findsOneWidget);
  });

  testWidgets('macOS height-limited media grid preserves square tiles', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    try {
      await tester.pumpWidget(
        _buildTestApp(
          Center(
            child: SizedBox(
              width: 760,
              child: MemoMediaGrid(
                entries: List<MemoMediaEntry>.generate(
                  9,
                  (index) => MemoMediaEntry.image(_image('img-$index')),
                ),
                columns: 3,
                maxCount: 9,
                maxHeight: 300,
                preserveSquareTilesWhenHeightLimited: true,
                radius: 0,
                spacing: 4,
                borderColor: Colors.white24,
                backgroundColor: Colors.black,
                textColor: Colors.white,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileRect = tester.getRect(find.byType(ImagePreviewTile).first);
      final gridRect = tester.getRect(find.byType(GridView).first);
      expect(tileRect.width, closeTo(tileRect.height, 0.1));
      expect(tileRect.width, lessThan(200));
      expect(gridRect.width, lessThan(760));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
