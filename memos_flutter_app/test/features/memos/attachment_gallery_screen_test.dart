import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memos_flutter_app/core/scene_micro_guide_widgets.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/features/memos/attachment_gallery_screen.dart';
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

Widget _buildTestApp(
  Widget child, {
  AppLocale locale = AppLocale.en,
  SceneMicroGuideRepository? repository,
}) {
  LocaleSettings.setLocale(locale);
  return ProviderScope(
    overrides: [
      if (repository != null)
        sceneMicroGuideRepositoryProvider.overrideWithValue(repository),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: locale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
}

void main() {
  test('gallery cache extent limits mobile decode size', () {
    expect(resolveAttachmentGalleryCacheExtent(360, 3, isDesktop: false), 1620);
    expect(
      resolveAttachmentGalleryCacheExtent(4000, 3, isDesktop: false),
      1920,
    );
    expect(resolveAttachmentGalleryCacheExtent(0, 3, isDesktop: false), isNull);
    expect(resolveAttachmentGalleryCacheExtent(2000, 2, isDesktop: true), 1920);
  });

  test('gallery preview extent stays below full decode size', () {
    expect(resolveAttachmentGalleryPreviewExtent(1620, isDesktop: false), 810);
    expect(resolveAttachmentGalleryPreviewExtent(3072, isDesktop: false), 960);
    expect(resolveAttachmentGalleryPreviewExtent(600, isDesktop: false), 300);
    expect(resolveAttachmentGalleryPreviewExtent(240, isDesktop: false), 120);
    expect(resolveAttachmentGalleryPreviewExtent(4096, isDesktop: true), 1440);
    expect(
      resolveAttachmentGalleryPreviewExtent(null, isDesktop: false),
      isNull,
    );
  });

  test('gallery decode size preserves image aspect ratio', () {
    final portrait = resolveAttachmentGalleryDecodeSize(
      const Size(720, 1600),
      const Size(400, 800),
      3,
      isDesktop: false,
    );
    expect(portrait, isNotNull);
    expect(portrait!.width, 864);
    expect(portrait.height, 1920);

    final landscape = resolveAttachmentGalleryDecodeSize(
      const Size(1600, 720),
      const Size(400, 800),
      3,
      isDesktop: false,
    );
    expect(landscape, isNotNull);
    expect(landscape!.width, 1800);
    expect(landscape.height, 810);
  });

  test('gallery preview size scales down uniformly', () {
    final preview = resolveAttachmentGalleryPreviewSize((
      width: 864,
      height: 1920,
    ), isDesktop: false);
    expect(preview, isNotNull);
    expect(preview!.width, 432);
    expect(preview.height, 960);
  });

  test('gallery decode hint uses only dominant axis', () {
    expect(resolveAttachmentGalleryDecodeHint((width: 864, height: 1920)), (
      width: 0,
      height: 1920,
    ));
    expect(resolveAttachmentGalleryDecodeHint((width: 1920, height: 864)), (
      width: 1920,
      height: 0,
    ));
  });

  test('gallery display size parser swaps axes for rotated jpeg', () {
    final image = img.Image(width: 2, height: 4);
    image.exif.imageIfd.orientation = 6;
    final bytes = img.encodeJpg(image);
    expect(resolveAttachmentGalleryDisplaySizeFromBytes(bytes), (
      width: 4,
      height: 2,
    ));
  });

  testWidgets('desktop gallery supports keyboard and click navigation', (
    tester,
  ) async {
    final repository = SceneMicroGuideRepository(_MemorySecureStorage());
    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
            AttachmentImageSource(
              id: 'second',
              title: 'Second',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(SceneMicroGuideOverlayPill), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.byType(SceneMicroGuideOverlayPill), findsNothing);

    final pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(pageRect.left + 40, pageRect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('escape closes pushed gallery route', (tester) async {
    final repository = SceneMicroGuideRepository(_MemorySecureStorage());
    await tester.pumpWidget(
      _buildTestApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AttachmentGalleryScreen(
                          images: [
                            AttachmentImageSource(
                              id: 'only',
                              title: 'Only',
                              mimeType: 'image/png',
                            ),
                          ],
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
        repository: repository,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('1/1'), findsNothing);
  });

  testWidgets('double tap resets image zoom to default scale', (tester) async {
    final repository = SceneMicroGuideRepository(_MemorySecureStorage());
    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SceneMicroGuideOverlayPill), findsOneWidget);

    final viewerFinder = find.byType(InteractiveViewer);
    final viewerBefore = tester.widget<InteractiveViewer>(viewerFinder);
    viewerBefore.transformationController!.value = Matrix4.diagonal3Values(
      2,
      2,
      1,
    );
    await tester.pump();

    final pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(pageRect.center);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(pageRect.center);
    await tester.pumpAndSettle();

    final viewerAfter = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewerAfter.transformationController!.value.getMaxScaleOnAxis(), 1);
    expect(find.byType(SceneMicroGuideOverlayPill), findsNothing);
  });

  testWidgets('mobile gallery pans zoomed image before switching pages', (
    tester,
  ) async {
    final repository = SceneMicroGuideRepository(_MemorySecureStorage());
    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
            AttachmentImageSource(
              id: 'second',
              title: 'Second',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
          isDesktopOverride: false,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byType(InteractiveViewer);
    final pageViewFinder = find.byType(PageView);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final viewerRect = tester.getRect(viewerFinder);

    viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();

    final zoomedPageView = tester.widget<PageView>(pageViewFinder);
    expect(zoomedPageView.physics, isA<NeverScrollableScrollPhysics>());

    await tester.drag(viewerFinder, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);

    final rightEdgeMatrix = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-viewerRect.width, 0, 0);
    viewer.transformationController!.value = rightEdgeMatrix;
    await tester.pump();

    await tester.drag(viewerFinder, const Offset(-80, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets(
    'mobile gallery clears zoom lock after a zoomed page is disposed',
    (tester) async {
      final repository = SceneMicroGuideRepository(_MemorySecureStorage());
      await tester.pumpWidget(
        _buildTestApp(
          const AttachmentGalleryScreen(
            images: [
              AttachmentImageSource(
                id: 'first',
                title: 'First',
                mimeType: 'image/png',
              ),
              AttachmentImageSource(
                id: 'second',
                title: 'Second',
                mimeType: 'image/png',
              ),
              AttachmentImageSource(
                id: 'third',
                title: 'Third',
                mimeType: 'image/png',
              ),
              AttachmentImageSource(
                id: 'fourth',
                title: 'Fourth',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 0,
            isDesktopOverride: false,
          ),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      final viewerFinder = find.byType(InteractiveViewer);
      final pageViewFinder = find.byType(PageView);
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      final viewerRect = tester.getRect(viewerFinder);
      final pageRect = tester.getRect(pageViewFinder);
      final pageSwipeDistance = pageRect.width * 0.75;

      final rightEdgeMatrix = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-viewerRect.width, 0, 0);
      viewer.transformationController!.value = rightEdgeMatrix;
      await tester.pump();

      expect(
        tester.widget<PageView>(pageViewFinder).physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      await tester.drag(viewerFinder, const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/4'), findsOneWidget);

      await tester.drag(pageViewFinder, Offset(-pageSwipeDistance, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/4'), findsOneWidget);

      await tester.drag(pageViewFinder, Offset(-pageSwipeDistance, 0));
      await tester.pumpAndSettle();
      expect(find.text('4/4'), findsOneWidget);

      final viewerScales = tester
          .widgetList<InteractiveViewer>(
            find.byType(InteractiveViewer, skipOffstage: false),
          )
          .map(
            (current) =>
                current.transformationController!.value.getMaxScaleOnAxis(),
          )
          .toList();
      expect(viewerScales, isNot(contains(greaterThan(1.1))));

      await tester.drag(pageViewFinder, Offset(pageSwipeDistance, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/4'), findsOneWidget);

      await tester.drag(pageViewFinder, Offset(pageSwipeDistance, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/4'), findsOneWidget);

      await tester.drag(pageViewFinder, Offset(pageSwipeDistance, 0));
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget);

      expect(
        tester.widget<PageView>(pageViewFinder).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );

      await tester.drag(pageViewFinder, Offset(-pageSwipeDistance, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/4'), findsOneWidget);
    },
  );

  testWidgets('controls guide is shown once per device state', (tester) async {
    final storage = _MemorySecureStorage();
    final repository = SceneMicroGuideRepository(storage);

    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SceneMicroGuideOverlayPill), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.byType(SceneMicroGuideOverlayPill), findsNothing);
    expect(
      jsonDecode(
        (await storage.read(key: SceneMicroGuideRepository.storageKey))!,
      ),
      contains(SceneMicroGuideId.attachmentGalleryControls.name),
    );

    await tester.pumpWidget(
      _buildTestApp(
        const AttachmentGalleryScreen(
          images: [
            AttachmentImageSource(
              id: 'first',
              title: 'First',
              mimeType: 'image/png',
            ),
          ],
          initialIndex: 0,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SceneMicroGuideOverlayPill), findsNothing);
  });
}
