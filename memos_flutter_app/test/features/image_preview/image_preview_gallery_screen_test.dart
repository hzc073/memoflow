import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/image_preview/image_preview_edit_result.dart';
import 'package:memos_flutter_app/features/image_preview/widgets/image_preview_gallery_body.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/features/image_preview/image_preview_item.dart';
import 'package:memos_flutter_app/features/image_preview/image_preview_open_request.dart';
import 'package:memos_flutter_app/features/image_preview/widgets/image_preview_gallery_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/system/scene_micro_guide_provider.dart';
import '../../test_support.dart';

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

Widget _buildTestApp(
  Widget child, {
  Set<SceneMicroGuideId> seenGuides = const <SceneMicroGuideId>{
    SceneMicroGuideId.attachmentGalleryControls,
  },
}) {
  LocaleSettings.setLocale(AppLocale.en);
  final repository = _FixedSceneMicroGuideRepository(seenGuides);
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
        home: child,
      ),
    ),
  );
}

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  testWidgets('gallery screen supports keyboard navigation', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'first',
                title: 'First',
                mimeType: 'image/png',
              ),
              ImagePreviewItem(
                id: 'second',
                title: 'Second',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 0,
          ),
          isDesktopOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('gallery screen hides download button when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'first',
                title: 'First',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 0,
            enableDownload: false,
          ),
          isDesktopOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('desktop immersive gallery omits AppBar back chrome', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      _buildTestApp(
        ImagePreviewGalleryScreen(
          request: const ImagePreviewOpenRequest(
            items: <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'first',
                title: 'First',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 0,
          ),
          isDesktopOverride: true,
          immersiveDesktopChrome: true,
          showViewerCloseButton: true,
          onClose: () async {
            closed = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text('1/1'), findsOneWidget);
    expect(
      find.byKey(const Key('desktop_media_preview_close_button')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('gallery screen shows replace affordance when callback exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: const <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'first',
                title: 'First',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 0,
            onReplace: (_) async {},
          ),
          isDesktopOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });

  testWidgets('pending gallery uses custom preview chrome', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: const <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'pending:first',
                title: 'First',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 0,
            onReplace: (_) async {},
          ),
          isDesktopOverride: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(
      find.byKey(const Key('pending_preview_close_button')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('pending chrome follows the currently viewed pending item', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: const <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'server:first',
                title: 'First',
                mimeType: 'image/png',
              ),
              ImagePreviewItem(
                id: 'pending:second',
                title: 'Second',
                mimeType: 'image/png',
              ),
            ],
            initialIndex: 1,
            onReplace: (_) async {},
          ),
          isDesktopOverride: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(
      find.byKey(const Key('pending_preview_close_button')),
      findsOneWidget,
    );
  });

  testWidgets('gallery constrains portrait image box by contained aspect', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'portrait',
                title: 'Portrait',
                mimeType: 'image/png',
                width: 720,
                height: 1600,
              ),
            ],
            initialIndex: 0,
          ),
          isDesktopOverride: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(
      find.byKey(const Key('image_preview_display_box_portrait')),
    );
    expect(size.width, closeTo(244.8, 0.2));
    expect(size.height, closeTo(544.0, 0.2));
  });

  testWidgets('gallery screen triggers replace callback', (tester) async {
    Object? capturedResult;
    const expectedResult = ImagePreviewEditResult(
      sourceId: 'editable',
      filePath: '/tmp/edited.jpg',
      filename: 'edited.jpg',
      mimeType: 'image/jpeg',
      size: 123,
    );

    await tester.pumpWidget(
      _buildTestApp(
        ImagePreviewGalleryScreen(
          request: ImagePreviewOpenRequest(
            items: const <ImagePreviewItem>[
              ImagePreviewItem(
                id: 'editable',
                title: 'Editable',
                mimeType: 'image/jpeg',
              ),
            ],
            initialIndex: 0,
            onReplace: (result) async {
              capturedResult = result;
            },
          ),
          isDesktopOverride: true,
          editResultOverride: () async {
            return expectedResult;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final galleryState = tester.state<ImagePreviewGalleryBodyState>(
      find.byType(ImagePreviewGalleryBody),
    );
    expect(galleryState.widget.request.onReplace, isNotNull);
    expect(galleryState.widget.request.items, isNotEmpty);
    expect(galleryState.widget.editResultOverride, isNotNull);
    await galleryState.triggerEditForTesting();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(capturedResult, isA<ImagePreviewEditResult>());
    final result = capturedResult! as ImagePreviewEditResult;
    expect(result.sourceId, expectedResult.sourceId);
    expect(result.filePath, expectedResult.filePath);
    expect(result.filename, expectedResult.filename);
    expect(result.mimeType, expectedResult.mimeType);
    expect(result.size, expectedResult.size);
  });
}
