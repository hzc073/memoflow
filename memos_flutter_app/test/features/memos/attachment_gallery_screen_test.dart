import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
